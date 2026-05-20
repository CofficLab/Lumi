import AppKit
import XCTest
@testable import LumiPreviewKit

@MainActor
final class PreviewSurfaceViewTests: XCTestCase {

    func test_attach_setsCurrentSurfaceID_andLayerContents() throws {
        let frame = try XCTUnwrap(
            LumiPreviewFacade.DemoSurfaceFactory.makeFrame(
                width: 32, height: 32, scale: 1, seq: 1
            )
        )
        let view = LumiPreviewFacade.PreviewSurfaceView(frame: NSRect(x: 0, y: 0, width: 32, height: 32))
        XCTAssertNil(view.currentSurfaceID)

        view.attach(surfaceID: frame.surfaceID)

        XCTAssertEqual(view.currentSurfaceID, frame.surfaceID)
        XCTAssertNil(view.layer?.contents)
        XCTAssertNotEqual(view.debugContentLayerFrame, .zero)
        XCTAssertTrue(view.subviews.isEmpty)
    }

    func test_detach_clearsContents() throws {
        let frame = try XCTUnwrap(
            LumiPreviewFacade.DemoSurfaceFactory.makeFrame(
                width: 32, height: 32, scale: 1, seq: 1
            )
        )
        let view = LumiPreviewFacade.PreviewSurfaceView()
        view.attach(surfaceID: frame.surfaceID)

        view.detach()

        XCTAssertNil(view.currentSurfaceID)
        XCTAssertNil(view.layer?.contents)
        XCTAssertEqual(view.debugContentLayerFrame, .zero)
    }

    func test_attach_invalidSurfaceID_doesNotMutateState() {
        let view = LumiPreviewFacade.PreviewSurfaceView()
        view.attach(surfaceID: 0xFFFF_FFFF)
        XCTAssertNil(view.currentSurfaceID)
    }

    func test_setCursorShape_updatesCurrentShape() {
        let view = LumiPreviewFacade.PreviewSurfaceView()
        XCTAssertEqual(view.cursorShape, .arrow)

        view.setCursorShape(.pointingHand)

        XCTAssertEqual(view.cursorShape, .pointingHand)
    }

    func test_responderBehavior_followsInteractiveState() {
        let view = LumiPreviewFacade.PreviewSurfaceView()

        XCTAssertFalse(view.acceptsFirstResponder)
        XCTAssertFalse(view.acceptsFirstMouse(for: nil))

        view.isInteractive = true

        XCTAssertTrue(view.acceptsFirstResponder)
        XCTAssertTrue(view.acceptsFirstMouse(for: nil))
    }

