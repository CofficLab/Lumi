import Foundation
import ScreenCaptureKit
import Testing
@testable import ScreenRecorderPlugin

/// 回归 #224：start 的互斥必须从进入启动流程持有到会话建立。
/// `currentSession` 在引擎启动成功前尚未写入，权限等待 / 目标解析 / 引擎启动
/// 的每个 await 都是 MainActor 重入窗口；只查 `hasActiveSession` 会让并发
/// start 全部通过，后到者覆盖先到者的 recorder / session。
@MainActor
@Suite("RecordingSessionManager 并发启动互斥（#224）")
struct RecordingSessionManagerConcurrencyTests {

    // MARK: - 测试基础设施

    /// 可等待的门闩：让第一个 start 确定性地停在某个 await 上。
    private actor Gate {
        private var arrived = false
        private var released = false
        private var arrivalWaiters: [CheckedContinuation<Void, Never>] = []
        private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

        func arrive() {
            arrived = true
            arrivalWaiters.forEach { $0.resume() }
            arrivalWaiters.removeAll()
        }

        func waitArrival() async {
            if arrived { return }
            await withCheckedContinuation { arrivalWaiters.append($0) }
        }

        func waitRelease() async {
            if released { return }
            await withCheckedContinuation { releaseWaiters.append($0) }
        }

        func release() {
            released = true
            releaseWaiters.forEach { $0.resume() }
            releaseWaiters.removeAll()
        }
    }

    @MainActor
    private final class PermissionBox {
        var completions: [@Sendable (Bool) -> Void] = []
    }

    /// 引擎桩：start 总是失败，让流程走到引擎启动阶段而不触碰真实采集。
    private final class FailingRecorder: RecordingEngine, @unchecked Sendable {
        var onError: (@Sendable (Error) -> Void)?
        @MainActor
        func start(filter: SCContentFilter, config: RecordingConfig, tempOutputURL: URL) async throws {
            throw RecordingError.encodingFailed("stub recorder")
        }
        func stop() async throws -> ScreenCaptureRecorder.Output { throw RecordingError.notRecording }
        func cancel() async {}
    }

    /// 引擎桩：start 空操作成功，用于建立活动会话。
    private final class IdleRecorder: RecordingEngine, @unchecked Sendable {
        var onError: (@Sendable (Error) -> Void)?
        @MainActor
        func start(filter: SCContentFilter, config: RecordingConfig, tempOutputURL: URL) async throws {}
        func stop() async throws -> ScreenCaptureRecorder.Output { throw RecordingError.notRecording }
        func cancel() async {}
    }

    private enum SecondOutcome: Sendable {
        case finished(Error?)
        case timedOut
    }

    /// 等待第二个 start 的结果；5 秒未收尾视为挂起（互斥失效时它会停在
    /// 与第一个 start 相同的 await 上）。无论结果如何都执行 release，
    /// 让第一个 start 能够收尾，避免 task group 悬挂。
    private func awaitSecondStart(
        _ task: Task<Error?, Never>,
        release: () async -> Void
    ) async -> SecondOutcome {
        await withTaskGroup(of: SecondOutcome.self) { group in
            group.addTask { .finished(await task.value) }
            group.addTask {
                try? await Task.sleep(for: .seconds(5))
                return .timedOut
            }
            let first = await group.next() ?? .timedOut
            await release()
            group.cancelAll()
            return first
        }
    }

    private func startTask(
        _ manager: RecordingSessionManager,
        config: RecordingConfig
    ) -> Task<Error?, Never> {
        Task { @MainActor in
            do {
                try await manager.start(config: config)
                return nil
            } catch {
                return error
            }
        }
    }

    private func makeConfig(includeMicrophone: Bool = false) -> RecordingConfig {
        RecordingConfig(
            target: .display(),
            includeMicrophone: includeMicrophone,
            outputDirectory: URL(fileURLWithPath: NSTemporaryDirectory())
        )
    }

