import Foundation
import KitMail

/// 内存会话替身（工厂注入用，不联网）。
/// 支持测试中更新消息集，用于同步/增量/删除/未读变化场景。
final class MockMailSessionFactory: MailSessionFactory, @unchecked Sendable {
    struct Behavior {
        var failConnect = false
        var failMessages = false
        var failFolders = false
        var failSearch = false
    }

    private let behavior: Behavior
    private let messages: [MailMessageSummary]
    nonisolated(unsafe) private(set) var createdCount = 0

    init(
        behavior: Behavior = Behavior(),
        messages: [MailMessageSummary] = []
    ) {
        self.behavior = behavior
        self.messages = messages
    }

    func makeSession(
        account: MailAccountConfig,
        password: String
    ) async throws -> any MailSessionServing {
        createdCount += 1
        return MockMailSession(behavior: behavior, messages: messages)
    }
}

/// 可变消息集的内存 IMAP 替身。
actor MockMailSession: MailSessionServing {
    private let behavior: MockMailSessionFactory.Behavior
    private var messages: [MailMessageSummary]
    private(set) var connected = false
    /// 已记录的 setFlags 调用（断言用）。
    private(set) var flagUpdates: [(uid: UInt64, folder: String, isRead: Bool?, isFlagged: Bool?)] = []

    init(behavior: MockMailSessionFactory.Behavior = MockMailSessionFactory.Behavior(), messages: [MailMessageSummary]) {
        self.behavior = behavior
        self.messages = messages
    }

    /// 测试钩子：替换消息集（模拟服务器端新增/删除/未读变化）。
    func updateMessages(_ new: [MailMessageSummary]) {
        messages = new
    }

    func connect() async throws {
        if behavior.failConnect {
            throw MailError.authFailed
        }
        connected = true
    }

    func disconnect() async {
        connected = false
    }

    func listFolders() async throws -> [MailFolder] {
        if behavior.failFolders { throw MailError.network }
        return [
            MailFolder(path: "INBOX", kind: .inbox, delimiter: "/"),
            MailFolder(path: "[Gmail]/Sent Mail", kind: .sent, delimiter: "/"),
        ]
    }

    func fetchMessages(folder: String, sinceUID: UInt64?, limit: Int) async throws -> [MailMessageSummary] {
        if behavior.failMessages { throw MailError.protocolError("mock fetch failure") }
        var filtered = messages.filter { $0.folder == folder }
        if let sinceUID {
            filtered = filtered.filter { $0.uid > sinceUID }
        }
        return Array(filtered.prefix(limit))
    }

    func fetchBody(uid: UInt64, folder: String) async throws -> MailMessageDetail {
        MailMessageDetail(
            summary: messages.first { $0.uid == uid } ?? MailMessageSummary(
                accountID: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
                folder: folder,
                uid: uid,
                subject: "Subject",
                from: MailAddress(displayName: nil, email: "a@b.com"),
                date: Date(),
                isRead: false,
                isFlagged: false,
                hasAttachment: false
            ),
            htmlBody: "<p>Hello</p>",
            plainTextBody: "Hello",
            attachments: []
        )
    }

    func setFlags(uid: UInt64, folder: String, isRead: Bool?, isFlagged: Bool?) async throws {
        flagUpdates.append((uid, folder, isRead, isFlagged))
        if let index = messages.firstIndex(where: { $0.uid == uid && $0.folder == folder }) {
            if let isRead { messages[index].isRead = isRead }
            if let isFlagged { messages[index].isFlagged = isFlagged }
        }
    }

    func search(query: String, folder: String) async throws -> [UInt64] {
        if behavior.failSearch { throw MailError.network }
        return messages.filter { $0.folder == folder }.map(\.uid)
    }

    func sendMessage(mime: Data) async throws {}

    func appendDraft(mime: Data, folder: String) async throws {}
}
