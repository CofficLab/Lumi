import Foundation
import MailCore

/// `MailCoreAdapter` 工厂：KitMail 对外唯一的会话创建入口。
///
/// 上层经 `MailSessionFactory` 拿到 `any MailSessionServing`，
/// 本类型是「唯一 import MailCore 第三方处」的实现。
public struct MailCoreAdapterFactory: MailSessionFactory, @unchecked Sendable {
    public init() {}

    public func makeSession(
        account: MailAccountConfig,
        password: String
    ) async throws -> any MailSessionServing {
        MailCoreAdapter(account: account, password: password)
    }
}

/// MailCore2 适配器。
///
/// 并发模型（集中一处）：
/// - 所有进入 MailCore 的调用经内部串行队列 `queue` 派发；
/// - ObjC 回调在 MailCore 的任意线程触发，经 `CallbackGate` 只 resume 一次
///   对应的 continuation（超时 watchdog 与回调竞争安全）；
/// - 本类型 `@unchecked Sendable`：可变状态仅 `imapSession` / `smtpSession`，
///   它们仅在 `queue` 内被访问。
public final class MailCoreAdapter: MailSessionServing, @unchecked Sendable {
    /// 单次操作超时（30s），超时归为 `.network`。
    public static let operationTimeout: TimeInterval = 30

    private let account: MailAccountConfig
    private let imapSession: MCOIMAPSession
    private let smtpSession: MCOSMTPSession
    private let queue = DispatchQueue(label: "com.lumi.kitmail.adapter", qos: .userInitiated)

    private var bridge: MailCoreCallbackBridge {
        MailCoreCallbackBridge(queue: queue)
    }

    public init(account: MailAccountConfig, password: String) {
        self.account = account

        let imap = MCOIMAPSession()
        imap.hostname = account.imapHost
        imap.port = UInt32(account.imapPort)
        imap.username = account.username
        imap.password = password
        imap.connectionType = account.useTLS ? .TLS : .startTLS
        imap.timeout = Self.operationTimeout
        self.imapSession = imap

        let smtp = MCOSMTPSession()
        smtp.hostname = account.smtpHost
        smtp.port = UInt32(account.smtpPort)
        smtp.username = account.username
        smtp.password = password
        smtp.connectionType = account.useTLS ? .TLS : .startTLS
        smtp.timeout = Self.operationTimeout
        self.smtpSession = smtp
    }

    // MARK: - MailSessionServing

    public func connect() async throws {
        try await bridge.performVoid { completion in
            guard let op = self.imapSession.connectOperation() else {
                completion(MailError.protocolError("operation creation failed"))
                return
            }
            op.start { error in
                completion(error)
            }
        }
    }

    public func disconnect() async {
        try? await bridge.performVoid { completion in
            guard let op = self.imapSession.disconnectOperation() else {
                completion(MailError.protocolError("operation creation failed"))
                return
            }
            op.start { error in
                completion(error)
            }
        }
    }

    public func listFolders() async throws -> [MailFolder] {
        let folders: [MCOIMAPFolder] = try await bridge.perform { completion in
            // 协议约定列出全部文件夹：使用 IMAP LIST（全部）而非 LSUB（已订阅），
            // 否则未订阅但仍存在的文件夹会从工作区消失。
            guard let op = Self.fetchFoldersOperation(using: self.imapSession) else {
                completion(nil, MailError.protocolError("operation creation failed"))
                return
            }
            op.start { error, values in
                completion(values, error)
            }
        }
        return folders.map { folder in
            MailFolder(
                path: folder.path,
                kind: MailFolder.inferKind(from: folder.path),
                delimiter: String(folder.delimiter)
            )
        }
    }

    /// 文件夹枚举操作：始终取「全部文件夹」（IMAP LIST）。
    /// 独立成函数以便测试锁定不会退回 `fetchSubscribedFoldersOperation`。
    static func fetchFoldersOperation(
        using session: MCOIMAPSession
    ) -> MCOIMAPFetchFoldersOperation? {
        session.fetchAllFoldersOperation()
    }

