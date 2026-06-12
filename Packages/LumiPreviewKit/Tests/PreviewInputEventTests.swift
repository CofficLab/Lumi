import AppKit
import XCTest
@testable import LumiPreviewKit

final class PreviewInputEventTests: XCTestCase {

    // MARK: - Codable round-trips

    func test_mouseEvent_roundTrip() throws {
        for phase in [
            LumiPreviewFacade.MouseEvent.Phase.down,
            .up,
            .moved,
            .dragged,
            .entered,
            .exited
        ] {
            let event = LumiPreviewFacade.PreviewInputEvent.mouse(.init(
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
        let event = LumiPreviewFacade.PreviewInputEvent.scrollWheel(.init(
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
        let event = LumiPreviewFacade.PreviewInputEvent.key(.init(
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
        let event = LumiPreviewFacade.PreviewInputEvent.flagsChanged(modifiers: [.command, .option])
        try roundTrip(event)
    }

    func test_textInputEvents_roundTrip() throws {
        let events: [LumiPreviewFacade.PreviewInputEvent] = [
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
        let event = LumiPreviewFacade.PreviewInputEvent.dragAndDrop(.init(
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
        let event = LumiPreviewFacade.PreviewInputEvent.touchBar(.init(
            itemIdentifier: "com.coffic.lumi.inline-preview.fixture.increment",
            phase: .itemPressed,
            modifiers: [.command]
        ))
        try roundTrip(event)
    }

    // MARK: - AppKit bridging

    func test_modifierFlags_appKitRoundTrip_preservesMembers() {
        let original: LumiPreviewFacade.ModifierFlags = [.shift, .command, .option, .capsLock]
        let appKit = original.toAppKit()
        let roundTripped = LumiPreviewFacade.ModifierFlags.fromAppKitImported(appKit)
        XCTAssertEqual(roundTripped, original)
    }

    func test_scrollPhase_appKitRoundTrip() {
        for phase in [
            LumiPreviewFacade.ScrollWheelEvent.Phase.began,
            .changed,
            .ended,
            .cancelled,
            .mayBegin,
            .stationary,
            .none
        ] {
            let roundTripped = LumiPreviewFacade.ScrollWheelEvent.Phase.fromAppKit(phase.toAppKit())
            XCTAssertEqual(roundTripped, phase, "phase \(phase) did not round-trip via AppKit")
        }
    }

    func test_cursorShape_appKitRoundTrip_preservesKnownShapes() {
        var seenCursors: [NSCursor] = []

        for shape in LumiPreviewFacade.PreviewCursorShape.allCases {
            let cursor = shape.appKitCursor
            if shape != .arrow, cursor === NSCursor.arrow {
                continue
            }
            if seenCursors.contains(where: { $0 === cursor }) {
                continue
            }
            seenCursors.append(cursor)

            let roundTripped = LumiPreviewFacade.PreviewCursorShape(appKit: cursor)
            XCTAssertEqual(roundTripped, shape, "cursor shape \(shape) did not round-trip via AppKit")
        }
    }

    func test_cursorShape_appKitInitializer_defaultsUnknownCursorToArrow() {
        let customCursor = NSCursor(
            image: NSImage(size: NSSize(width: 8, height: 8)),
            hotSpot: .zero
        )

        XCTAssertEqual(LumiPreviewFacade.PreviewCursorShape(appKit: customCursor), .arrow)
    }

    // MARK: - HostCommand 编解码

    func test_hostCommand_forwardInputEvent_roundTrip() throws {
        let command = LumiPreviewFacade.HostCommand.forwardInputEvent(
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
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(T.self, from: data)
        XCTAssertEqual(decoded, value, file: file, line: line)
    }
}
