import Foundation
import LumiPreviewKit
import Testing
@testable import LumiPreviewKit

@Suite("HotRenderResponse")
struct HotRenderResponseTests {
    @Test("wraps legacy render responses")
    func wrapsLegacyRenderResponse() {
        let legacy = LumiPreviewPackage.RenderResponse(
            success: true,
            previewID: "preview-1",
            message: "ok",
            previewImagePNGBase64: "png",
            diagnostics: "diagnostic",
            isFallback: true,
            livePreviewEnabled: true,
            liveWindowNumber: 42
        )

        let response = LumiPreviewPackage.HotRenderResponse(legacy)

        #expect(response.success)
        #expect(response.previewID == "preview-1")
        #expect(response.message == "ok")
        #expect(response.previewImagePNGBase64 == "png")
        #expect(response.diagnostics == "diagnostic")
        #expect(response.isFallback)
        #expect(response.livePreviewEnabled)
        #expect(response.liveWindowNumber == 42)
        #expect(response.preferredTransport == .base64)
    }

    @Test("prefers shared memory over file and base64 transports")
    func preferredTransportPriority() {
        #expect(LumiPreviewPackage.HotRenderResponse(success: true).preferredTransport == .none)
        #expect(LumiPreviewPackage.HotRenderResponse(success: true, previewImagePNGBase64: "png").preferredTransport == .base64)
        #expect(LumiPreviewPackage.HotRenderResponse(success: true, previewImagePNGBase64: "png", imageFilePath: "/tmp/frame.png").preferredTransport == .file)
        #expect(LumiPreviewPackage.HotRenderResponse(success: true, previewImagePNGBase64: "png", imageFilePath: "/tmp/frame.png", sharedMemoryTag: "tag").preferredTransport == .sharedMemory)
    }

    @Test("decodes new host fields while old fields remain optional")
    func decodesNewHostFields() throws {
        let data = Data("""
        {
          "success": true,
          "previewID": "preview-2",
          "imageFilePath": "/tmp/LumiPreviewKit/frame.png",
          "sharedMemoryTag": "frame-123",
          "frameSize": { "width": 320, "height": 180 },
          "bytesPerRow": 1280
        }
        """.utf8)

        let response = try JSONDecoder().decode(LumiPreviewPackage.HotRenderResponse.self, from: data)

        #expect(response.success)
        #expect(response.previewID == "preview-2")
        #expect(response.imageFilePath == "/tmp/LumiPreviewKit/frame.png")
        #expect(response.sharedMemoryTag == "frame-123")
        #expect(response.frameSize == .init(width: 320, height: 180))
        #expect(response.frameWidth == 320)
        #expect(response.frameHeight == 180)
        #expect(response.bytesPerRow == 1280)
        #expect(response.isFallback == false)
        #expect(response.livePreviewEnabled == false)
    }
}
