import Foundation
import KitAgentTool
import KitMail
import KitTestSupport
import Testing
@testable import PluginMail

/// 回归 #840：`account_id` 传了但非法时，四个 Mail 工具都必须报参数错误。
///
/// 原先「没传」和「传了但解析失败」都变成 nil，`accountFor(nil)` 统一选第一个
/// 账户：调用方把 ID 写错时收不到任何参数错误，`mail_send_message` 还会在审批
/// 通过后从**错误的邮箱**把信寄出去。
@Suite("Mail 工具的 account_id 参数校验")
struct MailAccountIDArgumentTests {

    // MARK: - 非法参数必须被拒绝

    @Test("四个工具都必须拒绝非法 account_id，且不触达 IMAP/SMTP（回归 #840）")
    func invalidAccountIDIsRejectedByEveryTool() async throws {
        let harness = try MailToolsHarness()
        let arguments: [String: ToolArgument] = ["account_id": ToolArgument("not-a-uuid")]

        for (tool, extra) in harness.tools() {
            try await expectAccountIDRejection(tool, arguments: extra.merging(arguments) { _, new in new })
        }

        let sent = await harness.session.sentMIMEs
        let appended = await harness.session.appendedMessages
        let flags = await harness.session.flagUpdates
        #expect(harness.factory.createdCount == 0, "非法 account_id 不得创建任何会话")
        #expect(sent.isEmpty, "非法 account_id 不得寄出邮件")
        #expect(appended.isEmpty, "非法 account_id 不得归档到 Sent")
        #expect(flags.isEmpty, "非法 account_id 不得改动已读标记")
    }

    @Test("空串与纯空白的 account_id 必须被拒绝（回归 #840）")
    func emptyAndWhitespaceAccountIDAreRejected() async throws {
        let harness = try MailToolsHarness()

        for raw in ["", "   ", "\n\t"] {
            for (tool, extra) in harness.tools() {
                try await expectAccountIDRejection(
                    tool,
                    arguments: extra.merging(["account_id": ToolArgument(raw)]) { _, new in new }
                )
            }
        }

        let sent = await harness.session.sentMIMEs
        #expect(harness.factory.createdCount == 0)
        #expect(sent.isEmpty)
    }

    @Test("非字符串类型的 account_id 必须被拒绝（回归 #840）")
    func nonStringAccountIDIsRejected() async throws {
        let harness = try MailToolsHarness()
        let wrongTypes: [Any] = [42, true, NSNull(), [harness.first.id.uuidString], ["id": harness.first.id.uuidString]]

        for value in wrongTypes {
            for (tool, extra) in harness.tools() {
                try await expectAccountIDRejection(
                    tool,
                    arguments: extra.merging(["account_id": ToolArgument(value)]) { _, new in new }
                )
            }
        }

        let sent = await harness.session.sentMIMEs
        #expect(harness.factory.createdCount == 0)
        #expect(sent.isEmpty)
    }

    @Test("格式合法但不存在的 account_id 必须报错，不得伪装成空结果（回归 #840）")
    func unknownAccountIDIsAnErrorNotAnEmptyResult() async throws {
        let harness = try MailToolsHarness()
        let unknown = UUID().uuidString

        // list 原先把 notFound 吞成「没有可用的邮件账户」的成功文案。
        do {
            let result = try await MailListMessagesTool(service: harness.service)
                .execute(arguments: ["account_id": ToolArgument(unknown)])
            Issue.record("不存在的账户不得返回成功文案：\(result)")
        } catch let error as ToolExecutionError {
            #expect((error.errorDescription ?? "").contains("account_id"))
        }

        let sendTool = MailSendMessageTool(service: harness.service)
        do {
            _ = try await sendTool.execute(arguments: harness.sendArguments.merging(
                ["account_id": ToolArgument(unknown)]
            ) { _, new in new })
            Issue.record("不存在的账户不得寄信")
        } catch let error as MailError {
            #expect(error == .notFound)
        }

        let sent = await harness.session.sentMIMEs
        #expect(harness.factory.createdCount == 0)
        #expect(sent.isEmpty)
    }

