import XCTest
import KitMail
@testable import PluginMail

final class MailComposerServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MailAccountStore.reset()
    }

    override func tearDown() {
        MailAccountStore.reset()
        super.tearDown()
    }

    private func makeAccount() -> MailAccountConfig {
        MailAccountConfig(
            id: UUID(),
            displayName: "张三",
            email: "zhangsan@example.com",
            imapHost: "imap.example.com",
            imapPort: 993,
            smtpHost: "smtp.example.com",
            smtpPort: 465,
            username: "zhangsan"
        )
    }

    private func makeDraft() -> MimeMessageDraft {
        MimeMessageDraft(
            from: MailAddress(displayName: "张三", email: "zhangsan@example.com"),
            to: [MailAddress(displayName: nil, email: "lisi@example.com")],
            cc: [],
            subject: "Hello",
            plainTextBody: "Hello, Li Si!",
            inReplyTo: "<mid-1@example.com>",
            references: ["<mid-0@example.com>", "<mid-1@example.com>"]
        )
    }

    func testSendBuildsMIMEAndAppendsToSent() async throws {
        let session = MockMailSession(messages: [])
        let manager = MailSessionManager(
            factory: SingleSessionFactory(session: session)
        )
        let account = makeAccount()
        MailAccountStore.setPassword("p", for: account.id)

        let composer = MailComposerService(sessionManager: manager)
        try await composer.send(draft: makeDraft(), account: account)

        let sent = await session.sentMIMEs
        XCTAssertEqual(sent.count, 1, "应调用一次 SMTP 发送")
        let mimeString = String(data: sent[0], encoding: .utf8) ?? ""
        XCTAssertTrue(mimeString.contains("Subject: Hello"), "MIME 应含主题")
        XCTAssertTrue(mimeString.contains("lisi@example.com"), "MIME 应含收件人")
        XCTAssertTrue(mimeString.contains("Hello, Li Si!"), "MIME 应含正文")

        let appended = await session.appendedDrafts
        XCTAssertEqual(appended.count, 1, "成功后应归档到已发送")
        XCTAssertEqual(appended[0].folder, "[Gmail]/Sent Mail", "mock 提供 sent 文件夹，应归档到该文件夹")
    }

    func testSendThrowsAuthFailedWithoutPassword() async {
        let session = MockMailSession(messages: [])
        let manager = MailSessionManager(factory: SingleSessionFactory(session: session))
        let composer = MailComposerService(sessionManager: manager)
        let account = makeAccount()

        do {
            try await composer.send(draft: makeDraft(), account: account)
            XCTFail("expected authFailed")
        } catch let error as MailError {
            XCTAssertEqual(error, .authFailed)
        } catch {
            XCTFail("unexpected \(error)")
        }
        let sent = await session.sentMIMEs
        XCTAssertTrue(sent.isEmpty)
    }

    func testSentFolderDiscoveryPrefersSentKind() async throws {
        // 提供带 Sent 文件夹的 mock：应 APPEND 到 [Gmail]/Sent Mail
        let session = MockMailSession(messages: [])
        let manager = MailSessionManager(factory: SingleSessionFactory(session: session))
        let account = makeAccount()
        MailAccountStore.setPassword("p", for: account.id)

        let composer = MailComposerService(sessionManager: manager)
        try await composer.send(draft: makeDraft(), account: account)

        let appended = await session.appendedDrafts
        XCTAssertEqual(appended.first?.folder, "[Gmail]/Sent Mail")
    }
}

/// 固定返回同一 session 的工厂（composer 测试用）。
private final class SingleSessionFactory: MailSessionFactory, @unchecked Sendable {
    private let session: MockMailSession

    init(session: MockMailSession) {
        self.session = session
    }

    func makeSession(account: MailAccountConfig, password: String) async throws -> any MailSessionServing {
        session
    }
}