    private func expectAlreadyRecording(_ outcome: SecondOutcome) {
        switch outcome {
        case .timedOut:
            Issue.record("第二个 start 未被互斥拒绝，挂起在启动流程的 await 上")
        case .finished(let error):
            switch error as? RecordingError {
            case .some(.alreadyRecording):
                break
            default:
                Issue.record("期望 alreadyRecording，实际: \(String(describing: error))")
            }
        }
    }

    // MARK: - 回归用例

    @Test("目标解析期间的第二个 start 必须被拒绝 alreadyRecording（#224）")
    func secondStartDuringTargetResolutionIsRejected() async {
        let manager = RecordingSessionManager()
        manager.screenRecordingPermissionProvider = { true }
        let gate = Gate()
        manager.targetResolver = { _ in
            await gate.arrive()
            await gate.waitRelease()
            return (SCContentFilter(), "Stub", nil)
        }
        manager.recorderFactory = { FailingRecorder() }
        let config = makeConfig()

        let first = startTask(manager, config: config)
        await gate.waitArrival()

        let second = startTask(manager, config: config)
        let outcome = await awaitSecondStart(second) { await gate.release() }
        expectAlreadyRecording(outcome)

        // 第一个请求按自己的路径收尾（引擎桩失败），未被第二个请求覆盖。
        let firstError = await first.value
        switch firstError as? RecordingError {
        case .some(.encodingFailed):
            break
        default:
            Issue.record("期望第一个 start 以引擎桩错误收尾，实际: \(String(describing: firstError))")
        }
        #expect(manager.hasActiveSession == false)

        // 失败后互斥必须释放：再次 start 能重新进入解析与引擎阶段。
        do {
            try await manager.start(config: config)
            Issue.record("期望引擎桩失败")
        } catch let error as RecordingError {
            guard case .encodingFailed = error else {
                Issue.record("期望重新启动后仍为 encodingFailed，实际: \(error)")
                return
            }
        } catch {
            Issue.record("非预期错误: \(error)")
        }
    }

    @Test("麦克风权限等待期间的第二个 start 必须被拒绝 alreadyRecording（#224）")
    func secondStartDuringMicrophonePermissionIsRejected() async {
        let manager = RecordingSessionManager()
        manager.osMajorVersionProvider = { 15 }
        manager.screenRecordingPermissionProvider = { true }
        manager.microphonePermissionProvider = { false }
        let gate = Gate()
        let box = PermissionBox()
        manager.microphonePermissionRequester = { completion in
            box.completions.append(completion)
            Task { await gate.arrive() }
        }
        manager.recorderFactory = { FailingRecorder() }
        let config = makeConfig(includeMicrophone: true)

        let first = startTask(manager, config: config)
        await gate.waitArrival()

        let second = startTask(manager, config: config)
        let outcome = await awaitSecondStart(second) {
            box.completions.forEach { $0(false) }
        }
        expectAlreadyRecording(outcome)
        // 被拒绝的请求不得再次触发权限弹窗。
        #expect(box.completions.count == 1)

        let firstError = await first.value
        switch firstError as? RecordingError {
        case .some(.microphonePermissionDenied):
            break
        default:
            Issue.record("期望第一个 start 以麦克风权限拒绝收尾，实际: \(String(describing: firstError))")
        }
        #expect(manager.hasActiveSession == false)
    }

    @Test("已建立的会话拒绝第二个 start 且不被覆盖（#224）")
    func activeSessionRejectsSecondStartWithoutOverwrite() async throws {
        let manager = RecordingSessionManager()
        manager.screenRecordingPermissionProvider = { true }
        manager.targetResolver = { _ in (SCContentFilter(), "Stub", nil) }
        manager.recorderFactory = { IdleRecorder() }
        let config = makeConfig()

        try await manager.start(config: config)
        #expect(manager.hasActiveSession)
        let sessionID = manager.currentSession?.id

        do {
            try await manager.start(config: config)
            Issue.record("期望 alreadyRecording")
        } catch let error as RecordingError {
            guard case .alreadyRecording = error else {
                Issue.record("期望 alreadyRecording，实际: \(error)")
                return
            }
        }
        #expect(manager.currentSession?.id == sessionID)
        #expect(manager.hasActiveSession)
        await manager.cancel()
    }
}