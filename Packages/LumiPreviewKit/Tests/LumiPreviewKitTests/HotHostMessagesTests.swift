import Foundation
import LumiPreviewKit
import Testing
@testable import LumiPreviewKit

@Suite("HotHostMessages")
struct HotHostMessagesTests {
    @Test("encodes and decodes interpose request")
    func encodesAndDecodesInterposeRequest() throws {
        let request = LumiPreviewPackage.HotHostRequest(
            command: .interposeDylib,
            dylibPath: "/tmp/PreviewEntry.dylib",
            previewEntrySymbol: "lumi_preview_entry"
        )

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(LumiPreviewPackage.HotHostRequest.self, from: data)

        #expect(decoded.command == .interposeDylib)
        #expect(decoded.dylibPath == "/tmp/PreviewEntry.dylib")
        #expect(decoded.previewEntrySymbol == "lumi_preview_entry")
    }

    @Test("preserves live frame payload")
    func preservesLiveFramePayload() throws {
        let request = LumiPreviewPackage.HotHostRequest(
            command: .updateLiveFrame,
            liveFrame: LumiPreviewPackage.LiveFrameRequest(
                x: 10,
                y: 20,
                width: 320,
                height: 180,
                scale: 2
            )
        )

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(LumiPreviewPackage.HotHostRequest.self, from: data)

        #expect(decoded.command == .updateLiveFrame)
        #expect(decoded.liveFrame == request.liveFrame)
    }
}