    // MARK: - 合法参数仍按原语义工作

    @Test("完全省略 account_id 时仍使用第一个账户")
    func omittedAccountIDStillUsesFirstAccount() async throws {
        let harness = try MailToolsHarness(messages: [harnessSummary(accountID: firstAccountID, uid: 1, subject: "First inbox")])

        let listed = try await MailListMessagesTool(service: harness.service).execute(arguments: [:])
        #expect(listed.contains(harness.first.email), "省略参数时应列出第一个账户")
        #expect(listed.contains("First inbox"))

        let sent = try await MailSendMessageTool(service: harness.service)
            .execute(arguments: harness.sendArguments)
        #expect(sent.contains("已发送"))
        let mime = try #require(await harness.session.sentMIMEs.first)
        let text = String(data: mime, encoding: .utf8) ?? ""
        #expect(text.contains(harness.first.email), "省略参数时应从第一个账户寄出")
        #expect(!text.contains(harness.second.email))
    }

    @Test("传入合法 account_id 时必须使用该账户，而不是第一个")
    func validAccountIDSelectsThatAccount() async throws {
        let harness = try MailToolsHarness()

        _ = try await MailSendMessageTool(service: harness.service).execute(
            arguments: harness.sendArguments.merging(
                ["account_id": ToolArgument(harness.second.id.uuidString)]
            ) { _, new in new }
        )

        let mime = try #require(await harness.session.sentMIMEs.first)
        let text = String(data: mime, encoding: .utf8) ?? ""
        #expect(text.contains(harness.second.email), "应从第二个账户寄出")
        #expect(!text.contains(harness.first.email), "不得回落到第一个账户")
    }

    @Test("UUID 两侧的空白被裁掉后仍视为合法")
    func surroundingWhitespaceIsTrimmed() async throws {
        let harness = try MailToolsHarness()

        _ = try await MailSendMessageTool(service: harness.service).execute(
            arguments: harness.sendArguments.merging(
                ["account_id": ToolArgument("  \(harness.second.id.uuidString)\n")]
            ) { _, new in new }
        )

        let mime = try #require(await harness.session.sentMIMEs.first)
        #expect((String(data: mime, encoding: .utf8) ?? "").contains(harness.second.email))
    }

    @Test("搜索只读被请求账户的缓存")
    func searchReadsOnlyTheRequestedAccountCache() async throws {
        let harness = try MailToolsHarness()
        try await harness.cache.upsertMessages(
            [harnessSummary(accountID: harness.first.id, uid: 1, subject: "First secret")],
            accountID: harness.first.id,
            folder: "INBOX"
        )
        try await harness.cache.upsertMessages(
            [harnessSummary(accountID: harness.second.id, uid: 2, subject: "Second notes")],
            accountID: harness.second.id,
            folder: "INBOX"
        )

        let result = try await MailSearchMessagesTool(service: harness.service).execute(arguments: [
            "query": ToolArgument("notes"),
            "account_id": ToolArgument(harness.second.id.uuidString),
        ])
        #expect(result.contains("Second notes"))
        #expect(!result.contains("First secret"), "不得混入第一个账户的缓存")
    }

    @Test("schema 必须说明省略与非法值的处理方式")
    func accountIDSchemaDocumentsRejection() throws {
        let harness = try MailToolsHarness()

        for (tool, _) in harness.tools() {
            let schema = tool.inputSchema(for: .english)
            let properties = try #require(schema["properties"] as? [String: Any])
            let accountID = try #require(properties["account_id"] as? [String: Any])
            let description = try #require(accountID["description"] as? String)
            #expect(description.contains("Omit"), "\(tool.name) 应说明可省略")
            #expect(description.contains("rejected"), "\(tool.name) 应说明非法值会被拒绝")
        }
    }