    public func fetchMessages(
        folder: String,
        sinceUID: UInt64?,
        limit: Int
    ) async throws -> [MailMessageSummary] {
        let messages: [MCOIMAPMessage]
        if let sinceUID {
            // 增量：uid > sinceUID 的全部新邮件。
            // 游标同样必须先校验，避免 +1 在 UInt64.max 上溢出。
            let cursor = try Self.validatedUID(sinceUID)
            let range = MCORangeMake(UInt64(cursor) + 1, UINT64_MAX - UInt64(cursor))
            let uids = MCOIndexSet(range: range)
            messages = try await bridge.perform { completion in
                guard let op = self.imapSession.fetchMessagesOperation(
                    withFolder: folder,
                    requestKind: [.headers, .flags, .structure],
                    uids: uids
                ) else {
                    completion(nil, MailError.protocolError("operation creation failed"))
                    return
                }
                op.start { error, values, _ in
                    completion(values, error)
                }
            }
        } else {
            // 全量：取最新 limit 条（倒序）
            let info: MCOIMAPFolderInfo = try await bridge.perform { completion in
                guard let op = self.imapSession.folderInfoOperation(folder) else {
                    completion(nil, MailError.protocolError("operation creation failed"))
                    return
                }
                op.start { error, value in
                    completion(value, error)
                }
            }
            let count = Int64(info.messageCount)
            let upper = max(count - Int64(limit) + 1, 1)
            let range = MCORangeMake(UInt64(upper), UInt64(count - upper + 1))
            let numbers = MCOIndexSet(range: range)
            messages = try await bridge.perform { completion in
                guard let op = self.imapSession.fetchMessagesByNumberOperation(
                    withFolder: folder,
                    requestKind: [.headers, .flags, .structure],
                    numbers: numbers
                ) else {
                    completion(nil, MailError.protocolError("operation creation failed"))
                    return
                }
                op.start { error, values, _ in
                    completion(values, error)
                }
            }
        }
        return messages.map { Self.summary(from: $0, accountID: account.id, folder: folder) }
    }

    public func fetchBody(uid: UInt64, folder: String) async throws -> MailMessageDetail {
        // MailCore 的接口只接受 UInt32；越界 UID 在这里转为参数错误，
        // 而不是在 `UInt32(uid)` 处 trap。
        let uid32 = try Self.validatedUID(uid)
        let rawData: Data = try await bridge.perform { completion in
            guard let op = self.imapSession.fetchMessageOperation(withFolder: folder, uid: uid32) else {
                completion(nil, MailError.protocolError("operation creation failed"))
                return
            }
            op.start { error, data in
                completion(data, error)
            }
        }
        guard let parser = MCOMessageParser(data: rawData) else {
            throw MailError.protocolError("failed to parse message \(uid)")
        }
        guard let header = parser.header else {
            throw MailError.protocolError("failed to parse header for message \(uid)")
        }

        let summary = MailMessageSummary(
            accountID: account.id,
            folder: folder,
            uid: uid,
            messageID: header.messageID,
            subject: header.subject ?? "",
            from: Self.address(from: header.from),
            to: (header.to as? [MCOAddress] ?? []).compactMap(Self.address(from:)),
            date: header.date ?? .distantPast,
            isRead: false,
            isFlagged: false,
            hasAttachment: !(parser.attachments() as? [MCOAbstractPart] ?? []).isEmpty,
            references: header.references as? [String] ?? []
        )

        let html = parser.htmlRendering(with: nil)
        let plain = parser.plainTextRendering()
        let attachments = try await fetchAttachments(for: parser, uid: uid32, folder: folder)

        return MailMessageDetail(
            summary: summary,
            htmlBody: (html ?? "").isEmpty ? nil : html,
            plainTextBody: (plain ?? "").isEmpty ? nil : plain,
            attachments: attachments,
            inReplyTo: header.inReplyTo.first as? String
        )
    }

    public func setFlags(
        uid: UInt64,
        folder: String,
        isRead: Bool?,
        isFlagged: Bool?
    ) async throws {
        let uid32 = try Self.validatedUID(uid)
        var pending: [(kind: MCOIMAPStoreFlagsRequestKind, flags: MCOMessageFlag)] = []
        if let isRead {
            pending.append((isRead ? .add : .remove, .seen))
        }
        if let isFlagged {
            pending.append((isFlagged ? .add : .remove, .flagged))
        }
        for (kind, flags) in pending {
            try await bridge.performVoid { completion in
                guard let op = self.imapSession.storeFlagsOperation(
                    withFolder: folder,
                    uids: MCOIndexSet(index: UInt64(uid32)),
                    kind: kind,
                    flags: flags
                ) else {
                    completion(MailError.protocolError("operation creation failed"))
                    return
                }
                op.start { error in
                    completion(error)
                }
            }
        }
    }

