import AppKit
import XCTest
@testable import LumiInlinePreviewKit

final class PreviewInputEventTests: XCTestCase {

    // MARK: - Codable round-trips

    func test_mouseEvent_roundTrip() throws {
        for phase in [
            LumiInlinePreviewFacade.MouseEvent.Phase.down,
            .up,
            .moved,
            .dragged,
            .entered,
            .exited
        ] {
            let event = LumiInlinePreviewFacade.PreviewInputEvent.mouse(.init(
                phase: phase,
                button: .left,
                x: 12,
                y: 34,
                clickCount: 1,
                modifiers: [.shift, .command]
            ))
            try roundTrip(event)
        }
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

    func test_textInputEvents_roundTrip() throws {
        let events: [LumiInlinePreviewFacade.PreviewInputEvent] = [
            .textInput(.init(
                phase: .setMarkedText,
                text: "zhong",
                selectedRange: .init(location: 0, length: 5),
                replacementRange: .notFound
            )),
            .textInput(.init(
                phase: .insertText,
                text: "中",
                replacementRange: .init(location: 0, length: 5)
            )),
            .textInput(.init(phase: .unmarkText, text: ""))
        ]
        for event in events {
            try roundTrip(event)
        }
    }

    func test_dragDropEvent_roundTrip() throws {
        let event = LumiInlinePreviewFacade.PreviewInputEvent.dragAndDrop(.init(
            phase: .perform,
            x: 44,
            y: 55,
            items: [
                .string("hello"),
                .fileURL("/tmp/example.txt")
            ],
            modifiers: [.option]
        ))
        try roundTrip(event)
    }

    func test_touchBarEvent_roundTrip() throws {
        let event = LumiInlinePreviewFacade.PreviewInputEvent.touchBar(.init(
            itemIdentifier: "com.coffic.lumi.inline-preview.fixture.increment",
            phase: .itemPressed,
            modifiers: [.command]
        ))
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
