import Foundation

public extension LumiPreviewPackage {
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
        public let discovery: LumiPreviewPackage.PreviewDiscovery?
        public let dylibPath: String?
        public let previewEntrySymbol: String?
        public let configuration: LumiPreviewPackage.PreviewRenderConfiguration
        public let liveFrame: LumiPreviewPackage.LiveFrameRequest?
        public let captureFrame: LumiPreviewPackage.CaptureFrameRequest?

        public init(
            command: HotHostCommand,
            discovery: LumiPreviewPackage.PreviewDiscovery? = nil,
            dylibPath: String? = nil,
            previewEntrySymbol: String? = nil,
            configuration: LumiPreviewPackage.PreviewRenderConfiguration = .empty,
            liveFrame: LumiPreviewPackage.LiveFrameRequest? = nil,
            captureFrame: LumiPreviewPackage.CaptureFrameRequest? = nil
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