    func test_mouseEvents_whenInteractive_forwardModels() throws {
        let view = LumiPreviewFacade.PreviewSurfaceView(frame: NSRect(x: 0, y: 0, width: 100, height: 80))
        view.isInteractive = true
        var events: [LumiPreviewFacade.PreviewInputEvent] = []
        view.onInputEvent = { events.append($0) }

        view.mouseDown(with: try makeMouseEvent(type: .leftMouseDown, location: NSPoint(x: 12, y: 34), clickCount: 2))
        view.mouseUp(with: try makeMouseEvent(type: .leftMouseUp, location: NSPoint(x: 13, y: 35), clickCount: 2))
        view.mouseDragged(with: try makeMouseEvent(type: .leftMouseDragged, location: NSPoint(x: 14, y: 36), clickCount: 1))
        view.mouseMoved(with: try makeMouseEvent(type: .mouseMoved, location: NSPoint(x: 22, y: 44), clickCount: 3))
        view.mouseEntered(with: try makeMouseEvent(type: .mouseMoved, location: NSPoint(x: 23, y: 45), clickCount: 3))
        view.mouseExited(with: try makeMouseEvent(type: .mouseMoved, location: NSPoint(x: 24, y: 46), clickCount: 3))
        view.rightMouseDown(with: try makeMouseEvent(type: .rightMouseDown, location: NSPoint(x: 31, y: 53), clickCount: 1))
        view.rightMouseUp(with: try makeMouseEvent(type: .rightMouseUp, location: NSPoint(x: 32, y: 54), clickCount: 1))
        view.rightMouseDragged(with: try makeMouseEvent(type: .rightMouseDragged, location: NSPoint(x: 33, y: 55), clickCount: 1))
        view.otherMouseDown(with: try makeMouseEvent(type: .otherMouseDown, location: NSPoint(x: 41, y: 63), clickCount: 1))
        view.otherMouseUp(with: try makeMouseEvent(type: .otherMouseUp, location: NSPoint(x: 42, y: 64), clickCount: 1))
        view.otherMouseDragged(with: try makeMouseEvent(type: .otherMouseDragged, location: NSPoint(x: 42, y: 64), clickCount: 1))

        XCTAssertEqual(events.count, 12)
        XCTAssertEqual(events[0], .mouse(.init(phase: .down, button: .left, x: 12, y: 34, clickCount: 2, modifiers: [.shift])))
        XCTAssertEqual(events[1], .mouse(.init(phase: .up, button: .left, x: 13, y: 35, clickCount: 2, modifiers: [.shift])))
        XCTAssertEqual(events[2], .mouse(.init(phase: .dragged, button: .left, x: 14, y: 36, clickCount: 1, modifiers: [.shift])))
        XCTAssertEqual(events[3], .mouse(.init(phase: .moved, button: .left, x: 22, y: 44, clickCount: 0, modifiers: [.shift])))
        XCTAssertEqual(events[4], .mouse(.init(phase: .entered, button: .left, x: 23, y: 45, clickCount: 0, modifiers: [.shift])))
        XCTAssertEqual(events[5], .mouse(.init(phase: .exited, button: .left, x: 24, y: 46, clickCount: 0, modifiers: [.shift])))
        XCTAssertEqual(events[6], .mouse(.init(phase: .down, button: .right, x: 31, y: 53, clickCount: 1, modifiers: [.shift])))
        XCTAssertEqual(events[7], .mouse(.init(phase: .up, button: .right, x: 32, y: 54, clickCount: 1, modifiers: [.shift])))
        XCTAssertEqual(events[8], .mouse(.init(phase: .dragged, button: .right, x: 33, y: 55, clickCount: 1, modifiers: [.shift])))
        XCTAssertEqual(events[9], .mouse(.init(phase: .down, button: .other, x: 41, y: 63, clickCount: 1, modifiers: [.shift])))
        XCTAssertEqual(events[10], .mouse(.init(phase: .up, button: .other, x: 42, y: 64, clickCount: 1, modifiers: [.shift])))
        XCTAssertEqual(events[11], .mouse(.init(phase: .dragged, button: .other, x: 42, y: 64, clickCount: 1, modifiers: [.shift])))
    }

