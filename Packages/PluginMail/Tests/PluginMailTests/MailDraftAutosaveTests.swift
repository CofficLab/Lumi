import XCTest
import KitMail
@testable import PluginMail

/// 撰写草稿自动保存（见 issue #1188）。
///
/// 修复前每次击键都在主线程同步 Base64/JSON 编码全部附件并整份重写；
/// 修复后合并连续编辑、编码与写入移出主 actor，附件单独落盘且只在增删时重写。
@MainActor
final class MailDraftAutosaveTests: XCTestCase {
    // XCTest 的 setUp/tearDown 是 nonisolated，用例本身在主 actor 上串行执行。
    nonisolated(unsafe) private var fixture: MailAccountStoreFixture!
    nonisolated(unsafe) private var store: MailAccountStore!
    nonisolated(unsafe) private var dataDirectory: URL!
    nonisolated(unsafe) private var account: MailAccountConfig!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fixture = try MailAccountStoreFixture()
        store = fixture.store
        dataDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-mail-draft-\(UUID().uuidString)", isDirectory: true)
        account = MailAccountConfig(
            id: UUID(),
            displayName: "张三",
            email: "zhangsan@example.com",
            imapHost: "imap.example.com",
            smtpHost: "smtp.example.com",
            username: "zhangsan"
        )
        store.upsertAccount(account)
    }

    override func tearDownWithError() throws {
        if let dataDirectory {
            try? FileManager.default.removeItem(at: dataDirectory)
        }
        dataDirectory = nil
        account = nil
        fixture = nil
        store = nil
        try super.tearDownWithError()
    }

    private var textURL: URL {
        dataDirectory.appendingPathComponent("drafts/\(account.id.uuidString)-new-0.json")
    }

    private var attachmentsURL: URL {
        dataDirectory.appendingPathComponent("drafts/\(account.id.uuidString)-new-0.attachments.json")
    }

    private func makeVM(
        draftStore: (any MailDraftSaving)? = nil,
        draftSaveDelay: Duration = .milliseconds(400),
        session: MockMailSession? = nil
    ) -> MailComposeViewModel {
        let manager = MailSessionManager(
            factory: MockMailSessionFactory(session: session),
            accountStore: store
        )
        return MailComposeViewModel(
            composer: MailComposerService(sessionManager: manager, accountStore: store),
            sessionManager: manager,
            account: account,
            dataDirectory: dataDirectory,
            mode: .new,
            draftStore: draftStore,
            draftSaveDelay: draftSaveDelay
        )
    }

    private func readTextBody() throws -> String {
        let data = try Data(contentsOf: textURL)
        let payload = try JSONDecoder().decode(MailDraftPayload.self, from: data)
        return payload.body
    }

    // MARK: - 主线程占用

    func testSaveEncodesAndWritesOffMainThread() async throws {
        let recorder = ThreadRecordingDraftStore()
        let vm = makeVM(draftStore: recorder)
        vm.body = "Hello"
        vm.addAttachment(Data(repeating: 0x41, count: 4096), filename: "big.bin")

        await vm.saveDraftNow()

        let sawMainThread = await recorder.sawMainThread
        XCTAssertEqual(sawMainThread, false, "编码与文件写入不应在主线程执行")
        XCTAssertTrue(FileManager.default.fileExists(atPath: textURL.path))
        XCTAssertNotNil(vm.draftSavedAt)
    }

    // MARK: - 附件不再随文本编辑重写

    func testTextOnlyEditDoesNotRewriteAttachments() async throws {
        let vm = makeVM()
        vm.addAttachment(Data("pdf-bytes".utf8), filename: "plan.pdf")
        await vm.saveDraftNow()
        XCTAssertTrue(FileManager.default.fileExists(atPath: attachmentsURL.path))

        // 删掉附件文件后做纯文本编辑：不应被重新写出。
        try FileManager.default.removeItem(at: attachmentsURL)
        vm.body = "Edited body"
        await vm.saveDraftNow()

        XCTAssertFalse(
            FileManager.default.fileExists(atPath: attachmentsURL.path),
            "纯文本编辑不应重新编码/写入附件"
        )
        XCTAssertEqual(try readTextBody(), "Edited body")
        let text = try String(contentsOf: textURL, encoding: .utf8)
        XCTAssertFalse(text.contains("pdf-bytes"), "草稿文本里不应内嵌附件字节")
        XCTAssertFalse(text.contains(Data("pdf-bytes".utf8).base64EncodedString()))
    }

    func testAttachmentChangesRewriteAttachmentFile() async throws {
        let vm = makeVM()
        vm.addAttachment(Data("pdf-bytes".utf8), filename: "plan.pdf")
        await vm.saveDraftNow()

        var stored = try JSONDecoder().decode(
            [MailDraftAttachment].self,
            from: Data(contentsOf: attachmentsURL)
        )
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.data, Data("pdf-bytes".utf8))

        vm.removeAttachment(at: 0)
        await vm.saveDraftNow()

        stored = try JSONDecoder().decode(
            [MailDraftAttachment].self,
            from: Data(contentsOf: attachmentsURL)
        )
        XCTAssertTrue(stored.isEmpty, "删除附件后应重写附件文件")
    }

    func testRestoredDraftSkipsAttachmentRewriteOnFirstTextEdit() async throws {
        let first = makeVM()
        first.addAttachment(Data("pdf-bytes".utf8), filename: "plan.pdf")
        await first.saveDraftNow()

        let reopened = makeVM()
        XCTAssertEqual(reopened.attachments.count, 1)
        try FileManager.default.removeItem(at: attachmentsURL)

        reopened.body = "More text"
        await reopened.saveDraftNow()

        XCTAssertFalse(
            FileManager.default.fileExists(atPath: attachmentsURL.path),
            "恢复后首次纯文本编辑不应重写附件"
        )
        XCTAssertEqual(try readTextBody(), "More text")
    }

    func testLegacyDraftWithEmbeddedAttachmentsStillRestores() throws {
        let directory = dataDirectory.appendingPathComponent("drafts", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let legacy: [String: Any] = [
            "mode": "new",
            "to": "lisi@example.com",
            "cc": "",
            "subject": "Old draft",
            "body": "Legacy body",
            "attachments": [
                [
                    "filename": "plan.pdf",
                    "mimeType": "application/pdf",
                    "data": Data("pdf-bytes".utf8).base64EncodedString()
                ]
            ]
        ]
        try JSONSerialization.data(withJSONObject: legacy).write(to: textURL)

        let vm = makeVM()
        XCTAssertEqual(vm.body, "Legacy body")
        XCTAssertEqual(vm.attachments.count, 1)
        XCTAssertEqual(vm.attachments.first?.data, Data("pdf-bytes".utf8))
    }

    func testLegacyDraftMigratesAttachmentsOnFirstSave() async throws {
        let directory = dataDirectory.appendingPathComponent("drafts", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let legacy: [String: Any] = [
            "mode": "new",
            "to": "lisi@example.com",
            "cc": "",
            "subject": "Old draft",
            "body": "Legacy body",
            "attachments": [
                [
                    "filename": "plan.pdf",
                    "mimeType": "application/pdf",
                    "data": Data("pdf-bytes".utf8).base64EncodedString()
                ]
            ]
        ]
        try JSONSerialization.data(withJSONObject: legacy).write(to: textURL)

        let vm = makeVM()
        vm.body = "Edited legacy body"
        await vm.saveDraftNow()

        let reopened = makeVM()
        XCTAssertEqual(reopened.body, "Edited legacy body")
        XCTAssertEqual(reopened.attachments.count, 1, "旧草稿的附件应迁移到独立文件而不是丢失")
        XCTAssertEqual(reopened.attachments.first?.data, Data("pdf-bytes".utf8))
    }

    // MARK: - 合并连续编辑

    func testContinuousEditsCoalesceIntoOneWrite() async throws {
        let counter = CountingDraftStore()
        let vm = makeVM(draftStore: counter, draftSaveDelay: .milliseconds(60))

        for index in 0..<8 {
            vm.body = "Typing \(index)"
            vm.scheduleDraftSave()
        }
        try await Task.sleep(for: .milliseconds(400))

        let count = await counter.saveCount
        XCTAssertEqual(count, 1, "连续击键应合并成一次落盘")
        XCTAssertEqual(try readTextBody(), "Typing 7")
    }

    // MARK: - 后写覆盖先写

    func testStaleSaveDoesNotOverwriteNewerDraft() async throws {
        let gated = GatedDraftStore()
        let vm = makeVM(draftStore: gated)

        vm.body = "Old body"
        let stale = Task { await vm.saveDraftNow() }
        await gated.waitUntilArmed()

        vm.body = "New body"
        await vm.saveDraftNow()
        XCTAssertEqual(try readTextBody(), "New body")

        await gated.release()
        await stale.value

        XCTAssertEqual(try readTextBody(), "New body", "晚到的旧快照不应覆盖新草稿")
    }

    func testSendSuccessRemovesTextAndAttachmentFiles() async throws {
        let session = MockMailSession(messages: [])
        store.setPassword("p", for: account.id)
        let vm = makeVM(session: session)
        vm.to = "lisi@example.com"
        vm.body = "Body"
        vm.addAttachment(Data("pdf-bytes".utf8), filename: "plan.pdf")
        await vm.saveDraftNow()
        XCTAssertTrue(FileManager.default.fileExists(atPath: attachmentsURL.path))

        vm.send()
        for _ in 0..<100 {
            if vm.phase != .sending { break }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(vm.phase, .sent)

        XCTAssertFalse(FileManager.default.fileExists(atPath: textURL.path))
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: attachmentsURL.path),
            "发送成功后附件草稿也应删除"
        )
    }
}

