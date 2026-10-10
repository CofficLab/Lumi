import Foundation
import MailCore

/// Phase 0 Spike 冒烟验证：确认 MailCore ObjC API 在 Swift 中可用。
/// 本文件在 Spike 结论落定后由 MailCoreAdapter 正式实现替换。
enum SpikeSmoke {
    static func verify() {
        let session = MCOIMAPSession()
        session.hostname = "imap.example.com"
        session.port = 993
        session.username = "user@example.com"
        session.password = "app-password"
        session.connectionType = .TLS
        _ = session.connectionType
        _ = MCOIMAPMessagesRequestKind.headers
        _ = session.folderInfoOperation("INBOX")
        let uids = MCOIndexSet(range: MCORangeMake(1, UINT64_MAX))
        _ = session.fetchMessagesOperation(
            withFolder: "INBOX",
            requestKind: [.headers, .structure],
            uids: uids
        )
        _ = session.fetchMessageOperation(withFolder: "INBOX", uid: 1)
        _ = MCOMessageBuilder()
    }
}