    // MARK: - 辅助

    private func expectAccountIDRejection(
        _ tool: any SuperAgentTool,
        arguments: [String: ToolArgument]
    ) async throws {
        do {
            let result = try await tool.execute(arguments: arguments)
            Issue.record("\(tool.name) 应拒绝非法 account_id，实际返回：\(result)")
        } catch let error as ToolExecutionError {
            #expect(
                (error.errorDescription ?? "").contains("account_id"),
                "\(tool.name) 的错误信息应指出 account_id：\(error.errorDescription ?? "")"
            )
        }
    }
}

// MARK: - 夹具

private let firstAccountID = UUID(uuidString: "AAAAAAAA-1111-1111-1111-111111111111")!
private let secondAccountID = UUID(uuidString: "BBBBBBBB-2222-2222-2222-222222222222")!

private func harnessSummary(accountID: UUID, uid: UInt64, subject: String) -> MailMessageSummary {
    MailMessageSummary(
        accountID: accountID,
        folder: "INBOX",
        uid: uid,
        subject: subject,
        from: MailAddress(displayName: "李四", email: "lisi@example.com"),
        date: Date(timeIntervalSince1970: TimeInterval(uid)),
        isRead: false
    )
}

/// 两个账户（A 在前、B 在后）+ 内存会话替身，不联网、不碰真实 Keychain。
private final class MailToolsHarness {
    let fixture: MailAccountStoreFixture
    let first: MailAccountConfig
    let second: MailAccountConfig
    let session: MockMailSession
    let factory: MockMailSessionFactory
    let service: MailAgentToolService
    var cache: MailCacheService!
    private let cacheDirectory: TemporaryDirectory

    init(messages: [MailMessageSummary] = []) throws {
        fixture = try MailAccountStoreFixture()
        cacheDirectory = try TemporaryDirectory.make("mail-account-id")
        cache = MailCacheService(databaseDirectory: cacheDirectory.url)

        first = Self.account(id: firstAccountID, email: "first@example.com", displayName: "第一个")
        second = Self.account(id: secondAccountID, email: "second@example.com", displayName: "第二个")
        _ = fixture.store.upsertAccount(first)
        _ = fixture.store.upsertAccount(second)
        fixture.store.setPassword("p", for: first.id)
        fixture.store.setPassword("p", for: second.id)

        session = MockMailSession(messages: messages)
        factory = MockMailSessionFactory(session: session)
        let manager = MailSessionManager(factory: factory, accountStore: fixture.store)
        service = MailAgentToolService(
            sessionManager: manager,
            cache: cache,
            composer: MailComposerService(sessionManager: manager, accountStore: fixture.store),
            accountStore: fixture.store
        )
    }

    deinit {
        cache = nil
        cacheDirectory.remove()
    }

    /// 四个生产工具及各自除 account_id 外的必需参数。
    func tools() -> [(any SuperAgentTool, [String: ToolArgument])] {
        [
            (MailListMessagesTool(service: service), ["folder": ToolArgument("INBOX")]),
            (MailReadMessageTool(service: service), ["uid": ToolArgument(1)]),
            (MailSearchMessagesTool(service: service), ["query": ToolArgument("hello")]),
            (MailSendMessageTool(service: service), sendArguments),
        ]
    }

    var sendArguments: [String: ToolArgument] {
        [
            "to": ToolArgument("lisi@example.com"),
            "subject": ToolArgument("Subject"),
            "body": ToolArgument("Body"),
        ]
    }

    private static func account(id: UUID, email: String, displayName: String) -> MailAccountConfig {
        MailAccountConfig(
            id: id,
            displayName: displayName,
            email: email,
            imapHost: "imap.example.com",
            imapPort: 993,
            smtpHost: "smtp.example.com",
            smtpPort: 465,
            username: email
        )
    }
}