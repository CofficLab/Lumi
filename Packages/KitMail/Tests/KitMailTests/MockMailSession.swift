import Foundation
@testable import KitMail

/// 内存版 `MailSessionServing`：验证协议可 mock，并作为 Phase 2 单测的
/// 会话替身模式参考（Phase 2 在自己的测试 target 内自建等价实现）。
final class MockMailSession: MailSessionServing, @unchecked Sendable {
    var failConnect = false
    var failFetch = false
    private var messages: [MailMessageSummary] = []
    private var details: [UInt64: MailMessageDetail] = [:]

    init() {
        var seed: [MailMessageSummary] = []
        for uid in 1...5 {
            seed.append(
                MailMessageSummary(
                    accountID: UUID(),
                    folder: "INBOX",
                    uid: UInt64(uid),
                    messageID: "<m\(uid)@example.com>",
                    subject: "Message \(uid)",
                    from: MailAddress(displayName: "Alice", email: "alice@example.com"),
                    date: Date(timeIntervalSince1970: 1_700_000_000 + Double(uid)),
                    isRead: uid % 2 == 0,
                    hasAttachment: uid == 3
                )
            )
        }
        messages = seed
    }

    func connect() async throws {
        if failConnect { throw MailError.authFailed }
    }

    func disconnect() async {}

    func listFolders() async throws -> [MailFolder] {
        [
            MailFolder(path: "INBOX", kind: .inbox, unreadCount: 2),
            MailFolder(path: "Sent Mail", kind: .sent),
        ]
    }

    func fetchMessages(
        folder: String,
        sinceUID: UInt64?,
        limit: Int
    ) async throws -> [MailMessageSummary] {
        if failFetch { throw MailError.network }
        var result = messages
        if let sinceUID {
            result = result.filter { $0.uid > sinceUID }
        }
        return Array(result.suffix(limit))
    }

    func fetchBody(uid: UInt64, folder: String) async throws -> MailMessageDetail {
        guard let summary = messages.first(where: { $0.uid == uid }) else {
            throw MailError.notFound
        }
        return MailMessageDetail(
            summary: summary,
            htmlBody: "<p>Body \(uid)</p>",
            plainTextBody: "Body \(uid)"
        )
    }

    func setFlags(uid: UInt64, folder: String, isRead: Bool?, isFlagged: Bool?) async throws {}

    func search(query: String, folder: String) async throws -> [UInt64] {
        messages.filter { $0.subject.contains(query) }.map(\.uid)
    }

    func sendMessage(mime: Data) async throws {}

    func appendDraft(mime: Data, folder: String) async throws {}

    // MARK: - 辅助（测试断言用）

    func recordDetail(uid: UInt64, detail: MailMessageDetail) {
        details[uid] = detail
    }
}
