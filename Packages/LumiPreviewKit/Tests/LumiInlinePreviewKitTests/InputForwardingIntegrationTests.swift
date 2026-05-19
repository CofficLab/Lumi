import IOSurface
import XCTest
@testable import LumiInlinePreviewKit

private actor InputProbe {
    private(set) var frameCount = 0
    private(set) var errors: [String] = []
    private var waitingForInputInteractive = false

    func recordFrame() { frameCount += 1 }
    func recordError(_ message: String) { errors.append(message) }
    func beginWaitingForInputInteractive() {
        waitingForInputInteractive = true
    }
    func observePolicy(_ policy: LumiInlinePreviewFacade.FrameStreamPolicy) -> (idle: Bool, inputInteractive: Bool) {
        if policy == .idle {
            return (true, false)
        }
        if policy == .interactive, waitingForInputInteractive {
            waitingForInputInteractive = false
            return (false, true)
        }
        return (false, false)
    }
}

/// 端到端验证 Phase 3 输入转发：
///
/// 启动子进程 → startFrameStream → 连发一组鼠标 / 滚轮 / 键盘事件 →
/// 同步响应都成功 + 子进程不崩 + 后续 ping 仍通 + 没收到 error 事件。
///
/// 此处不严格验证"事件改变了画面"——那需要用户 dylib 暴露状态读取符号，留给上层端到端测。
/// 这一层只把跨进程注入路径打通的合规性测出来。
final class InputForwardingIntegrationTests: XCTestCase {

    func test_forwardInputEvent_acceptsAllShapes_andKeepsSubprocessAlive() async throws {
        guard let url = LumiInlinePreviewFacade.InlineHostExecutableResolver.resolve() else {
            throw XCTSkip("LumiInlinePreviewHostApp binary not found; run `swift build` first.")
        }

        let connection = try LumiInlinePreviewFacade.ProcessInlineHostConnection.launch(executableURL: url)

        let probe = InputProbe()
        let events = connection.events
        let eventTask = Task {
            for await event in events {
                switch event {
                case .frameProduced:
                    await probe.recordFrame()
                case .error(let message):
                    await probe.recordError(message)
                case .streamStateChanged(let policy):
                    _ = await probe.observePolicy(policy)
                case .entryLoaded, .entryDebugState, .cursorChanged:
                    break
                }
            }
        }

        // 起流（让子进程进入 interactive policy；无须等帧到再发事件）。
        let start = try await connection.send(.startFrameStream(width: 320, height: 180, scale: 2))
        XCTAssertTrue(start.success)

        // 模拟一组真实 SwiftUI 控件交互序列。
        let eventsToSend: [LumiInlinePreviewFacade.PreviewInputEvent] = [
            .mouse(.init(phase: .entered, button: .left, x: 40, y: 70, clickCount: 0, modifiers: [])),
            .mouse(.init(phase: .down, button: .left, x: 50, y: 80, clickCount: 1, modifiers: [])),
            .mouse(.init(phase: .up, button: .left, x: 50, y: 80, clickCount: 1, modifiers: [])),
            .mouse(.init(phase: .moved, button: .left, x: 60, y: 90, clickCount: 0, modifiers: [])),
            .mouse(.init(phase: .dragged, button: .left, x: 80, y: 100, clickCount: 0, modifiers: [])),
            .mouse(.init(phase: .exited, button: .left, x: 280, y: 140, clickCount: 0, modifiers: [])),
            .dragAndDrop(.init(
                phase: .perform,
                x: 120,
                y: 90,
                items: [.string("drop payload")],
                modifiers: []
            )),
            .touchBar(.init(
                itemIdentifier: "com.coffic.lumi.inline-preview.fixture.action",
                phase: .itemPressed,
                modifiers: []
            )),
            .scrollWheel(.init(
                x: 100, y: 100,
                deltaX: 0, deltaY: -2,
                scrollingDeltaX: 0, scrollingDeltaY: -20,
                hasPreciseScrollingDeltas: true,
                modifiers: [],
                phase: .changed,
                momentumPhase: .none
            )),
            .key(.init(
                phase: .down,
                keyCode: 0x24,
                characters: "\r",
                charactersIgnoringModifiers: "\r",
                isARepeat: false,
                modifiers: []
            )),
            .key(.init(
                phase: .up,
                keyCode: 0x24,
                characters: "\r",
                charactersIgnoringModifiers: "\r",
                isARepeat: false,
                modifiers: []
            )),
            .flagsChanged(modifiers: [.shift]),
            .flagsChanged(modifiers: [])
        ]

        for event in eventsToSend {
            let response = try await connection.send(.forwardInputEvent(event))
            XCTAssertTrue(response.success, "forwardInputEvent should succeed for \(event)")
        }

        // 子进程仍存活：ping 必须能往返
        let pong = try await connection.send(.ping)
        XCTAssertTrue(pong.success)
        XCTAssertEqual(pong.message, "pong")

        // 没有 error 事件溢出
        let errors = await probe.errors
        XCTAssertTrue(errors.isEmpty, "subprocess pushed errors during input forwarding: \(errors)")

        eventTask.cancel()
        await connection.terminate()
    }