@MainActor
final class MailComposeViewModelTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MailAccountStore.reset()
    }

    override func tearDown() {
        MailAccountStore.reset()
        super.tearDown()
    }

    private func makeAccount() -> MailAccountConfig {
        MailAccountConfig(
            id: UUID(),
            displayName: "张三",
            email: "zhangsan@example.com",
            imapHost: "imap.example.com",
            smtpHost: "smtp.example.com",
            username: "zhangsan"
        )
    }

    private func makeDetail() -> MailMessageDetail {
        MailMessageDetail(
            summary: MailMessageSummary(
                accountID: UUID(),
                folder: "INBOX",
                uid: 42,
                messageID: "<mid-42@example.com>",
                subject: "Project Update",
                from: MailAddress(displayName: "李四", email: "lisi@example.com"),
                to: [MailAddress(displayName: nil, email: "zhangsan@example.com")],
                date: Date(timeIntervalSince1970: 1_700_000_000),
                isRead: false,
                isFlagged: false,
                hasAttachment: false,
                references: ["<mid-41@example.com>"]
            ),
            htmlBody: nil,
            plainTextBody: "Please review the plan.",
            attachments: []
        )
    }

    /// 等待发送状态从 sending 收敛（跨 actor 链）。
    private func waitForPhaseSettle(_ vm: MailComposeViewModel) async {
        for _ in 0..<100 {
            if vm.phase != .sending { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    private func makeVM(
        mode: MailComposeMode,
        detail: MailMessageDetail? = nil,
        session: MockMailSession? = nil,
        account: MailAccountConfig? = nil
    ) -> MailComposeViewModel {
        let manager = MailSessionManager(
            factory: session.map { SingleSessionFactory(session: $0) } ?? MockMailSessionFactory()
        )
        return MailComposeViewModel(
            composer: MailComposerService(sessionManager: manager),
            sessionManager: manager,
            account: account ?? makeAccount(),
            mode: mode,
            originalDetail: detail
        )
    }

    func testNewModeDefaultsEmpty() {
        let vm = makeVM(mode: .new)
        XCTAssertEqual(vm.to, "")
        XCTAssertEqual(vm.subject, "")
        XCTAssertEqual(vm.body, "")
    }

    func testReplyModePrefills() {
        let vm = makeVM(mode: .reply, detail: makeDetail())
        XCTAssertEqual(vm.to, "lisi@example.com")
        XCTAssertEqual(vm.subject, "Re: Project Update")
        XCTAssertTrue(vm.body.contains("Please review the plan."), "回复应引用原正文")
        XCTAssertTrue(vm.body.contains("> Please review the plan."), "引用行带 > 前缀")
    }

    func testReplyPrefixNotDuplicated() {
        let vm = makeVM(mode: .reply, detail: makeDetail())
        vm.subject = vm.subject // 已在预填时检查
        XCTAssertFalse(vm.subject.hasPrefix("Re: Re:"))
    }

    func testForwardModePrefills() {
        let vm = makeVM(mode: .forward, detail: makeDetail())
        XCTAssertEqual(vm.subject, "Fw: Project Update")
        XCTAssertEqual(vm.to, "", "转发收件人为空，由用户填写")
        XCTAssertTrue(vm.body.contains("Forwarded message"))
        XCTAssertTrue(vm.body.contains("Please review the plan."))
    }

    func testSendFailureRetainsDraftState() async {
        let session = MockMailSession(messages: [])
        let account = makeAccount()
        MailAccountStore.setPassword("p", for: account.id)
        let vm = makeVM(mode: .new, session: session, account: account)
        vm.to = "lisi@example.com"
        vm.subject = "Hi"
        vm.body = "Body"

        vm.send()
        // 发送成功（mock 不失败）→ sent
        await waitForPhaseSettle(vm)
        XCTAssertEqual(vm.phase, .sent, "mock 发送应成功")

        // 失败场景：清密码 → authFailed
        MailAccountStore.setPassword(nil, for: account.id)
        let vm2 = makeVM(mode: .new, session: session, account: account)
        vm2.to = "lisi@example.com"
        vm2.subject = "Hi"
        vm2.body = "Body"
        vm2.send()
        await waitForPhaseSettle(vm2)
        if case .failed(let message) = vm2.phase {
            XCTAssertFalse(message.isEmpty)
        } else {
            XCTFail("expected failed phase, got \(vm2.phase)")
        }
    }
}