    public func search(query: String, folder: String) async throws -> [UInt64] {
        let subject = MCOIMAPSearchExpression.searchSubject(query)
        let from = MCOIMAPSearchExpression.search(from: query)
        let recipient = MCOIMAPSearchExpression.search(to: query)
        let expression = MCOIMAPSearchExpression.searchOr(
            subject,
            other: MCOIMAPSearchExpression.searchOr(from, other: recipient)
        )
        let indexSet: MCOIndexSet = try await bridge.perform { completion in
            guard let op = self.imapSession.searchExpressionOperation(withFolder: folder, expression: expression) else {
                completion(nil, MailError.protocolError("operation creation failed"))
                return
            }
            op.start { error, value in
                completion(value, error)
            }
        }
        var uids: [UInt64] = []
        indexSet.enumerate { uid in
            uids.append(uid)
        }
        return uids
    }

    public func sendMessage(mime: Data) async throws {
        try await bridge.performVoid { completion in
            guard let op = self.smtpSession.sendOperation(with: mime) else {
                completion(MailError.protocolError("operation creation failed"))
                return
            }
            op.start { error in
                completion(error)
            }
        }
    }

    public func appendDraft(mime: Data, folder: String) async throws {
        try await bridge.performVoid { completion in
            guard let op = self.imapSession.appendMessageOperation(
                withFolder: folder,
                messageData: mime,
                flags: .draft
            ) else {
                completion(MailError.protocolError("operation creation failed"))
                return
            }
            op.start { error, _ in
                completion(error)
            }
        }
    }

    // MARK: - 映射

    private static func summary(
        from message: MCOIMAPMessage,
        accountID: UUID,
        folder: String
    ) -> MailMessageSummary {
        guard let header = message.header else {
            // 无头消息仍返回摘要骨架（uid 可用于后续 fetchBody 重取）
            return MailMessageSummary(
                accountID: accountID,
                folder: folder,
                uid: UInt64(message.uid)
            )
        }
        let flags = message.flags
        return MailMessageSummary(
            accountID: accountID,
            folder: folder,
            uid: UInt64(message.uid),
            messageID: header.messageID,
            subject: header.subject ?? "",
            from: address(from: header.from),
            to: (header.to as? [MCOAddress] ?? []).compactMap(address(from:)),
            date: header.date ?? .distantPast,
            isRead: flags.contains(.seen),
            isFlagged: flags.contains(.flagged),
            hasAttachment: hasAttachment(in: message.mainPart),
            snippet: nil,
            references: header.references as? [String] ?? []
        )
    }

    /// 递归判断 part 结构树是否含附件。
    private static func hasAttachment(in part: MCOAbstractPart?) -> Bool {
        guard let part else { return false }
        if part.isAttachment { return true }
        if let multipart = part as? MCOAbstractMultipart {
            for child in (multipart.parts as? [MCOAbstractPart] ?? []) {
                if hasAttachment(in: child) { return true }
            }
        }
        if let messagePart = part as? MCOAbstractMessagePart {
            return hasAttachment(in: messagePart.mainPart)
        }
        return false
    }

    private static func address(from address: MCOAddress?) -> MailAddress? {
        guard let address else { return nil }
        let email = address.mailbox ?? ""
        guard !email.isEmpty else { return nil }
        return MailAddress(displayName: address.displayName, email: email)
    }

    /// 遍历消息结构，对需要网络的附件 part 下载并落盘。
    private func fetchAttachments(
        for parser: MCOMessageParser,
        uid: UInt32,
        folder: String
    ) async throws -> [MailAttachment] {
        let parts = parser.attachments as? [MCOAbstractPart] ?? []
        guard !parts.isEmpty else { return [] }

        let directory = attachmentDirectory()
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        var results: [MailAttachment] = []
        for part in parts {
            guard let filename = part.filename, !filename.isEmpty else { continue }
            let mimeType = part.mimeType ?? "application/octet-stream"

            if let attachment = part as? MCOAttachment, let data = attachment.data {
                // 内联数据直接可用
                results.append(
                    MailAttachment(
                        filename: filename,
                        mimeType: mimeType,
                        size: Int64(data.count),
                        data: data
                    )
                )
                continue
            }

            // 需从服务器下载：partID / encoding 在 MCOIMAPPart 上
            guard let imapPart = part as? MCOIMAPPart,
                  let partID = imapPart.partID else { continue }
            let data: Data = try await bridge.perform { completion in
                guard let op = self.imapSession.fetchMessageAttachmentOperation(
                    withFolder: folder,
                    uid: uid,
                    partID: partID,
                    encoding: imapPart.encoding
                ) else {
                    completion(nil, MailError.protocolError("operation creation failed"))
                    return
                }
                op.start { error, value in
                    completion(value, error)
                }
            }
            let safeName = sanitizedFileName(filename)
            let fileURL = directory.appendingPathComponent(safeName)
            try data.write(to: fileURL)
            results.append(
                MailAttachment(
                    filename: filename,
                    mimeType: mimeType,
                    size: Int64(data.count),
                    localFileURL: fileURL.path
                )
            )
        }
        return results
    }

