import XCTest
@testable import LumiPreviewKit

final class HostMessagesTests: XCTestCase {

    // MARK: - HostCommand

    func test_command_ping_roundTrip() throws {
        try roundTrip(LumiPreviewFacade.HostCommand.ping)
    }

    func test_command_startFrameStream_roundTrip() throws {
        try roundTrip(LumiPreviewFacade.HostCommand.startFrameStream(
            width: 320, height: 180, scale: 2
        ))
    }

    func test_command_stopFrameStream_roundTrip() throws {
        try roundTrip(LumiPreviewFacade.HostCommand.stopFrameStream)
    }

    func test_command_setFrameStreamPolicy_roundTrip() throws {
        for policy in LumiPreviewFacade.FrameStreamPolicy.allCases {
            try roundTrip(LumiPreviewFacade.HostCommand.setFrameStreamPolicy(policy))
        }
    }

    func test_command_resizeSurface_roundTrip() throws {
        try roundTrip(LumiPreviewFacade.HostCommand.resizeSurface(
            width: 640, height: 480, scale: 1.5
        ))
    }

    func test_command_loadDylib_roundTrip() throws {
        try roundTrip(LumiPreviewFacade.HostCommand.loadDylib(
            path: "/tmp/preview.dylib",
            symbolName: "lumi_preview_make_nsview"
        ))
    }

    func test_command_unloadDylib_roundTrip() throws {
        try roundTrip(LumiPreviewFacade.HostCommand.unloadDylib)
    }

    func test_command_requestEntryDebugState_roundTrip() throws {
        try roundTrip(LumiPreviewFacade.HostCommand.requestEntryDebugState)
    }

    // MARK: - Request

    func test_request_roundTrip() throws {
        let request = LumiPreviewFacade.HostRequest(
            requestID: 42,
            command: .startFrameStream(width: 1, height: 2, scale: 3)
        )
        try roundTrip(request)
    }

    // MARK: - Outbound envelope

    func test_outbound_response_roundTrip() throws {
        try roundTrip(LumiPreviewFacade.HostOutbound.response(
            requestID: 7,
            payload: .init(success: true, message: "ok")
        ))
    }

    func test_outbound_event_frameProduced_roundTrip() throws {
        let frame = LumiPreviewFacade.IOSurfaceFrame(
            surfaceID: 99, width: 320, height: 180, scale: 2, seq: 5
        )
        try roundTrip(LumiPreviewFacade.HostOutbound.event(.frameProduced(frame)))
    }

    func test_outbound_event_error_roundTrip() throws {
        try roundTrip(LumiPreviewFacade.HostOutbound.event(.error(message: "boom")))
    }

    func test_outbound_event_entryLoaded_success_roundTrip() throws {
        try roundTrip(LumiPreviewFacade.HostOutbound.event(
            .entryLoaded(success: true, message: nil)
        ))
    }

    func test_outbound_event_entryLoaded_failure_roundTrip() throws {
        try roundTrip(LumiPreviewFacade.HostOutbound.event(
            .entryLoaded(success: false, message: "dlopen failed: file not found")
        ))
    }

    func test_outbound_event_entryDebugState_roundTrip() throws {
        try roundTrip(LumiPreviewFacade.HostOutbound.event(
            .entryDebugState("mouseDown=1;keyDown=1")
        ))
    }

    func test_outbound_event_cursorChanged_roundTrip() throws {
        for shape in LumiPreviewFacade.PreviewCursorShape.allCases {
            try roundTrip(LumiPreviewFacade.HostOutbound.event(.cursorChanged(shape)))
        }
    }

    // MARK: - Helpers

    private func roundTrip<T: Codable & Equatable>(_ value: T, file: StaticString = #filePath, line: UInt = #line) throws {
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(T.self, from: data)
        XCTAssertEqual(decoded, value, file: file, line: line)
    }
}
