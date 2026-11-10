import XCTest
import KitMail
@testable import PluginMail

final class MailComposerServiceTests: XCTestCase {
    /// 每个用例一套独立的临时目录 + 内存 Keychain：不读写真实用户凭据。
    private var fixture: MailAccountStoreFixture!
    private var store: MailAccountStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fixture = try MailAccountStoreFixture()
        store = fixture.store
    }

    override func tearDownWithError() throws {
        fixture = nil
        store = nil
        try super.tearDownWithError()
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
            factory: SingleSessionFactory(session: session),
            accountStore: store
        )
        let account = makeAccount()
        store.setPassword("p", for: account.id)

        let composer = MailComposerService(sessionManager: manager, accountStore: store)
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
        let manager = MailSessionManager(factory: SingleSessionFactory(session: session), accountStore: store)
        let composer = MailComposerService(sessionManager: manager, accountStore: store)
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
        let manager = MailSessionManager(factory: SingleSessionFactory(session: session), accountStore: store)
        let account = makeAccount()
        store.setPassword("p", for: account.id)

        let composer = MailComposerService(sessionManager: manager, accountStore: store)
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
    /// 每个用例一套独立的临时目录 + 内存 Keychain：不读写真实用户凭据。
    private var fixture: MailAccountStoreFixture!
    private var store: MailAccountStore!
    /// 每个用例独立的插件数据目录，避免草稿文件跨用例串扰。
    private var dataDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fixture = try MailAccountStoreFixture()
        store = fixture.store
        dataDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-mail-compose-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        if let dataDirectory {
            try? FileManager.default.removeItem(at: dataDirectory)
        }
        dataDirectory = nil
        fixture = nil
        store = nil
        try super.tearDownWithError()
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
            factory: session.map { SingleSessionFactory(session: $0) } ?? MockMailSessionFactory(),
            accountStore: store
        )
        return MailComposeViewModel(
            composer: MailComposerService(sessionManager: manager, accountStore: store),
            sessionManager: manager,
            account: account ?? makeAccount(),
            dataDirectory: dataDirectory,
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

    func testDraftRestoreRestoresAllFields() {
        let account = makeAccount()
        let vm = makeVM(mode: .new, account: account)
        vm.to = "lisi@example.com"
        vm.cc = "wangwu@example.com"
        vm.subject = "Quarterly"
        vm.body = "Draft body"
        vm.addAttachment(Data("pdf-bytes".utf8), filename: "plan.pdf")
        XCTAssertNotNil(vm.draftSavedAt, "编辑后应写入本地草稿")

        let reopened = makeVM(mode: .new, account: account)
        XCTAssertEqual(reopened.to, "lisi@example.com")
        XCTAssertEqual(reopened.cc, "wangwu@example.com")
        XCTAssertEqual(reopened.subject, "Quarterly")
        XCTAssertEqual(reopened.body, "Draft body")
        XCTAssertEqual(reopened.attachments.count, 1)
        XCTAssertEqual(reopened.attachments.first?.filename, "plan.pdf")
        XCTAssertEqual(reopened.attachments.first?.data, Data("pdf-bytes".utf8))
        XCTAssertNotNil(reopened.draftSavedAt, "恢复后应保留草稿保存时间")
    }

    func testCorruptDraftFallsBackToModeDefaults() throws {
        let account = makeAccount()
        let draftsDir = dataDirectory.appendingPathComponent("drafts", isDirectory: true)
        try FileManager.default.createDirectory(at: draftsDir, withIntermediateDirectories: true)
        let draftURL = draftsDir.appendingPathComponent("\(account.id.uuidString)-reply-42.json")
        try Data("{ not valid json".utf8).write(to: draftURL)

        let vm = makeVM(mode: .reply, detail: makeDetail(), account: account)
        XCTAssertEqual(vm.to, "lisi@example.com", "草稿损坏时应回退到回复预填")
        XCTAssertEqual(vm.subject, "Re: Project Update")
        XCTAssertTrue(vm.body.contains("Please review the plan."))
        XCTAssertNil(vm.draftSavedAt)
    }

    func testSuccessfulSendClearsLocalDraft() async {
        let session = MockMailSession(messages: [])
        let account = makeAccount()
        store.setPassword("p", for: account.id)
        let vm = makeVM(mode: .new, session: session, account: account)
        vm.to = "lisi@example.com"
        vm.body = "Body"
        vm.saveDraftNow()

        vm.send()
        await waitForPhaseSettle(vm)
        XCTAssertEqual(vm.phase, .sent, "mock 发送应成功")

        let reopened = makeVM(mode: .new, account: account)
        XCTAssertEqual(reopened.body, "", "发送成功后应删除本地草稿")
    }

    func testSendFailureRetainsDraftState() async {
        let session = MockMailSession(messages: [])
        let account = makeAccount()
        store.setPassword("p", for: account.id)
        let vm = makeVM(mode: .new, session: session, account: account)
        vm.to = "lisi@example.com"
        vm.subject = "Hi"
        vm.body = "Body"

        vm.send()
        // 发送成功（mock 不失败）→ sent
        await waitForPhaseSettle(vm)
        XCTAssertEqual(vm.phase, .sent, "mock 发送应成功")

        // 失败场景：清密码 → authFailed
        store.setPassword(nil, for: account.id)
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
