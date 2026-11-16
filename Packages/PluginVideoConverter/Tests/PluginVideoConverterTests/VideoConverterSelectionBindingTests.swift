import Foundation
import Testing
@testable import PluginVideoConverter

// MARK: - 替身

/// 可控的视频转换替身：每次 `convert` 记录一份独立的回调与续体，测试据此
/// 精确驱动「旧任务迟到进度/日志/完成/失败」与「新任务正常推进」的时序（#263）。
/// `cancel` 只记录调用，不自动结束转换——旧任务是否仍在后台跑由测试显式控制。
@MainActor
final class StubVideoConverter: VideoConverting {

    @MainActor
    final class Call {
        let onProgress: @Sendable (Double) -> Void
        let onLog: @Sendable (String) -> Void
        var continuation: CheckedContinuation<Void, Error>?

        init(
            onProgress: @escaping @Sendable (Double) -> Void,
            onLog: @escaping @Sendable (String) -> Void
        ) {
            self.onProgress = onProgress
            self.onLog = onLog
        }

        func emitProgress(_ percent: Double) { onProgress(percent) }
        func emitLog(_ line: String) { onLog(line) }
        func finish() {
            continuation?.resume()
            continuation = nil
        }
        func fail(_ error: any Error) {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }

    private(set) var calls: [Call] = []
    private(set) var cancelCallCount = 0

    func convert(
        input: URL,
        output: URL,
        format: VideoFormat,
        onProgress: @escaping @Sendable (Double) -> Void,
        onLog: @escaping @Sendable (String) -> Void
    ) async throws {
        let call = Call(onProgress: onProgress, onLog: onLog)
        calls.append(call)
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            call.continuation = c
        }
    }

    func cancel() async {
        cancelCallCount += 1
    }
}

// MARK: - 调度辅助

@MainActor
private func waitUntil(
    timeout: Duration = .seconds(5),
    _ condition: @MainActor () -> Bool
) async {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while !condition() {
        if clock.now >= deadline {
            Issue.record("等待条件超时")
            return
        }
        await Task.yield()
    }
}

/// 让出主 actor 若干次，排空被测代码 spawn 的 MainActor 回调任务。
@MainActor
private func settle(_ iterations: Int = 24) async {
    for _ in 0..<iterations { await Task.yield() }
}

private func makeItem(_ path: String) -> VideoFileItem {
    VideoFileItem(url: URL(fileURLWithPath: path), fileSize: 10)
}

// MARK: - 测试

/// 锁定 #263：转换途中清空/切换选择后，旧任务的迟到进度、日志、完成与失败
/// 都不得写进新选择的状态；旧任务也不得复位新回合的 `isConverting`。
@Suite("VideoConverter 选择切换的回合身份隔离")
@MainActor
struct VideoConverterSelectionBindingTests {

    @Test("清空选择后旧任务的迟到进度/日志/完成不污染新选择")
    func lateCallbacksFromClearedConversionDoNotPolluteNewSelection() async {
        let stub = StubVideoConverter()
        let vm = VideoConverterViewModel(converter: stub)
        vm.selectedFile = makeItem("/tmp/a.mov")
        vm.startConversion()
        await waitUntil { stub.calls.count == 1 }
        #expect(vm.isConverting)

        // 转换中清空选择 → 旧回合被作废（代号递增 + 取消底层进程）。
        vm.clearSelection()
        vm.selectedFile = makeItem("/tmp/b.mov")

        // 旧任务仍在后台跑并迟到上报：进度、日志、完成。
        stub.calls[0].emitProgress(0.75)
        stub.calls[0].emitLog("old-task-line")
        stub.calls[0].finish()
        await settle()

        #expect(stub.cancelCallCount == 1)
        #expect(vm.progress == 0)
        #expect(vm.conversionLog.isEmpty)
        #expect(vm.isConverting == false)
    }

