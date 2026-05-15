import AppKit
import Foundation
import LumiPreviewKit

@MainActor
final class HotStdioPreviewHost {
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let renderer = HotPreviewRenderer()
    private let frameStore = LumiPreviewPackage.FrameFileStore()
    private let sharedMemoryFrameChannel = LumiPreviewPackage.SharedMemoryFrameChannel()
    private var requestReader: HotHostRequestReader?

    func run() {
        let requestReader = HotHostRequestReader(host: self)
        self.requestReader = requestReader
        requestReader.start()
        NSApplication.shared.run()
    }

    func handleLine(_ line: String) async -> Data {
        guard let data = line.data(using: .utf8) else {
            return encoded(LumiPreviewPackage.ErrorResponse(message: "Request is not valid UTF-8."))
        }

        do {
            let request = try decoder.decode(LumiPreviewPackage.HotHostRequest.self, from: data)
            return encoded(await handle(request))
        } catch {
            return encoded(LumiPreviewPackage.ErrorResponse(message: "Invalid request: \(error.localizedDescription)"))
        }
    }

    private func handle(_ request: LumiPreviewPackage.HotHostRequest) async -> LumiPreviewPackage.HotRenderResponse {
        switch request.command {
        case .render:
            guard let discovery = request.discovery else {
                return LumiPreviewPackage.HotRenderResponse(success: false, message: "Render request is missing discovery.")
            }
            return makeHotResponse(
                from: renderer.render(discovery: discovery, configuration: request.configuration)
            )
        case .refresh:
            return makeHotResponse(from: renderer.refresh())
        case .captureFrame:
            return makeHotResponse(from: renderer.captureFrame(
                includeImageFallback: request.captureFrame?.includeImageFallback ?? true
            ))
        case .loadDylib:
            guard let dylibPath = request.dylibPath else {
                return LumiPreviewPackage.HotRenderResponse(success: false, message: "Dylib load request is missing dylibPath.")
            }
            let response = renderer.loadDylib(
                atPath: dylibPath,
                previewEntrySymbol: request.previewEntrySymbol
            )
            return makeHotResponse(from: response)
        case .interposeDylib:
            guard let dylibPath = request.dylibPath else {
                return LumiPreviewPackage.HotRenderResponse(success: false, message: "Interpose request is missing dylibPath.")
            }
            let response = await renderer.interposeDylib(
                atPath: dylibPath,
                previewEntrySymbol: request.previewEntrySymbol
            )
            return makeHotResponse(from: response)
        case .startLivePreview:
            return makeHotResponse(from: renderer.startLivePreview())
        case .updateLiveFrame:
            guard let liveFrame = request.liveFrame else {
                return LumiPreviewPackage.HotRenderResponse(success: false, message: "Update live frame request is missing liveFrame.")
            }
            return makeHotResponse(from: renderer.updateLiveFrame(
                x: liveFrame.x,
                y: liveFrame.y,
                width: liveFrame.width,
                height: liveFrame.height,
                scale: liveFrame.scale
            ))
        case .showLivePreview:
            return makeHotResponse(from: renderer.showLivePreview())
        case .hideLivePreview:
            return makeHotResponse(from: renderer.hideLivePreview())
        case .reloadLivePreview:
            guard let dylibPath = request.dylibPath else {
                return LumiPreviewPackage.HotRenderResponse(success: false, message: "Reload live preview request is missing dylibPath.")
            }
            return makeHotResponse(from: renderer.reloadLivePreview(
                dylibPath: dylibPath,
                previewEntrySymbol: request.previewEntrySymbol
            ))
        case .stopLivePreview:
            return makeHotResponse(from: renderer.stopLivePreview())
        }
    }

    private func makeHotResponse(
        from response: LumiPreviewPackage.RenderResponse
    ) -> LumiPreviewPackage.HotRenderResponse {
        let sharedFrame = renderer.snapshotToSharedMemory(using: sharedMemoryFrameChannel)
        if let sharedFrame {
            return LumiPreviewPackage.HotRenderResponse(
                success: response.success,
                previewID: response.previewID,
                message: response.message,
                previewImagePNGBase64: response.previewImagePNGBase64,
                sharedMemoryTag: sharedFrame.tag,
                frameSize: .init(width: sharedFrame.width, height: sharedFrame.height),
                bytesPerRow: sharedFrame.bytesPerRow,
                diagnostics: response.diagnostics,
                isFallback: response.isFallback,
                livePreviewEnabled: response.livePreviewEnabled,
                liveWindowNumber: response.liveWindowNumber
            )
        }

        if let base64 = response.previewImagePNGBase64,
           let fileURL = try? frameStore.writePNG(base64EncodedPNG: base64, previewID: response.previewID) {
            return LumiPreviewPackage.HotRenderResponse(
                success: response.success,
                previewID: response.previewID,
                message: response.message,
                imageFilePath: fileURL.path,
                diagnostics: response.diagnostics,
                isFallback: response.isFallback,
                livePreviewEnabled: response.livePreviewEnabled,
                liveWindowNumber: response.liveWindowNumber
            )
        }

        return LumiPreviewPackage.HotRenderResponse(
            success: response.success,
            previewID: response.previewID,
            message: response.message,
            previewImagePNGBase64: response.previewImagePNGBase64,
            diagnostics: response.diagnostics,
            isFallback: response.isFallback,
            livePreviewEnabled: response.livePreviewEnabled,
            liveWindowNumber: response.liveWindowNumber
        )
    }

    private func encoded<Response: Encodable>(_ response: Response) -> Data {
        do {
            return try encoder.encode(response)
        } catch {
            return Data(#"{"message":"Failed to encode response."}"#.utf8)
        }
    }
}
