import XCTest
import KitAgentTool
import KitMail
@testable import PluginMail

final class MailAgentToolsTests: XCTestCase {
    private var cache: MailCacheService!
    private var dbURL: URL!
    private let accountID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

    override func setUp() {
        super.setUp()
        MailAccountStore.reset()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MailAgentTests-\(UUID().uuidString)", isDirectory: true)
        dbURL = dir
        cache = MailCacheService(databaseDirectory: dir)
    }

    override func tearDown() {
        cache = nil
        try? FileManager.default.removeItem(at: dbURL)
        MailAccountStore.reset()
        super.tearDown()
    }

    private func makeAccount() -> MailAccountConfig {
        MailAccountConfig(
            id: accountID,
            displayName: "张三",
            email: "zhangsan@example.com",
            imapHost: "imap.example.com",
            imapPort: 993,
            smtpHost: "smtp.example.com",
            smtpPort: 465,
            username: "zhangsan"
        )
    }

    private func makeService(session: MockMailSession) -> MailAgentToolService {
        let manager = MailSessionManager(factory: SingleAgentSessionFactory(session: session))
        return MailAgentToolService(
            sessionManager: manager,
            cache: cache,
            composer: MailComposerService(sessionManager: manager)
        )
    }

    private func summary(uid: UInt64, subject: String) -> MailMessageSummary {
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

    // MARK: - 工具分级

    func testRiskLevelsAndCapabilities() {
        let service = MailAgentToolService(
            sessionManager: MailSessionManager(factory: SingleAgentSessionFactory(session: MockMailSession(messages: []))),
            cache: cache,
            composer: MailComposerService(sessionManager: MailSessionManager(factory: SingleAgentSessionFactory(session: MockMailSession(messages: []))))
        )
        XCTAssertEqual(MailListMessagesTool(service: service).permissionRiskLevel(arguments: [:]), .safe)
        XCTAssertEqual(MailReadMessageTool(service: service).permissionRiskLevel(arguments: [:]), .safe)
        XCTAssertEqual(MailSearchMessagesTool(service: service).permissionRiskLevel(arguments: [:]), .safe)
        XCTAssertEqual(MailSendMessageTool(service: service).permissionRiskLevel(arguments: [:]), .high)
        XCTAssertTrue(MailSendMessageTool(service: service).requiresExplicitApproval(arguments: [:]))
        XCTAssertEqual(MailListMessagesTool(service: service).executionCapability, .parallelReadOnly)
        XCTAssertEqual(MailSendMessageTool(service: service).executionCapability, .serialSideEffect)
    }

    // MARK: - 工具执行

    func testListMessagesWithoutAccount() async throws {
        let service = makeService(session: MockMailSession(messages: []))
        // 无账户 → 提示配置
        let tool = MailListMessagesTool(service: service)
        let result = try await tool.execute(arguments: [:])
        XCTAssertTrue(result.contains("没有可用的邮件账户"))
    }

    func testListMessagesReturnsRecentSummaries() async throws {
        MailAccountStore.upsertAccount(makeAccount())
        MailAccountStore.setPassword("p", for: accountID)
        let session = MockMailSession(messages: [
            summary(uid: 1, subject: "Hello"),
            summary(uid: 2, subject: "World"),
        ])
        let service = makeService(session: session)
        let tool = MailListMessagesTool(service: service)
        let result = try await tool.execute(arguments: [
            "limit": ToolArgument(5),
            "folder": ToolArgument("INBOX"),
        ])
        XCTAssertTrue(result.contains("Hello"))
        XCTAssertTrue(result.contains("uid=2"))
        XCTAssertTrue(result.contains("【未读】"))
    }

    func testReadMessageMarksAsReadAndReturnsBody() async throws {
        MailAccountStore.upsertAccount(makeAccount())
        MailAccountStore.setPassword("p", for: accountID)
        let session = MockMailSession(messages: [summary(uid: 7, subject: "Report")])
        let service = makeService(session: session)
        let tool = MailReadMessageTool(service: service)
        let result = try await tool.execute(arguments: [
            "uid": ToolArgument(7),
        ])
        XCTAssertTrue(result.contains("Report"), "应含主题")
        XCTAssertTrue(result.contains("Hello"), "应含正文")

        let flags = await session.flagUpdates
        XCTAssertEqual(flags.first?.uid, 7)
        XCTAssertEqual(flags.first?.isRead, true)
    }

    func testSearchMessagesFindsCachedHits() async throws {
        MailAccountStore.upsertAccount(makeAccount())
        try await cache.upsertMessages(
            [summary(uid: 1, subject: "Meeting notes")],
            accountID: accountID,
            folder: "INBOX"
        )
        let service = makeService(session: MockMailSession(messages: []))
        let tool = MailSearchMessagesTool(service: service)
        let result = try await tool.execute(arguments: ["query": ToolArgument("meeting")])
        XCTAssertTrue(result.contains("Meeting notes"))
    }

    func testSendMessageSendsAndAppends() async throws {
        MailAccountStore.upsertAccount(makeAccount())
        MailAccountStore.setPassword("p", for: accountID)
        let session = MockMailSession(messages: [])
        let service = makeService(session: session)
        let tool = MailSendMessageTool(service: service)
        let result = try await tool.execute(arguments: [
            "to": ToolArgument("lisi@example.com"),
            "subject": ToolArgument("Hello from Agent"),
            "body": ToolArgument("Agent body"),
        ])
        XCTAssertTrue(result.contains("已发送"))
        let sent = await session.sentMIMEs
        XCTAssertEqual(sent.count, 1)
        let mime = String(data: sent[0], encoding: .utf8) ?? ""
        XCTAssertTrue(mime.contains("Hello from Agent"))
        let appended = await session.appendedDrafts
        XCTAssertEqual(appended.count, 1)
    }

    func testSendMessageThrowsAuthFailedWithoutCredentials() async {
        // 无账户：notFound（accountFor 抛 notFound）
        let service = makeService(session: MockMailSession(messages: []))
        let tool = MailSendMessageTool(service: service)
        do {
            _ = try await tool.execute(arguments: [
                "to": ToolArgument("x@y.com"),
                "subject": ToolArgument("S"),
                "body": ToolArgument("B"),
            ])
            XCTFail("expected error")
        } catch let error as MailError {
            XCTAssertEqual(error, .notFound)
        } catch {
            XCTFail("unexpected \(error)")
        }
    }
}

/// 固定返回同一 session 的工厂（Agent 工具测试用）。
private final class SingleAgentSessionFactory: MailSessionFactory, @unchecked Sendable {
    private let session: MockMailSession

    init(session: MockMailSession) {
        self.session = session
    }

    func makeSession(account: MailAccountConfig, password: String) async throws -> any MailSessionServing {
        session
    }
}