    func test_forwardInputEvent_promotesIdleStreamBackToInteractive() async throws {
        guard let url = LumiInlinePreviewFacade.InlineHostExecutableResolver.resolve() else {
            throw XCTSkip("LumiInlinePreviewHostApp binary not found; run `swift build` first.")
        }

        let connection = try LumiInlinePreviewFacade.ProcessInlineHostConnection.launch(executableURL: url)

        let probe = InputProbe()
        let idleExpectation = expectation(description: "stream cooled down to idle")
        let interactiveExpectation = expectation(description: "input promoted stream to interactive")
        var pendingIdle: XCTestExpectation? = idleExpectation
        var pendingInteractive: XCTestExpectation? = interactiveExpectation

        let events = connection.events
        let eventTask = Task {
            for await event in events {
                switch event {
                case .streamStateChanged(let policy):
                    let result = await probe.observePolicy(policy)
                    if result.idle, let exp = pendingIdle {
                        pendingIdle = nil
                        exp.fulfill()
                    }
                    if result.inputInteractive, let exp = pendingInteractive {
                        pendingInteractive = nil
                        exp.fulfill()
                    }
                case .frameProduced:
                    await probe.recordFrame()
                case .error(let message):
                    await probe.recordError(message)
                case .entryLoaded, .entryDebugState, .cursorChanged:
                    break
                }
            }
        }

        let start = try await connection.send(.startFrameStream(width: 320, height: 180, scale: 2))
        XCTAssertTrue(start.success)

        await fulfillment(of: [idleExpectation], timeout: 4)
        let idleStartFrameCount = await probe.frameCount
        try await Task.sleep(nanoseconds: 2_300_000_000)
        let afterDirtyIdleFrameCount = await probe.frameCount
        try await Task.sleep(nanoseconds: 1_300_000_000)
        let afterSettledIdleFrameCount = await probe.frameCount
        XCTAssertLessThanOrEqual(
            afterDirtyIdleFrameCount - idleStartFrameCount,
            2,
            "idle should only consume the pending dirty frame, not keep snapshotting continuously"
        )
        XCTAssertEqual(
            afterSettledIdleFrameCount,
            afterDirtyIdleFrameCount,
            "settled idle stream should not produce frames while the renderer is clean"
        )

        await probe.beginWaitingForInputInteractive()
        let inputEvent = LumiInlinePreviewFacade.PreviewInputEvent.mouse(.init(
            phase: .moved,
            button: .left,
            x: 80,
            y: 80,
            clickCount: 0,
            modifiers: []
        ))
        let response = try await connection.send(.forwardInputEvent(inputEvent))
        XCTAssertTrue(response.success)

        await fulfillment(of: [interactiveExpectation], timeout: 2)

        let errors = await probe.errors
        XCTAssertTrue(errors.isEmpty, "subprocess pushed errors during policy cooldown test: \(errors)")

        eventTask.cancel()
        await connection.terminate()
    }
}
