import Foundation
import Combine
import KitMail

/// 撰写模式。
public enum MailComposeMode: Sendable, Equatable {
    case new
    case reply
    case forward
}

/// 撰写 ViewModel：新写/回复/转发三模式 + 本地自动保存草稿 + 发送状态机。
@MainActor
final class MailComposeViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case sending
        case sent
        case failed(String)
    }

    // 依赖
    private let composer: MailComposerService
    private let account: MailAccountConfig
    private let sessionManager: MailSessionManager
    /// 插件数据目录（由 `MailPlugin` 经 `StorageProviding` 解析后注入）。
    private let dataDirectory: URL

    // 模式与上下文
    let mode: MailComposeMode
    private let originalDetail: MailMessageDetail?

    // 表单
    @Published var to = ""
    @Published var cc = ""
    @Published var subject = ""
    @Published var body = ""
    @Published var attachments: [MimeAttachmentData] = []

    // 状态
    @Published private(set) var phase: Phase = .idle
    @Published var draftSavedAt: Date?

    // 草稿自动保存
    private let draftStore: any MailDraftSaving
    private let draftSaveDelay: Duration
    private var draftSaveTask: Task<Void, Never>?
    private var draftSaveGeneration = 0
    private var attachmentsRevision = 0

    /// 本地草稿文件路径（自动保存）。
    private var draftURL: URL { draftURLs.text }

    /// 附件单独落盘：纯文本编辑只重写小的草稿 JSON（见 issue #1188）。
    private var draftAttachmentsURL: URL { draftURLs.attachments }

    private var draftURLs: (text: URL, attachments: URL) {
        Self.draftURLs(
            dataDirectory: dataDirectory,
            accountID: account.id,
            modeKey: mode.key,
            uid: originalDetail?.summary.uid ?? 0
        )
    }

    private nonisolated static func draftURLs(
        dataDirectory: URL,
        accountID: UUID,
        modeKey: String,
        uid: UInt64
    ) -> (text: URL, attachments: URL) {
        let directory = dataDirectory.appendingPathComponent("drafts", isDirectory: true)
        let key = "\(accountID.uuidString)-\(modeKey)-\(uid)"
        return (
            directory.appendingPathComponent("\(key).json"),
            directory.appendingPathComponent("\(key).attachments.json")
        )
    }

    init(
        composer: MailComposerService,
        sessionManager: MailSessionManager,
        account: MailAccountConfig,
        dataDirectory: URL,
        mode: MailComposeMode,
        originalDetail: MailMessageDetail? = nil,
        draftStore: (any MailDraftSaving)? = nil,
        draftSaveDelay: Duration = .milliseconds(400)
    ) {
        self.composer = composer
        self.sessionManager = sessionManager
        self.account = account
        self.dataDirectory = dataDirectory
        self.mode = mode
        self.originalDetail = originalDetail
        self.draftSaveDelay = draftSaveDelay
        // 同一账户/模式/原邮件上下文存在本地草稿时优先恢复，否则用模式默认内容。
        let urls = Self.draftURLs(
            dataDirectory: dataDirectory,
            accountID: account.id,
            modeKey: mode.key,
            uid: originalDetail?.summary.uid ?? 0
        )
        let restored = Self.readDraft(
            textURL: urls.text,
            attachmentsURL: urls.attachments,
            modeKey: mode.key
        )
        self.draftStore = draftStore ?? MailDraftStore(
            restoredAttachmentsRevision: restored?.attachmentsOnDisk == true ? 0 : nil
        )
        if let restored {
            to = restored.payload.to
            cc = restored.payload.cc
            subject = restored.payload.subject
            body = restored.payload.body
            attachments = restored.attachments
            draftSavedAt = restored.savedAt
        } else {
            applyModeDefaults()
        }
    }

    // MARK: - 模式预填

    private func applyModeDefaults() {
        switch mode {
        case .new:
            break
        case .reply:
            guard let original = originalDetail else { return }
            if let from = original.summary.from {
                to = from.email
            }
            subject = prefix("Re:", original.summary.subject)
            body = MimeMessageBuilder.quotedReplyText(
                originalDate: original.summary.date,
                originalFrom: original.summary.from,
                originalBody: original.plainTextBody
            )
        case .forward:
            guard let original = originalDetail else { return }
            subject = prefix("Fw:", original.summary.subject)
            body = forwardQuote(original)
        }
    }

    private func prefix(_ marker: String, _ subject: String) -> String {
        guard !subject.isEmpty else { return marker }
        if subject.hasPrefix(marker) { return subject }
        return "\(marker) \(subject)"
    }

    private func forwardQuote(_ original: MailMessageDetail) -> String {
        var lines = ["---------- Forwarded message ----------"]
        if let from = original.summary.from {
            lines.append("From: \(from.rfc5322)")
        }
        lines.append("Date: \(original.summary.date.formatted(date: .long, time: .shortened))")
        lines.append("Subject: \(original.summary.subject)")
        lines.append("To: \(original.summary.to.map(\.rfc5322).joined(separator: ", "))")
        lines.append("")
        if let body = original.plainTextBody {
            lines.append(body)
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - 草稿恢复与自动保存

    private struct RestoredDraft {
        var payload: MailDraftPayload
        var attachments: [MimeAttachmentData]
        var savedAt: Date?
        /// 附件是否已存放在独立文件里。旧格式内嵌附件时为 false，
        /// 首次保存需要把附件迁移到独立文件，否则纯文本编辑会丢掉附件。
        var attachmentsOnDisk: Bool
    }

    /// 读取本地草稿；文件缺失、损坏或模式不匹配时返回 nil。
    private nonisolated static func readDraft(
        textURL: URL,
        attachmentsURL: URL,
        modeKey: String
    ) -> RestoredDraft? {
        guard let data = try? Data(contentsOf: textURL),
              let payload = try? JSONDecoder().decode(MailDraftPayload.self, from: data),
              payload.mode == modeKey
        else { return nil }

        let stored: [MailDraftAttachment]
        let attachmentsOnDisk: Bool
        if let legacy = payload.attachments {
            stored = legacy
            attachmentsOnDisk = false
        } else {
            stored = (try? Data(contentsOf: attachmentsURL)).flatMap {
                try? JSONDecoder().decode([MailDraftAttachment].self, from: $0)
            } ?? []
            attachmentsOnDisk = true
        }
        let savedAt = (try? FileManager.default
            .attributesOfItem(atPath: textURL.path)[.modificationDate]) as? Date
        return RestoredDraft(
            payload: payload,
            attachments: stored.map {
                MimeAttachmentData(filename: $0.filename, mimeType: $0.mimeType, data: $0.data)
            },
            savedAt: savedAt,
            attachmentsOnDisk: attachmentsOnDisk
        )
    }

    /// 编辑后调用：合并连续击键，延迟落盘。
    func scheduleDraftSave() {
        draftSaveTask?.cancel()
        let delay = draftSaveDelay
        draftSaveTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            self.draftSaveTask = nil
            await self.saveDraftNow()
        }
    }

    /// 立即落盘当前草稿（取消防抖）。编码与文件 IO 都在主线程之外执行。
    func saveDraftNow() async {
        draftSaveTask?.cancel()
        draftSaveTask = nil
        draftSaveGeneration += 1
        let generation = draftSaveGeneration
        let snapshot = MailDraftSnapshot(
            textURL: draftURL,
            attachmentsURL: draftAttachmentsURL,
            payload: MailDraftPayload(
                mode: mode.key,
                to: to,
                cc: cc,
                subject: subject,
                body: body,
                attachments: nil
            ),
            attachments: attachments.map {
                MailDraftAttachment(filename: $0.filename, mimeType: $0.mimeType, data: $0.data)
            },
            attachmentsRevision: attachmentsRevision
        )
        do {
            let written = try await draftStore.save(snapshot, generation: generation)
            guard generation == draftSaveGeneration, written else { return }
            draftSavedAt = .now
        } catch {
            // 自动保存失败不阻断编辑，静默忽略。
        }
    }

    /// 关闭撰写窗口时把防抖窗口内的最后一次编辑落盘，避免丢字。
    func flushDraftSaveOnClose() {
        guard phase != .sent else { return }
        Task { await saveDraftNow() }
    }

    // MARK: - 发送

    func send() {
        guard phase != .sending else { return }
        let recipients = parseAddresses(to)
        guard !recipients.isEmpty else {
            phase = .failed("收件人不能为空。")
            return
        }
        phase = .sending
        let draft = MimeMessageDraft(
            from: MailAddress(displayName: account.displayName, email: account.email),
            to: recipients,
            cc: parseAddresses(cc),
            subject: subject,
            htmlBody: nil,
            plainTextBody: body,
            attachments: attachments,
            inReplyTo: originalDetail?.summary.messageID,
            references: originalDetail.map {
                MimeMessageBuilder.replyReferences(
                    originalReferences: $0.summary.references,
                    originalMessageID: $0.summary.messageID
                )
            } ?? []
        )
        Task {
            do {
                try await composer.send(draft: draft, account: account)
                phase = .sent
                await discardLocalDraft()
            } catch let error as MailError {
                phase = .failed(error.localizedDescription)
                await saveDraftNow() // 失败保留草稿
            } catch {
                phase = .failed(error.localizedDescription)
                await saveDraftNow()
            }
        }
    }

    /// 添加附件（拖入/选择）。
    func addAttachment(_ data: Data, filename: String) {
        attachments.append(
            MimeAttachmentData(
                filename: filename,
                mimeType: mimeType(for: filename),
                data: data
            )
        )
        attachmentsRevision += 1
        scheduleDraftSave()
    }

    func removeAttachment(at index: Int) {
        guard attachments.indices.contains(index) else { return }
        attachments.remove(at: index)
        attachmentsRevision += 1
        scheduleDraftSave()
    }

    // MARK: - 工具

    private func parseAddresses(_ raw: String) -> [MailAddress] {
        raw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { MailAddress(displayName: nil, email: String($0)) }
    }

    private func mimeType(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "application/pdf"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "txt": return "text/plain"
        case "zip": return "application/zip"
        default: return "application/octet-stream"
        }
    }

    private func discardLocalDraft() async {
        draftSaveTask?.cancel()
        draftSaveTask = nil
        draftSaveGeneration += 1
        let generation = draftSaveGeneration
        await draftStore.discard(
            textURL: draftURL,
            attachmentsURL: draftAttachmentsURL,
            generation: generation
        )
    }
}

// MARK: - 本地草稿序列化

private extension MailComposeMode {
    var key: String {
        switch self {
        case .new: return "new"
        case .reply: return "reply"
        case .forward: return "forward"
        }
    }
}