// MARK: - 测试替身

/// 记录落盘时所在线程，并执行真实的编码/写入实现。
private actor ThreadRecordingDraftStore: MailDraftSaving {
    private(set) var sawMainThread: Bool?

    func save(_ snapshot: MailDraftSnapshot, generation: Int) throws -> Bool {
        sawMainThread = Thread.isMainThread
        try MailDraftStore.write(snapshot, previousAttachmentsRevision: nil)
        return true
    }

    func discard(textURL: URL, attachmentsURL: URL, generation: Int) {
        try? FileManager.default.removeItem(at: textURL)
        try? FileManager.default.removeItem(at: attachmentsURL)
    }
}

/// 只计数，用于验证防抖合并。
private actor CountingDraftStore: MailDraftSaving {
    private(set) var saveCount = 0

    func save(_ snapshot: MailDraftSnapshot, generation: Int) throws -> Bool {
        saveCount += 1
        try MailDraftStore.write(snapshot, previousAttachmentsRevision: nil)
        return true
    }

    func discard(textURL: URL, attachmentsURL: URL, generation: Int) {
        try? FileManager.default.removeItem(at: textURL)
        try? FileManager.default.removeItem(at: attachmentsURL)
    }
}

/// 卡住第一份快照，构造「旧请求晚到」。
private actor GatedDraftStore: MailDraftSaving {
    private let inner = MailDraftStore()
    private var gate: CheckedContinuation<Void, Never>?
    private var blockNextSave = true

    func save(_ snapshot: MailDraftSnapshot, generation: Int) async throws -> Bool {
        if blockNextSave {
            blockNextSave = false
            await withCheckedContinuation { continuation in
                gate = continuation
            }
        }
        return try await inner.save(snapshot, generation: generation)
    }

    func discard(textURL: URL, attachmentsURL: URL, generation: Int) async {
        await inner.discard(textURL: textURL, attachmentsURL: attachmentsURL, generation: generation)
    }

    func waitUntilArmed() async {
        while gate == nil {
            await Task.yield()
        }
    }

    func release() {
        gate?.resume()
        gate = nil
    }
}
