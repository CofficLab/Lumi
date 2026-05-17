import IOSurface
import XCTest
@testable import LumiInlinePreviewKit

private actor InputProbe {
    private(set) var frameCount = 0
    private(set) var errors: [String] = []

    func recordFrame() { frameCount += 1 }
    func recordError(_ message: String) { errors.append(message) }
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
                case .streamStateChanged, .entryLoaded:
                    break
                }
            }
        }

        // 起流（让子进程进入 interactive policy；无须等帧到再发事件）。
        let start = try await connection.send(.startFrameStream(width: 320, height: 180, scale: 2))
        XCTAssertTrue(start.success)

        // 模拟一组真实 SwiftUI 控件交互序列。
        let eventsToSend: [LumiInlinePreviewFacade.PreviewInputEvent] = [
            .mouse(.init(phase: .down, button: .left, x: 50, y: 80, clickCount: 1, modifiers: [])),
            .mouse(.init(phase: .up, button: .left, x: 50, y: 80, clickCount: 1, modifiers: [])),
            .mouse(.init(phase: .moved, button: .left, x: 60, y: 90, clickCount: 0, modifiers: [])),
            .mouse(.init(phase: .dragged, button: .left, x: 80, y: 100, clickCount: 0, modifiers: [])),
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
}
