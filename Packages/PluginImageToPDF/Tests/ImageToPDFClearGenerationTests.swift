import Foundation
import Testing
@testable import ImageToPDFPlugin

/// 确定性替身：持有每次 convert 的流 continuation，由测试显式 emit/finish/fail，
/// 用来构造「转换中 → Clear → 旧任务迟到写回」的时序（#380）。
/// 全部访问都发生在主 actor（测试体与 ViewModel 的 Task），故标记 @unchecked Sendable。
final class StubImageToPDFConverter: ImageToPDFConverting, @unchecked Sendable {
    final class Call {
        let outputURL: URL
        var continuation: AsyncThrowingStream<Double, Error>.Continuation?
        init(outputURL: URL) { self.outputURL = outputURL }
        func emit(_ value: Double) { continuation?.yield(value) }
        func finish(writeFile: Bool = false) {
            if writeFile { try? Data("pdf".utf8).write(to: outputURL) }
            continuation?.finish()
        }
        func fail(_ error: Error) { continuation?.finish(throwing: error) }
    }

    private(set) var calls: [Call] = []

    func convert(source: ImageItem, to outputURL: URL) -> AsyncThrowingStream<Double, Error> {
        let call = Call(outputURL: outputURL)
        calls.append(call)
        return AsyncThrowingStream { continuation in
            call.continuation = continuation
        }
    }
}

@Suite("ImageToPDF Clear 的回合身份隔离")
@MainActor
struct ImageToPDFClearGenerationTests {
    /// 让出主 actor，排空 convertAll 派生的 Task 与回调。
    private func settle(_ iterations: Int = 24) async {
        for _ in 0..<iterations { await Task.yield() }
    }

    /// 轮询直到条件成立（并行套件占用主 actor 时，固定 yield 次数不足以排空 Task）。
    private func waitUntil(
        timeout: Duration = .seconds(3),
        _ condition: @MainActor () -> Bool
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while !condition() {
            if clock.now > deadline {
                Issue.record("waitUntil 超时")
                return
            }
            await Task.yield()
        }
    }

    private func makeStaging() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        ImageToPDFRuntimeBridge.directoryURL = url
        return url
    }

    @Test("转换中 Clear 后旧任务的迟到进度/完成不得重新填回列表")
    func clearDuringConversionRejectsLateProgressAndCompletion() async throws {
        let staging = makeStaging()
        defer {
            ImageToPDFRuntimeBridge.directoryURL = nil
            try? FileManager.default.removeItem(at: staging)
        }
        let stub = StubImageToPDFConverter()
        let model = ImageToPDFViewModel(service: stub)
        model.addImages(from: [URL(fileURLWithPath: "/tmp/a.png")])
        model.convertAll()
        await waitUntil { !stub.calls.isEmpty }
        #expect(model.isConverting)
        #expect(model.outputItems.count == 1)
        let call = try #require(stub.calls.first)

        model.clearAll()
        #expect(model.inputImages.isEmpty)
        #expect(model.outputItems.isEmpty)
        #expect(model.isConverting == false)

        // 旧回合迟到：先 emit 进度再 finish（无文件 → 本应判 failed）。
        call.emit(0.8)
        call.finish()
        await settle()

        #expect(model.inputImages.isEmpty)
        #expect(model.outputItems.isEmpty, "旧任务不得把已清空的输出整批填回")
        #expect(model.isConverting == false)
        #expect(model.lastErrorMessage == nil)
    }

    @Test("Clear 后新转换不得被旧回合的迟到完成复位 isConverting")
    func clearThenNewConversionIsNotResetByOldCompletion() async throws {
        let staging = makeStaging()
        defer {
            ImageToPDFRuntimeBridge.directoryURL = nil
            try? FileManager.default.removeItem(at: staging)
        }
        let stub = StubImageToPDFConverter()
        let model = ImageToPDFViewModel(service: stub)
        let urlA = URL(fileURLWithPath: "/tmp/a.png")
        let urlB = URL(fileURLWithPath: "/tmp/b.png")

        model.addImages(from: [urlA])
        model.convertAll()
        await waitUntil { !stub.calls.isEmpty }
        let oldCall = try #require(stub.calls.first)

        model.clearAll()
        model.addImages(from: [urlB])
        model.convertAll()
        await waitUntil { stub.calls.count == 2 }
        #expect(stub.calls.count == 2)
        #expect(model.isConverting)
        #expect(model.outputItems.count == 1)
        let newCall = stub.calls[1]

        // 旧回合迟到完成（写出文件 → 本应判 done）。
        oldCall.emit(0.9)
        oldCall.finish(writeFile: true)
        await settle()
        #expect(model.isConverting, "旧回合完成不得复位新回合的 isConverting")
        #expect(model.outputItems.count == 1)
        #expect(model.outputItems.first?.source.url == urlB)

        // 新回合正常完成。
        newCall.finish(writeFile: true)
        await waitUntil { !model.isConverting }
        #expect(model.isConverting == false)
        #expect(model.outputItems.first?.status.outputURL != nil)
    }

    @Test("未被作废的转换正常上报进度并完成")
    func activeConversionAppliesProgressAndCompletion() async throws {
        let staging = makeStaging()
        defer {
            ImageToPDFRuntimeBridge.directoryURL = nil
            try? FileManager.default.removeItem(at: staging)
        }
        let stub = StubImageToPDFConverter()
        let model = ImageToPDFViewModel(service: stub)
        model.addImages(from: [URL(fileURLWithPath: "/tmp/a.png")])
        model.convertAll()
        await waitUntil { !stub.calls.isEmpty }
        let call = try #require(stub.calls.first)

        call.emit(0.5)
        await settle()
        #expect(model.outputItems.first?.progress == 0.5)
        #expect(model.isConverting)

        call.finish(writeFile: true)
        await waitUntil { !model.isConverting }
        #expect(model.isConverting == false)
        #expect(model.outputItems.first?.progress == 1.0)
        #expect(model.outputItems.first?.status.outputURL != nil)
    }

    @Test("转换中 Clear 后旧任务的迟到失败不得污染状态")
    func lateErrorFromClearedConversionDoesNotPollute() async throws {
        let staging = makeStaging()
        defer {
            ImageToPDFRuntimeBridge.directoryURL = nil
            try? FileManager.default.removeItem(at: staging)
        }
        let stub = StubImageToPDFConverter()
        let model = ImageToPDFViewModel(service: stub)
        let urlA = URL(fileURLWithPath: "/tmp/a.png")
        model.addImages(from: [urlA])
        model.convertAll()
        await waitUntil { !stub.calls.isEmpty }
        let call = try #require(stub.calls.first)

        model.clearAll()
        call.fail(ImageToPDFService.ConversionError.writeFailed(urlA))
        await settle()

        #expect(model.outputItems.isEmpty)
        #expect(model.lastErrorMessage == nil)
        #expect(model.isConverting == false)
    }

    @Test("空闲时 Clear 只清空输入，不触发转换")
    func clearWhenIdleClearsInputsWithoutConversion() {
        let stub = StubImageToPDFConverter()
        let model = ImageToPDFViewModel(service: stub)
        model.addImages(from: [URL(fileURLWithPath: "/tmp/a.png")])
        #expect(model.canClear)

        model.clearAll()
        #expect(model.inputImages.isEmpty)
        #expect(model.canClear == false)
        #expect(stub.calls.isEmpty)
        #expect(model.isConverting == false)
    }
}