    @Test("转换中切换文件会取消旧任务并拒绝其迟到回调")
    func switchingFileCancelsOldConversionAndRejectsLateCallbacks() async {
        let stub = StubVideoConverter()
        let vm = VideoConverterViewModel(converter: stub)
        vm.selectedFile = makeItem("/tmp/a.mov")
        vm.startConversion()
        await waitUntil { stub.calls.count == 1 }

        // 走真实选择入口 loadFile 切换到另一个文件。
        await vm.loadFile(url: URL(fileURLWithPath: "/tmp/b.mov"))
        #expect(vm.selectedFile?.url.path == "/tmp/b.mov")
        #expect(vm.isConverting == false)

        stub.calls[0].emitProgress(0.9)
        stub.calls[0].emitLog("stale")
        stub.calls[0].finish()
        await settle()

        #expect(stub.cancelCallCount == 1)
        #expect(vm.progress == 0)
        #expect(vm.conversionLog.isEmpty)
    }

    @Test("未被作废的转换正常上报进度/日志并完成")
    func activeConversionAppliesProgressLogAndCompletion() async {
        let stub = StubVideoConverter()
        let vm = VideoConverterViewModel(converter: stub)
        vm.selectedFile = makeItem("/tmp/a.mov")
        vm.startConversion()
        await waitUntil { stub.calls.count == 1 }

        stub.calls[0].emitProgress(0.5)
        stub.calls[0].emitLog("hello")
        await settle()
        #expect(vm.progress == 0.5)
        #expect(vm.conversionLog.contains("hello"))

        stub.calls[0].finish()
        await settle()
        #expect(vm.progress == 1.0)
        #expect(vm.isConverting == false)
        #expect(stub.cancelCallCount == 0)
    }

    @Test("清空选择后旧任务的迟到失败不污染新选择")
    func lateErrorFromClearedConversionDoesNotPollute() async {
        let stub = StubVideoConverter()
        let vm = VideoConverterViewModel(converter: stub)
        vm.selectedFile = makeItem("/tmp/a.mov")
        vm.startConversion()
        await waitUntil { stub.calls.count == 1 }

        vm.clearSelection()
        vm.selectedFile = makeItem("/tmp/b.mov")

        stub.calls[0].fail(VideoConverterError.conversionFailed(exitCode: 1))
        await settle()

        #expect(vm.conversionLog.isEmpty)
        #expect(vm.isConverting == false)
    }

    @Test("旧任务迟到完成不得复位新回合的 isConverting")
    func oldTaskCompletionDoesNotResetNewConversionFlag() async {
        let stub = StubVideoConverter()
        let vm = VideoConverterViewModel(converter: stub)
        vm.selectedFile = makeItem("/tmp/a.mov")
        vm.startConversion()
        await waitUntil { stub.calls.count == 1 }

        // 清空 → 选新文件 → 立即开始新转换：此时代号已推进两轮。
        vm.clearSelection()
        vm.selectedFile = makeItem("/tmp/b.mov")
        vm.startConversion()
        await waitUntil { stub.calls.count == 2 }
        #expect(vm.isConverting)

        // 旧任务这时才完成：不得把新回合的 isConverting 复位，也不得写进度。
        stub.calls[0].finish()
        await settle()
        #expect(vm.isConverting)
        #expect(vm.progress == 0)

        // 新任务正常完成才复位。
        stub.calls[1].finish()
        await settle()
        #expect(vm.isConverting == false)
        #expect(vm.progress == 1.0)
    }

    @Test("空闲时清空选择不触发取消")
    func clearWhenIdleDoesNotCancel() {
        let stub = StubVideoConverter()
        let vm = VideoConverterViewModel(converter: stub)
        vm.selectedFile = makeItem("/tmp/a.mov")

        vm.clearSelection()

        #expect(vm.selectedFile == nil)
        #expect(stub.cancelCallCount == 0)
        #expect(stub.calls.isEmpty)
    }
}