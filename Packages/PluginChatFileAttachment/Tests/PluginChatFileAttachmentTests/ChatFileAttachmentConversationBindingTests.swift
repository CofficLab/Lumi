import Foundation
import ProviderMessage
import Testing
@testable import PluginChatFileAttachment

/// 文件选择器的读取写回必须绑定选择时的会话（#161）：
/// 挂起池是发送器级全局数组，读取期间切换会话后，旧结果与旧错误都不能落入新会话。
@Suite("文件选择附件读取的会话绑定", .serialized)
@MainActor
struct ChatFileAttachmentConversationBindingTests {
    @Test("读取期间切换会话，旧文件附件不落入新会话挂起池（#161）")
    func staleFileSelectionDoesNotLeakIntoNewConversation() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("chat-file-attachment-stale-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("notes.txt")
        #expect(FileManager.default.createFile(atPath: fileURL.path, contents: Data("hello".utf8)))

        let a = UUID()
        let b = UUID()
        let capability = AttachmentButtonTestCapability()
        capability.selectedConversationID = a
        let button = ChatFileAttachmentButton(capability: capability)

        // 在 A 选择文件：同步捕获 A 并登记读取，随后挂起在后台读取上。
        button.handle(.success([fileURL]))
        // 读取任务尚未运行（MainActor 让出前 Task body 不会执行），同步切到 B。
        capability.selectedConversationID = b

        #expect(await capability.waitForAttachmentReads())

        #expect(capability.pendingFileAttachments.isEmpty)
        #expect(capability.errorMessage == nil)
        #expect(capability.readFailureCount == 0)
    }

    @Test("读取期间切换会话，整批旧文件附件都不落入新会话挂起池（#161）")
    func staleBatchSelectionDoesNotLeakIntoNewConversation() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("chat-file-attachment-stale-batch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = directory.appendingPathComponent("first.txt")
        let second = directory.appendingPathComponent("second.txt")
        #expect(FileManager.default.createFile(atPath: first.path, contents: Data("one".utf8)))
        #expect(FileManager.default.createFile(atPath: second.path, contents: Data("two".utf8)))

        let a = UUID()
        let b = UUID()
        let capability = AttachmentButtonTestCapability()
        capability.selectedConversationID = a
        let button = ChatFileAttachmentButton(capability: capability)

        button.handle(.success([first, second]))
        capability.selectedConversationID = b

        #expect(await capability.waitForAttachmentReads())

        #expect(capability.pendingFileAttachments.isEmpty)
        #expect(capability.errorMessage == nil)
    }

    @Test("读取期间切换会话，旧文件读取失败不报错到新会话（#161）")
    func staleFileSelectionErrorDoesNotLeakIntoNewConversation() async throws {
        let a = UUID()
        let b = UUID()
        let capability = AttachmentButtonTestCapability()
        capability.selectedConversationID = a
        let button = ChatFileAttachmentButton(capability: capability)

        // 指向不存在的路径，读取必定抛错；错误分支同样要校验会话身份。
        button.handle(.success([
            URL(fileURLWithPath: "/tmp/definitely-missing-\(UUID().uuidString).txt"),
        ]))
        capability.selectedConversationID = b

        #expect(await capability.waitForAttachmentReads())

        #expect(capability.errorMessage == nil)
        #expect(capability.readFailureCount == 0)
        #expect(capability.pendingFileAttachments.isEmpty)
    }

    @Test("未切换会话时，选择的文件正常进入挂起池")
    func fileSelectionInSameConversationAttaches() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("chat-file-attachment-same-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("notes.txt")
        #expect(FileManager.default.createFile(atPath: fileURL.path, contents: Data("hello".utf8)))

        let a = UUID()
        let capability = AttachmentButtonTestCapability()
        capability.selectedConversationID = a
        let button = ChatFileAttachmentButton(capability: capability)

        button.handle(.success([fileURL]))

        #expect(await capability.waitForAttachmentReads())

        let attachment = try #require(capability.pendingFileAttachments.first)
        #expect(attachment.fileName == "notes.txt")
        #expect(attachment.textContent == "hello")
        #expect(capability.errorMessage == nil)
    }
}

@MainActor
private final class AttachmentButtonTestCapability: ChatFileAttachmentCapability {
    var selectedConversationID: UUID?
    var pendingFileAttachments: [UserFileAttachment] = []
    var errorMessage: String?
    var readFailureCount = 0

    private var pendingAttachmentReadCount = 0
    private var attachmentReadWaiters: [CheckedContinuation<Bool, Never>] = []

    func addFileAttachment(_ attachment: UserFileAttachment) {
        pendingFileAttachments.append(attachment)
    }

    func presentLoadError(_ message: String) {
        errorMessage = message
    }

    func beginAttachmentRead() {
        pendingAttachmentReadCount += 1
    }

    func endAttachmentRead() {
        pendingAttachmentReadCount -= 1
        guard pendingAttachmentReadCount == 0 else { return }
        let waiters = attachmentReadWaiters
        attachmentReadWaiters.removeAll()
        for waiter in waiters { waiter.resume(returning: true) }
    }

    func recordAttachmentReadFailure() {
        readFailureCount += 1
    }

    func waitForAttachmentReads() async -> Bool {
        guard pendingAttachmentReadCount > 0 else { return true }
        return await withCheckedContinuation { attachmentReadWaiters.append($0) }
    }
}