    func test_keyAndFlagsEvents_whenInteractive_forwardModels() throws {
        let view = LumiPreviewFacade.PreviewSurfaceView()
        view.isInteractive = true
        var events: [LumiPreviewFacade.PreviewInputEvent] = []
        view.onInputEvent = { events.append($0) }

        let keyUp = try makeKeyEvent(type: .keyUp, characters: "a", keyCode: 0)
        let flags = try makeKeyEvent(type: .flagsChanged, characters: "", keyCode: 0, modifiers: [.command, .option])

        view.keyUp(with: keyUp)
        view.flagsChanged(with: flags)

        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0], .key(.init(
            phase: .up,
            keyCode: 0,
            characters: "a",
            charactersIgnoringModifiers: "a",
            isARepeat: false,
            modifiers: [.command]
        )))
        XCTAssertEqual(events[1], .flagsChanged(modifiers: [.command, .option]))
    }

    func test_scrollWheel_whenInteractive_forwardsModel() throws {
        let view = LumiPreviewFacade.PreviewSurfaceView(frame: NSRect(x: 0, y: 0, width: 100, height: 80))
        view.isInteractive = true
        var forwardedEvent: LumiPreviewFacade.PreviewInputEvent?
        view.onInputEvent = { forwardedEvent = $0 }

        view.scrollWheel(with: try makeScrollEvent(location: NSPoint(x: 11, y: 22)))

        guard case .scrollWheel(let event) = forwardedEvent else {
            return XCTFail("Expected scrollWheel event")
        }
        XCTAssertEqual(event.x, 11)
        XCTAssertEqual(event.scrollingDeltaX, 3)
        XCTAssertEqual(event.scrollingDeltaY, -4)
        XCTAssertTrue(event.hasPreciseScrollingDeltas)
        XCTAssertEqual(event.modifiers, [.option])
        XCTAssertEqual(event.phase, .none)
        XCTAssertEqual(event.momentumPhase, .none)
    }

    func test_mouseEvents_mapThroughAspectFitContentRect() throws {
        let frame = try XCTUnwrap(
            LumiPreviewFacade.DemoSurfaceFactory.makeFrame(
                width: 100, height: 100, scale: 1, seq: 1
            )
        )
        let view = LumiPreviewFacade.PreviewSurfaceView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
        view.isInteractive = true
        view.attach(surfaceID: frame.surfaceID)
        var forwardedEvent: LumiPreviewFacade.PreviewInputEvent?
        view.onInputEvent = { forwardedEvent = $0 }

        view.mouseDown(with: try makeMouseEvent(type: .leftMouseDown, location: NSPoint(x: 100, y: 50), clickCount: 1))

        XCTAssertEqual(forwardedEvent, .mouse(.init(
            phase: .down,
            button: .left,
            x: 50,
            y: 50,
            clickCount: 1,
            modifiers: [.shift]
        )))
    }

    func test_dragEvents_whenInteractive_forwardModels() {
        let view = LumiPreviewFacade.PreviewSurfaceView(frame: NSRect(x: 0, y: 0, width: 100, height: 80))
        view.isInteractive = true
        let draggingInfo = FakeDraggingInfo(
            location: NSPoint(x: 9, y: 10),
            pasteboard: makeDraggingPasteboard()
        )
        var events: [LumiPreviewFacade.PreviewInputEvent] = []
        view.onInputEvent = { events.append($0) }

        XCTAssertEqual(view.draggingEntered(draggingInfo), .copy)
        XCTAssertEqual(view.draggingUpdated(draggingInfo), .copy)
        view.draggingExited(draggingInfo)
        XCTAssertTrue(view.performDragOperation(draggingInfo))

        XCTAssertEqual(events.count, 4)
        XCTAssertEqual(events[0], .dragAndDrop(.init(
            phase: .entered,
            x: 9,
            y: 10,
            items: [.fileURL("/tmp/lumi-inline-preview-drag.txt"), .string("drag text")],
            modifiers: []
        )))
        XCTAssertEqual(events[1], .dragAndDrop(.init(
            phase: .updated,
            x: 9,
            y: 10,
            items: [.fileURL("/tmp/lumi-inline-preview-drag.txt"), .string("drag text")],
            modifiers: []
        )))
        XCTAssertEqual(events[2], .dragAndDrop(.init(
            phase: .exited,
            x: 9,
            y: 10,
            items: [.fileURL("/tmp/lumi-inline-preview-drag.txt"), .string("drag text")],
            modifiers: []
        )))
        XCTAssertEqual(events[3], .dragAndDrop(.init(
            phase: .perform,
            x: 9,
            y: 10,
            items: [.fileURL("/tmp/lumi-inline-preview-drag.txt"), .string("drag text")],
            modifiers: []
        )))
    }

    func test_dragEvents_whenNotInteractive_doNotForward() {
        let view = LumiPreviewFacade.PreviewSurfaceView()
        let draggingInfo = FakeDraggingInfo(
            location: NSPoint(x: 9, y: 10),
            pasteboard: makeDraggingPasteboard()
        )
        var events: [LumiPreviewFacade.PreviewInputEvent] = []
        view.onInputEvent = { events.append($0) }

        XCTAssertEqual(view.draggingEntered(draggingInfo), [])
        XCTAssertEqual(view.draggingUpdated(draggingInfo), [])
        view.draggingExited(nil)
        XCTAssertFalse(view.performDragOperation(draggingInfo))
        XCTAssertTrue(events.isEmpty)
    }

    func test_textInputClient_whenInteractive_forwardsCompositionEvents() {
        let view = LumiPreviewFacade.PreviewSurfaceView()
        view.isInteractive = true
        var events: [LumiPreviewFacade.PreviewInputEvent] = []
        view.onInputEvent = { events.append($0) }

        view.setMarkedText(
            NSAttributedString(string: "zhong"),
            selectedRange: NSRange(location: 1, length: 2),
            replacementRange: NSRange(location: 3, length: 4)
        )
        XCTAssertTrue(view.hasMarkedText())
        XCTAssertEqual(view.markedRange(), NSRange(location: 0, length: 5))

        view.insertText("中", replacementRange: NSRange(location: 0, length: 5))
        view.unmarkText()

        XCTAssertFalse(view.hasMarkedText())
        XCTAssertEqual(view.markedRange(), NSRange(location: NSNotFound, length: 0))
        XCTAssertEqual(view.selectedRange(), NSRange(location: NSNotFound, length: 0))
        XCTAssertEqual(view.validAttributesForMarkedText(), [])
        XCTAssertEqual(view.characterIndex(for: .zero), 0)

        var actualRange = NSRange(location: 99, length: 99)
        XCTAssertNil(view.attributedSubstring(forProposedRange: NSRange(location: 1, length: 1), actualRange: &actualRange))
        XCTAssertEqual(actualRange, NSRange(location: NSNotFound, length: 0))

        XCTAssertEqual(events.count, 3)
        XCTAssertEqual(events[0], .textInput(.init(
            phase: .setMarkedText,
            text: "zhong",
            selectedRange: .init(location: 1, length: 2),
            replacementRange: .init(location: 3, length: 4)
        )))
        XCTAssertEqual(events[1], .textInput(.init(
            phase: .insertText,
            text: "中",
            replacementRange: .init(location: 0, length: 5)
        )))
        XCTAssertEqual(events[2], .textInput(.init(phase: .unmarkText, text: "")))
    }

    func test_textInputClient_whenNotInteractive_doesNotForward() {
        let view = LumiPreviewFacade.PreviewSurfaceView()
        var events: [LumiPreviewFacade.PreviewInputEvent] = []
        view.onInputEvent = { events.append($0) }

        view.insertText("x", replacementRange: NSRange(location: 0, length: 0))
        view.setMarkedText("x", selectedRange: NSRange(location: 0, length: 1), replacementRange: NSRange(location: 0, length: 0))

        XCTAssertTrue(events.isEmpty)
        XCTAssertFalse(view.hasMarkedText())
    }

    func test_layoutAndBackingChanges_notifySize() {
        let view = LumiPreviewFacade.PreviewSurfaceView(frame: NSRect(x: 0, y: 0, width: 123, height: 45))
        var notifications: [(size: CGSize, scale: CGFloat)] = []
        view.onSizeChange = { notifications.append(($0, $1)) }

        view.layout()
        view.viewDidChangeBackingProperties()
        view.viewDidMoveToWindow()

        XCTAssertEqual(notifications.count, 3)
        XCTAssertEqual(notifications.map(\.size), Array(repeating: CGSize(width: 123, height: 45), count: 3))
        XCTAssertEqual(notifications.map(\.scale), [1, 1, 1])
    }

    func test_firstRect_withoutWindow_returnsZeroAndSetsActualRange() {
        let view = LumiPreviewFacade.PreviewSurfaceView()
        var actualRange = NSRange(location: 0, length: 0)

        let rect = view.firstRect(forCharacterRange: NSRange(location: 2, length: 3), actualRange: &actualRange)

        XCTAssertEqual(rect, .zero)
        XCTAssertEqual(actualRange, NSRange(location: 2, length: 3))
    }

    func test_trackingAreas_areReplacedOnUpdate() {
        let view = LumiPreviewFacade.PreviewSurfaceView(frame: NSRect(x: 0, y: 0, width: 100, height: 80))

        view.updateTrackingAreas()
        let firstTrackingAreas = view.trackingAreas

        view.updateTrackingAreas()
        let secondTrackingAreas = view.trackingAreas

        XCTAssertEqual(firstTrackingAreas.count, 1)
        XCTAssertEqual(secondTrackingAreas.count, 1)
        XCTAssertFalse(firstTrackingAreas[0] === secondTrackingAreas[0])
        XCTAssertTrue(secondTrackingAreas[0].options.contains(.mouseMoved))
        XCTAssertTrue(secondTrackingAreas[0].options.contains(.mouseEnteredAndExited))
    }

    func test_updateLayer_andWantsUpdateLayer_areStableNoops() {
        let view = LumiPreviewFacade.PreviewSurfaceView()

        XCTAssertTrue(view.wantsUpdateLayer)
        view.updateLayer()
    }

    private func makeMouseEvent(
        type: NSEvent.EventType,
        location: NSPoint,
        clickCount: Int
    ) throws -> NSEvent {
        try XCTUnwrap(NSEvent.mouseEvent(
            with: type,
            location: location,
            modifierFlags: [.shift],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 1,
            clickCount: clickCount,
            pressure: 0
        ))
    }

    private func makeKeyEvent(
        type: NSEvent.EventType,
        characters: String,
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags = [.command]
    ) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(
            with: type,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: keyCode
        ))
    }

    private func makeScrollEvent(location: NSPoint) throws -> NSEvent {
        let cgEvent = try XCTUnwrap(CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: -4,
            wheel2: 3,
            wheel3: 0
        ))
        cgEvent.location = location
        cgEvent.flags = .maskAlternate

        return try XCTUnwrap(NSEvent(cgEvent: cgEvent))
    }

    private func makeDraggingPasteboard() -> NSPasteboard {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("LumiPreviewKitTests-\(UUID().uuidString)"))
        pasteboard.clearContents()
        pasteboard.writeObjects([URL(fileURLWithPath: "/tmp/lumi-inline-preview-drag.txt") as NSURL])
        pasteboard.setString("drag text", forType: .string)
        return pasteboard
    }
}