    /// 收窄 UID 前的统一校验：非法值转为 `MailError.invalidArgument`。
    private static func validatedUID(_ uid: UInt64) throws -> UInt32 {
        guard let value = MailUID.validated(uid) else {
            throw MailError.invalidArgument(
                "uid must be between 1 and \(MailUID.maximum), got \(uid)"
            )
        }
        return value
    }

    private func attachmentDirectory() -> URL {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("KitMail", isDirectory: true)
            .appendingPathComponent(account.id.uuidString, isDirectory: true)
        return base
    }

    private func sanitizedFileName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics
            .union(CharacterSet(charactersIn: "-_. "))
        let components = name.components(separatedBy: allowed.inverted)
        let sanitized = components.joined(separator: "_")
        return sanitized.isEmpty ? "attachment" : sanitized
    }

    // MARK: - 错误映射

    /// MCOErrorCode → MailError。
    static func mapError(_ error: Error) -> MailError {
        let nsError = error as NSError
        guard nsError.domain == MCOErrorDomain else {
            return .protocolError(nsError.localizedDescription)
        }
        switch nsError.code {
        case MCOErrorCode.authentication.rawValue,
             MCOErrorCode.authenticationRequired.rawValue,
             MCOErrorCode.invalidAccount.rawValue,
             MCOErrorCode.gmailApplicationSpecificPasswordRequired.rawValue,
             MCOErrorCode.tiscaliSimplePassword.rawValue:
            return .authFailed
        case MCOErrorCode.connection.rawValue,
             MCOErrorCode.tlsNotAvailable.rawValue,
             MCOErrorCode.startTLSNotAvailable.rawValue,
             MCOErrorCode.certificate.rawValue,
             MCOErrorCode.noValidServerFound.rawValue:
            return .network
        case MCOErrorCode.nonExistantFolder.rawValue:
            return .notFound
        default:
            return .protocolError(nsError.localizedDescription)
        }
    }
}

/// MailCore 回调 → async/await 的桥接（内部类型，便于测试直接驱动回调）。
///
/// 操作在传入的串行队列上执行；回调与超时 watchdog 经 `CallbackGate`
/// 只生效一次。有返回值的操作走 `perform`；Void 操作走 `performVoid`——
/// MailCore 的 Void 回调成功时是 `completion(nil, nil)`，若按 `perform`
/// 的「无 value 即空结果」规则处理，会被误判为协议错误。
struct MailCoreCallbackBridge: Sendable {
    let queue: DispatchQueue

    func perform<T: Sendable>(
        timeout: TimeInterval = MailCoreAdapter.operationTimeout,
        _ run: @escaping (@escaping (T?, Error?) -> Void) -> Void
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            let gate = CallbackGate()
            queue.asyncAfter(deadline: .now() + timeout) {
                _ = gate.once {
                    continuation.resume(throwing: MailError.network)
                }
            }
            queue.async {
                run { value, error in
                    _ = gate.once {
                        if let error {
                            continuation.resume(throwing: MailCoreAdapter.mapError(error))
                        } else if let value {
                            continuation.resume(returning: value)
                        } else {
                            continuation.resume(throwing: MailError.protocolError("empty result"))
                        }
                    }
                }
            }
        }
    }

    /// 无返回值操作：`error == nil` 即成功，不再要求回调携带 value。
    func performVoid(
        timeout: TimeInterval = MailCoreAdapter.operationTimeout,
        _ run: @escaping (@escaping (Error?) -> Void) -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let gate = CallbackGate()
            queue.asyncAfter(deadline: .now() + timeout) {
                _ = gate.once {
                    continuation.resume(throwing: MailError.network)
                }
            }
            queue.async {
                run { error in
                    _ = gate.once {
                        if let error {
                            continuation.resume(throwing: MailCoreAdapter.mapError(error))
                        } else {
                            continuation.resume()
                        }
                    }
                }
            }
        }
    }
}

/// 回调只允许生效一次（回调或超时谁先到）。
private final class CallbackGate: @unchecked Sendable {
    private let lock = NSLock()
    private var completed = false

    func once(_ body: () -> Void) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !completed else { return false }
        completed = true
        body()
        return true
    }
}

private extension String {
    var nonEmptyOrNil: String? {
        isEmpty ? nil : self
    }
}
