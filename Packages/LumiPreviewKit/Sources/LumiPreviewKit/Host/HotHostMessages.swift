import Foundation

public extension LumiPreviewFacade {
    enum HotHostCommand: String, Codable, Sendable {
        case render
        case refresh
        case captureFrame
        case loadDylib
        case interposeDylib
        case startLivePreview
        case updateLiveFrame
        case showLivePreview
        case hideLivePreview
        case reloadLivePreview
        case stopLivePreview
    }

    struct HotHostRequest: Codable, Sendable {
        public let command: HotHostCommand
        public let discovery: LumiPreviewFacade.PreviewDiscovery?
        public let dylibPath: String?
        public let previewEntrySymbol: String?
        public let configuration: LumiPreviewFacade.PreviewRenderConfiguration
        public let liveFrame: LumiPreviewFacade.LiveFrameRequest?
        public let captureFrame: LumiPreviewFacade.CaptureFrameRequest?

        public init(
            command: HotHostCommand,
            discovery: LumiPreviewFacade.PreviewDiscovery? = nil,
            dylibPath: String? = nil,
            previewEntrySymbol: String? = nil,
            configuration: LumiPreviewFacade.PreviewRenderConfiguration = .empty,
            liveFrame: LumiPreviewFacade.LiveFrameRequest? = nil,
            captureFrame: LumiPreviewFacade.CaptureFrameRequest? = nil
        ) {
            self.command = command
            self.discovery = discovery
            self.dylibPath = dylibPath
            self.previewEntrySymbol = previewEntrySymbol
            self.configuration = configuration
            self.liveFrame = liveFrame
            self.captureFrame = captureFrame
        }
    }
}
