import Foundation
import ProviderMessage
import Testing
@testable import PluginConversationInput

/// 同一批拖入的多个附件必须按**原始拖放顺序**入池，而不是按读取完成顺序（#804）。
///
/// 两条拖放链（输入框 AppKit / 预览区 SwiftUI）都先拿到有序 URL 数组，再整批
/// 交给 `attach(droppedURLs:)`。读取可以并发，但结果按批次索引收集后再入池。
///
/// 这些用例用可注入的 `batchAttachmentReader` + 门闩确定性构造「后拖入的先读完」，
/// 因此乱序是必现的，而非依赖真实 I/O 时序的偶发。套件 `.serialized`，避免并发
/// 用例互相覆盖注入的读取器。
@MainActor
@Suite("ConversationInput 批次拖放顺序", .serialized)
struct ConversationInputDropOrderTests {
    // MARK: - 文件 / 图片按原始顺序入池

    @Test("同一批文件按原始拖放顺序入池，而非读取完成顺序（#804）")
    func batchFileDropsKeepOriginalOrderDespiteOutOfOrderReads() async throws {
        let aURL = URL(fileURLWithPath: "/tmp/drop-order-A-\(UUID().uuidString).txt")
        let bURL = URL(fileURLWithPath: "/tmp/drop-order-B-\(UUID().uuidString).txt")
        let aRelease = AsyncLatch()
        let bDone = AsyncLatch()
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)

        try await withBatchReader({ url in
            if url == aURL {
                // A 挂在门闩上，确保后拖入的 B 先读完。
                await aRelease.wait()
                return .file(UserFileAttachment(fileName: "A.txt", mimeType: "text/plain", textContent: "A"))
            }
            await bDone.release()
            return .file(UserFileAttachment(fileName: "B.txt", mimeType: "text/plain", textContent: "B"))
        }, body: {
            viewModel.attach(droppedURLs: [aURL, bURL])
            // 等 B 先完成：整批读取已同步登记，窗口内发送会等全部结束（#1023）。
            await bDone.wait()
            #expect(capability.pendingAttachmentReadCount == 2)
            // 再放行 A，确定性构造「B 先于 A 完成」。
            await aRelease.release()
            _ = await capability.waitForAttachmentReads()
        })

