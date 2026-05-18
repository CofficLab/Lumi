import XCTest
@testable import LumiInlinePreviewKit

final class HostMessagesTests: XCTestCase {

    // MARK: - HostCommand

    func test_command_ping_roundTrip() throws {
        try roundTrip(LumiInlinePreviewFacade.HostCommand.ping)
    }

    func test_command_startFrameStream_roundTrip() throws {
        try roundTrip(LumiInlinePreviewFacade.HostCommand.startFrameStream(
            width: 320, height: 180, scale: 2
        ))
    }

    func test_command_stopFrameStream_roundTrip() throws {
        try roundTrip(LumiInlinePreviewFacade.HostCommand.stopFrameStream)
    }

    func test_command_setFrameStreamPolicy_roundTrip() throws {
        for policy in LumiInlinePreviewFacade.FrameStreamPolicy.allCases {
            try roundTrip(LumiInlinePreviewFacade.HostCommand.setFrameStreamPolicy(policy))
        }
    }

    func test_command_resizeSurface_roundTrip() throws {
        try roundTrip(LumiInlinePreviewFacade.HostCommand.resizeSurface(
            width: 640, height: 480, scale: 1.5
        ))
    }

    func test_command_loadDylib_roundTrip() throws {
        try roundTrip(LumiInlinePreviewFacade.HostCommand.loadDylib(
            path: "/tmp/preview.dylib",
            symbolName: "lumi_preview_make_nsview"
        ))
    }

    func test_command_unloadDylib_roundTrip() throws {
        try roundTrip(LumiInlinePreviewFacade.HostCommand.unloadDylib)
    }

    func test_command_requestEntryDebugState_roundTrip() throws {
        try roundTrip(LumiInlinePreviewFacade.HostCommand.requestEntryDebugState)
    }

    // MARK: - Request

    func test_request_roundTrip() throws {
        let request = LumiInlinePreviewFacade.HostRequest(
            requestID: 42,
            command: .startFrameStream(width: 1, height: 2, scale: 3)
        )
        try roundTrip(request)
    }

    // MARK: - Outbound envelope

    func test_outbound_response_roundTrip() throws {
        try roundTrip(LumiInlinePreviewFacade.HostOutbound.response(
            requestID: 7,
            payload: .init(success: true, message: "ok")
        ))
    }

    func test_outbound_event_frameProduced_roundTrip() throws {
        let frame = LumiInlinePreviewFacade.IOSurfaceFrame(
            surfaceID: 99, width: 320, height: 180, scale: 2, seq: 5
        )
        try roundTrip(LumiInlinePreviewFacade.HostOutbound.event(.frameProduced(frame)))
    }

    func test_outbound_event_error_roundTrip() throws {
        try roundTrip(LumiInlinePreviewFacade.HostOutbound.event(.error(message: "boom")))
    }

    func test_outbound_event_entryLoaded_success_roundTrip() throws {
        try roundTrip(LumiInlinePreviewFacade.HostOutbound.event(
            .entryLoaded(success: true, message: nil)
        ))
    }

    func test_outbound_event_entryLoaded_failure_roundTrip() throws {
        try roundTrip(LumiInlinePreviewFacade.HostOutbound.event(
            .entryLoaded(success: false, message: "dlopen failed: file not found")
        ))
    }

    func test_outbound_event_entryDebugState_roundTrip() throws {
        try roundTrip(LumiInlinePreviewFacade.HostOutbound.event(
            .entryDebugState("mouseDown=1;keyDown=1")
        ))
    }

    func test_outbound_event_cursorChanged_roundTrip() throws {
        for shape in LumiInlinePreviewFacade.PreviewCursorShape.allCases {
            try roundTrip(LumiInlinePreviewFacade.HostOutbound.event(.cursorChanged(shape)))
        }
    }

    // MARK: - Helpers

    private func roundTrip<T: Codable & Equatable>(_ value: T, file: StaticString = #file, line: UInt = #line) throws {
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(T.self, from: data)
        XCTAssertEqual(decoded, value, file: file, line: line)
    }
}