private final class FakeDraggingInfo: NSObject, NSDraggingInfo {
    let draggingLocation: NSPoint
    let draggingPasteboard: NSPasteboard
    var draggingFormation: NSDraggingFormation = .default
    var animatesToDestination: Bool = false
    var numberOfValidItemsForDrop: Int = 0

    @MainActor
    init(location: NSPoint, pasteboard: NSPasteboard) {
        self.draggingLocation = location
        self.draggingPasteboard = pasteboard
    }

    var draggingDestinationWindow: NSWindow? { nil }
    var draggingSourceOperationMask: NSDragOperation { .copy }
    var draggingSource: Any? { nil }
    var draggingSequenceNumber: Int { 1 }
    var draggedImageLocation: NSPoint { draggingLocation }
    var draggedImage: NSImage? { nil }
    var springLoadingHighlight: NSSpringLoadingHighlight { .none }

    func slideDraggedImage(to screenPoint: NSPoint) {}

    override func namesOfPromisedFilesDropped(atDestination dropDestination: URL) -> [String]? {
        nil
    }

    func enumerateDraggingItems(
        options enumOpts: NSDraggingItemEnumerationOptions = [],
        for view: NSView?,
        classes classArray: [AnyClass],
        searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
        using block: @escaping (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void
    ) {}

    func resetSpringLoading() {}
}
