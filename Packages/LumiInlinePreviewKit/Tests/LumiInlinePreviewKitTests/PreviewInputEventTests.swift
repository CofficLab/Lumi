import AppKit
import XCTest
@testable import LumiInlinePreviewKit

final class PreviewInputEventTests: XCTestCase {

    // MARK: - Codable round-trips

    func test_mouseEvent_roundTrip() throws {
        let event = LumiInlinePreviewFacade.PreviewInputEvent.mouse(.init(
            phase: .down,
            button: .left,
            x: 12,
            y: 34,
            clickCount: 1,
            modifiers: [.shift, .command]
        ))
        try roundTrip(event)
    }

    func test_scrollWheelEvent_roundTrip() throws {
        let event = LumiInlinePreviewFacade.PreviewInputEvent.scrollWheel(.init(
            x: 100, y: 200,
            deltaX: 0, deltaY: -3,
            scrollingDeltaX: 0, scrollingDeltaY: -42,
            hasPreciseScrollingDeltas: true,
            modifiers: [],
            phase: .changed,
            momentumPhase: .none
        ))
        try roundTrip(event)
    }

    func test_keyEvent_roundTrip() throws {
        let event = LumiInlinePreviewFacade.PreviewInputEvent.key(.init(
            phase: .down,
            keyCode: 0x24,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            modifiers: [.shift]
        ))
        try roundTrip(event)
    }

    func test_flagsChanged_roundTrip() throws {
        let event = LumiInlinePreviewFacade.PreviewInputEvent.flagsChanged(modifiers: [.command, .option])
        try roundTrip(event)
    }

    // MARK: - AppKit bridging

    func test_modifierFlags_appKitRoundTrip_preservesMembers() {
        let original: LumiInlinePreviewFacade.ModifierFlags = [.shift, .command, .option, .capsLock]
        let appKit = original.toAppKit()
        let roundTripped = LumiInlinePreviewFacade.ModifierFlags.fromAppKitImported(appKit)
        XCTAssertEqual(roundTripped, original)
    }

    func test_scrollPhase_appKitRoundTrip() {
        for phase in [
            LumiInlinePreviewFacade.ScrollWheelEvent.Phase.began,
            .changed,
            .ended,
            .cancelled,
            .mayBegin,
            .stationary,
            .none
        ] {
            let roundTripped = LumiInlinePreviewFacade.ScrollWheelEvent.Phase.fromAppKit(phase.toAppKit())
            XCTAssertEqual(roundTripped, phase, "phase \(phase) did not round-trip via AppKit")
        }
    }

    // MARK: - HostCommand 编解码

    func test_hostCommand_forwardInputEvent_roundTrip() throws {
        let command = LumiInlinePreviewFacade.HostCommand.forwardInputEvent(
            .mouse(.init(
                phase: .up,
                button: .left,
                x: 1,
                y: 2,
                clickCount: 1,
                modifiers: []
            ))
        )
        try roundTrip(command)
    }

    // MARK: - Helpers

    private func roundTrip<T: Codable & Equatable>(
        _ value: T,
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(T.self, from: data)
        XCTAssertEqual(decoded, value, file: file, line: line)
    }
}