        #expect(capability.pendingFileAttachments.map(\.fileName) == ["A.txt", "B.txt"])
        #expect(capability.isInputFocused)
    }

    @Test("同一批图片按原始拖放顺序入池，而非读取完成顺序（#804）")
    func batchImageDropsKeepOriginalOrderDespiteOutOfOrderReads() async throws {
        let aURL = URL(fileURLWithPath: "/tmp/drop-order-A-\(UUID().uuidString).png")
        let bURL = URL(fileURLWithPath: "/tmp/drop-order-B-\(UUID().uuidString).png")
        let aRelease = AsyncLatch()
        let bDone = AsyncLatch()
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)

        try await withBatchReader({ url in
            if url == aURL {
                await aRelease.wait()
                return .image(UserImageAttachment(mimeType: "image/png", base64Data: "AAAA", fileName: "A.png"))
            }
            await bDone.release()
            return .image(UserImageAttachment(mimeType: "image/png", base64Data: "BBBB", fileName: "B.png"))
        }, body: {
            viewModel.attach(droppedURLs: [aURL, bURL])
            await bDone.wait()
            await aRelease.release()
            _ = await capability.waitForAttachmentReads()
        })

        #expect(capability.pendingImageAttachments.map(\.fileName) == ["A.png", "B.png"])
        #expect(capability.isInputFocused)
    }

    @Test("图片与文件混拖时，各自池内仍保持原始相对顺序（#804）")
    func batchMixedDropsKeepPerPoolOrder() async throws {
        let aURL = URL(fileURLWithPath: "/tmp/drop-mix-A-\(UUID().uuidString).txt")
        let bURL = URL(fileURLWithPath: "/tmp/drop-mix-B-\(UUID().uuidString).png")
        let cURL = URL(fileURLWithPath: "/tmp/drop-mix-C-\(UUID().uuidString).txt")
        let aRelease = AsyncLatch()
        let bDone = AsyncLatch()
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)

        // 批次顺序 [文件A, 图片B, 文件C]；A 最后完成，B/C 先完成。
        try await withBatchReader({ url in
            if url == aURL {
                await aRelease.wait()
                return .file(UserFileAttachment(fileName: "A.txt", mimeType: "text/plain", textContent: "A"))
            }
            if url == bURL {
                await bDone.release()
                return .image(UserImageAttachment(mimeType: "image/png", base64Data: "BBBB", fileName: "B.png"))
            }
            return .file(UserFileAttachment(fileName: "C.txt", mimeType: "text/plain", textContent: "C"))
        }, body: {
            viewModel.attach(droppedURLs: [aURL, bURL, cURL])
            await bDone.wait()
            await aRelease.release()
            _ = await capability.waitForAttachmentReads()
        })

        // 文件池保留 A→C 的相对顺序，图片池只有 B。
        #expect(capability.pendingFileAttachments.map(\.fileName) == ["A.txt", "C.txt"])
        #expect(capability.pendingImageAttachments.map(\.fileName) == ["B.png"])
    }

    // MARK: - 批次读取与会话绑定（#780）

    @Test("批次读取期间切换会话，整批旧附件不落入新会话（#780）")
    func staleBatchDropDoesNotLeakIntoNewConversation() async throws {
        let a = UUID()
        let b = UUID()
        let capability = SendActionBarTestCapability()
        capability.selectedConversationID = a
        let viewModel = ConversationInputViewModel(capability: capability)
        let url1 = URL(fileURLWithPath: "/tmp/drop-stale-1-\(UUID().uuidString).txt")
        let url2 = URL(fileURLWithPath: "/tmp/drop-stale-2-\(UUID().uuidString).txt")

        try await withBatchReader({ url in
            .file(UserFileAttachment(fileName: url.lastPathComponent, mimeType: "text/plain", textContent: "x"))
        }, body: {
            viewModel.attach(droppedURLs: [url1, url2])
            // 读取任务尚未运行（MainActor 让出前 Task body 不执行），同步切到 B。
            capability.selectedConversationID = b
            _ = await capability.waitForAttachmentReads()
        })

        #expect(capability.pendingFileAttachments.isEmpty)
        #expect(viewModel.fileAttachments.isEmpty)
        #expect(capability.errorMessage == nil)
        #expect(!capability.isInputFocused)
    }

    // MARK: - 批次内的单项失败

    @Test("批次中一个文件读取失败：报错但其余成功附件仍按序入池（#804）")
    func batchFileReadFailureSurfacesErrorAndKeepsSuccessfulOrder() async throws {
        let aURL = URL(fileURLWithPath: "/tmp/drop-fail-A-\(UUID().uuidString).txt")
        let bURL = URL(fileURLWithPath: "/tmp/drop-fail-B-\(UUID().uuidString).txt")
        let cURL = URL(fileURLWithPath: "/tmp/drop-fail-C-\(UUID().uuidString).txt")
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)

        try await withBatchReader({ url in
            if url == aURL { return .fileError(message: "boom A") }
            if url == bURL {
                return .file(UserFileAttachment(fileName: "B.txt", mimeType: "text/plain", textContent: "B"))
            }
            return .file(UserFileAttachment(fileName: "C.txt", mimeType: "text/plain", textContent: "C"))
        }, body: {
            viewModel.attach(droppedURLs: [aURL, bURL, cURL])
            _ = await capability.waitForAttachmentReads()
        })

        // A 失败被跳过，B、C 仍按原始顺序入池；错误提示可见。
        #expect(capability.pendingFileAttachments.map(\.fileName) == ["B.txt", "C.txt"])
        #expect(viewModel.errorMessage == "boom A")
    }

    // MARK: - 目录文本按序排队

    @Test("批次中的目录按原始顺序排队插入文本，附件按序入池（#804）")
    func batchDirectoriesKeepInsertOrder() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("drop-order-dir-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let dirA = root.appendingPathComponent("A")
        let dirC = root.appendingPathComponent("C")
        try FileManager.default.createDirectory(at: dirA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dirC, withIntermediateDirectories: true)
        let fileB = URL(fileURLWithPath: "/tmp/drop-dir-B-\(UUID().uuidString).txt")

        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)

        try await withBatchReader({ _ in
            .file(UserFileAttachment(fileName: "B.txt", mimeType: "text/plain", textContent: "B"))
        }, body: {
            viewModel.attach(droppedURLs: [dirA, fileB, dirC])
            _ = await capability.waitForAttachmentReads()
        })

        // 目录文本块按 A→C 顺序排队（同步插入），文件池只有 B。
        let first = try #require(viewModel.pendingBlock)
        #expect(first.text == dirA.path)
        viewModel.consumePendingBlock(id: first.id)
        let second = try #require(viewModel.pendingBlock)
        #expect(second.text == dirC.path)
        #expect(capability.pendingFileAttachments.map(\.fileName) == ["B.txt"])
    }

    // MARK: - Helpers

    /// 注入批次读取器，跑完 body 后恢复原读取器（defer 保证异常路径也恢复）。
    private func withBatchReader(
        _ reader: @escaping @Sendable (URL) async -> ConversationInputViewModel.AttachmentReadOutcome,
        body: () async throws -> Void
    ) async throws {
        let original = ConversationInputViewModel.batchAttachmentReader
        ConversationInputViewModel.batchAttachmentReader = reader
        defer { ConversationInputViewModel.batchAttachmentReader = original }
        try await body()
    }
}

/// 一次性门闩：等待方挂起，直到放行方 resume；放行先于等待时立即返回。
///
/// 用 actor 串行化「释放/等待」状态，避免续体被重复 resume 或丢失。
private actor AsyncLatch {
    private var continuation: CheckedContinuation<Void, Never>?
    private var released = false

    func wait() async {
        if released { return }
        await withCheckedContinuation { continuation = $0 }
    }

    func release() {
        guard !released else { return }
        released = true
        continuation?.resume()
        continuation = nil
    }
}