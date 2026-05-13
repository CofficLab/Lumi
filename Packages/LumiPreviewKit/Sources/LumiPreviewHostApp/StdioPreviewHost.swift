import AppKit
import Foundation
import LumiPreviewKit

@MainActor
final class StdioPreviewHost {
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let renderer = PreviewRenderer()
    private var requestReader: HostRequestReader?

    func run() {
        let requestReader = HostRequestReader(host: self)
        self.requestReader = requestReader
        requestReader.start()
        NSApplication.shared.run()
    }

    func handleLine(_ line: String) -> Data {
        guard let data = line.data(using: .utf8) else {
            return encoded(LumiPreviewPackage.ErrorResponse(message: "Request is not valid UTF-8."))
        }

        do {
            let request = try decoder.decode(LumiPreviewPackage.RenderRequest.self, from: data)
            return encoded(handle(request))
        } catch {
            return encoded(LumiPreviewPackage.ErrorResponse(message: "Invalid request: \(error.localizedDescription)"))
        }
    }

    private func encoded<Response: Encodable>(_ response: Response) -> Data {
        do {
            return try encoder.encode(response)
        } catch {
            return Data(#"{"message":"Failed to encode response."}"#.utf8)
        }
    }

    private func handle(_ request: LumiPreviewPackage.RenderRequest) -> LumiPreviewPackage.RenderResponse {
        switch request.command {
        case .render:
            guard let discovery = request.discovery else {
                return LumiPreviewPackage.RenderResponse(success: false, message: "Render request is missing discovery.")
            }
            return renderer.render(discovery: discovery, configuration: request.configuration)
        case .refresh:
            return renderer.refresh()
        case .loadDylib:
            guard let dylibPath = request.dylibPath else {
                return LumiPreviewPackage.RenderResponse(success: false, message: "Dylib load request is missing dylibPath.")
            }
            return renderer.loadDylib(atPath: dylibPath, previewEntrySymbol: request.previewEntrySymbol)
        case .startLivePreview:
            return renderer.startLivePreview()
        case .updateLiveFrame:
            guard let liveFrame = request.liveFrame else {
                return LumiPreviewPackage.RenderResponse(success: false, message: "Update live frame request is missing liveFrame.")
            }
            return renderer.updateLiveFrame(
                x: liveFrame.x,
                y: liveFrame.y,
                width: liveFrame.width,
                height: liveFrame.height,
                scale: liveFrame.scale
            )
        case .showLivePreview:
            return renderer.showLivePreview()
        case .hideLivePreview:
            return renderer.hideLivePreview()
        case .reloadLivePreview:
            guard let dylibPath = request.dylibPath else {
                return LumiPreviewPackage.RenderResponse(success: false, message: "Reload live preview request is missing dylibPath.")
            }
            return renderer.reloadLivePreview(
                dylibPath: dylibPath,
                previewEntrySymbol: request.previewEntrySymbol
            )
        case .stopLivePreview:
            return renderer.stopLivePreview()
        }
    }
}
