import Foundation
import LumiPreviewKit
import Testing
@testable import LumiPreviewKit

@Suite("PreviewHostMessages")
struct PreviewHostMessagesTests {
    @Test("2.1 RenderRequest round-trips through JSON")
    func renderRequestRoundTrip() throws {
        let discovery = PreviewDiscoveryFixtures.makeDiscovery()
        let request = LumiPreviewFacade.RenderRequest(
            command: .render,
            discovery: discovery,
            dylibPath: "/tmp/PreviewEntry.dylib",
            previewEntrySymbol: LumiPreviewFacade.PreviewEntryBuilder.symbolName,
            configuration: .empty,
            liveFrame: LumiPreviewFacade.LiveFrameRequest(x: 1, y: 2, width: 320, height: 180, scale: 2),
            captureFrame: LumiPreviewFacade.CaptureFrameRequest(includeImageFallback: false)
        )

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(LumiPreviewFacade.RenderRequest.self, from: data)

        #expect(decoded.command == .render)
        #expect(decoded.discovery?.id == discovery.id)
        #expect(decoded.dylibPath == request.dylibPath)
        #expect(decoded.previewEntrySymbol == request.previewEntrySymbol)
        #expect(decoded.liveFrame?.scale == 2)
        #expect(decoded.captureFrame?.includeImageFallback == false)
    }

    @Test("2.2 legacy JSON without liveFrame and captureFrame decodes")
    func legacyRenderRequestDecodes() throws {
        let data = Data("""
        {
          "command": "refresh",
          "dylibPath": "/tmp/PreviewEntry.dylib",
          "configuration": { "environmentInjections": [] }
        }
        """.utf8)

        let decoded = try JSONDecoder().decode(LumiPreviewFacade.RenderRequest.self, from: data)
        #expect(decoded.command == .refresh)
        #expect(decoded.liveFrame == nil)
        #expect(decoded.captureFrame == nil)
    }

    @Test("2.3 LiveFrameRequest and CaptureFrameRequest use defaults")
    func requestDefaults() throws {
        let liveData = Data("""
        { "x": 0, "y": 0, "width": 10, "height": 10 }
        """.utf8)
        let live = try JSONDecoder().decode(LumiPreviewFacade.LiveFrameRequest.self, from: liveData)
        #expect(live.scale == 1)

        let captureData = Data("{}".utf8)
        let capture = try JSONDecoder().decode(LumiPreviewFacade.CaptureFrameRequest.self, from: captureData)
        #expect(capture.includeImageFallback == true)
    }

    @Test("2.4 PreviewSurfaceTransport reports kind metadata")
    func surfaceTransportMetadata() {
        let shared = LumiPreviewFacade.PreviewSurfaceTransport.globalIOSurfaceID(99)
        let unsupported = LumiPreviewFacade.PreviewSurfaceTransport.unsupported(kind: "file")

        #expect(shared.kind == "globalIOSurfaceID")
        #expect(unsupported.kind == "file")
        #expect(!shared.isSecureCrossProcessTransport)
        #expect(!unsupported.isSecureCrossProcessTransport)
    }

    @Test("2.5 PreviewSurfaceFrame encodes global IOSurface transport")
    func previewSurfaceFrameEncoding() throws {
        let sharedFrame = LumiPreviewFacade.PreviewSurfaceFrame(
            surfaceID: 99,
            width: 320,
            height: 180,
            scale: 2,
            pixelFormat: "BGRA",
            bytesPerRow: 1280
        )
        #expect(sharedFrame.globalIOSurfaceID == 99)
        #expect(sharedFrame.transportKind == "globalIOSurfaceID")

        let unsupportedFrame = LumiPreviewFacade.PreviewSurfaceFrame(
            transport: .unsupported(kind: "file"),
            width: 100,
            height: 50,
            scale: 1,
            pixelFormat: "BGRA",
            bytesPerRow: 400
        )
        let data = try JSONEncoder().encode(unsupportedFrame)
        let decoded = try JSONDecoder().decode(LumiPreviewFacade.PreviewSurfaceFrame.self, from: data)
        #expect(decoded.transportKind == "file")
        #expect(decoded.globalIOSurfaceID == nil)
    }
}
