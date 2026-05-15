import Foundation

public extension LumiPreviewPackage {
    struct HotFrameSize: Codable, Sendable, Equatable {
        public let width: Int
        public let height: Int

        public init(width: Int, height: Int) {
            self.width = width
            self.height = height
        }
    }

    /// Transport used for a rendered preview frame.
    enum HotFrameTransport: String, Codable, Sendable, Equatable {
        case base64
        case file
        case sharedMemory
        case surface
        case none
    }

    /// Response model used by the hot preview pipeline.
    ///
    /// It keeps compatibility with `LumiPreviewKit.RenderResponse` while allowing
    /// new hosts to return file or shared-memory frame metadata.
    struct HotRenderResponse: Codable, Sendable, Equatable {
        private enum CodingKeys: String, CodingKey {
            case success
            case previewID
            case message
            case previewImagePNGBase64
            case imageFilePath
            case sharedMemoryTag
            case frameSize
            case frameWidth
            case frameHeight
            case bytesPerRow
            case diagnostics
            case isFallback
            case livePreviewEnabled
            case liveWindowNumber
        }

        public let success: Bool
        public let previewID: String?
        public let message: String?
        public let previewImagePNGBase64: String?
        public let imageFilePath: String?
        public let sharedMemoryTag: String?
        public let frameSize: HotFrameSize?
        public var frameWidth: Int? { frameSize?.width }
        public var frameHeight: Int? { frameSize?.height }
        public let bytesPerRow: Int?
        public let diagnostics: String?
        public let isFallback: Bool
        public let livePreviewEnabled: Bool
        public let liveWindowNumber: Int?

        public var preferredTransport: HotFrameTransport {
            if sharedMemoryTag != nil {
                return .sharedMemory
            }
            if imageFilePath != nil {
                return .file
            }
            if previewImagePNGBase64 != nil {
                return .base64
            }
            return .none
        }

        public init(
            success: Bool,
            previewID: String? = nil,
            message: String? = nil,
            previewImagePNGBase64: String? = nil,
            imageFilePath: String? = nil,
            sharedMemoryTag: String? = nil,
            frameSize: HotFrameSize? = nil,
            frameWidth: Int? = nil,
            frameHeight: Int? = nil,
            bytesPerRow: Int? = nil,
            diagnostics: String? = nil,
            isFallback: Bool = false,
            livePreviewEnabled: Bool = false,
            liveWindowNumber: Int? = nil
        ) {
            self.success = success
            self.previewID = previewID
            self.message = message
            self.previewImagePNGBase64 = previewImagePNGBase64
            self.imageFilePath = imageFilePath
            self.sharedMemoryTag = sharedMemoryTag
            self.frameSize = frameSize ?? {
                guard let frameWidth, let frameHeight else { return nil }
                return HotFrameSize(width: frameWidth, height: frameHeight)
            }()
            self.bytesPerRow = bytesPerRow
            self.diagnostics = diagnostics
            self.isFallback = isFallback
            self.livePreviewEnabled = livePreviewEnabled
            self.liveWindowNumber = liveWindowNumber
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.success = try container.decode(Bool.self, forKey: .success)
            self.previewID = try container.decodeIfPresent(String.self, forKey: .previewID)
            self.message = try container.decodeIfPresent(String.self, forKey: .message)
            self.previewImagePNGBase64 = try container.decodeIfPresent(String.self, forKey: .previewImagePNGBase64)
            self.imageFilePath = try container.decodeIfPresent(String.self, forKey: .imageFilePath)
            self.sharedMemoryTag = try container.decodeIfPresent(String.self, forKey: .sharedMemoryTag)
            if let decodedFrameSize = try container.decodeIfPresent(HotFrameSize.self, forKey: .frameSize) {
                self.frameSize = decodedFrameSize
            } else if let frameWidth = try container.decodeIfPresent(Int.self, forKey: .frameWidth),
                      let frameHeight = try container.decodeIfPresent(Int.self, forKey: .frameHeight) {
                self.frameSize = HotFrameSize(width: frameWidth, height: frameHeight)
            } else {
                self.frameSize = nil
            }
            self.bytesPerRow = try container.decodeIfPresent(Int.self, forKey: .bytesPerRow)
            self.diagnostics = try container.decodeIfPresent(String.self, forKey: .diagnostics)
            self.isFallback = try container.decodeIfPresent(Bool.self, forKey: .isFallback) ?? false
            self.livePreviewEnabled = try container.decodeIfPresent(Bool.self, forKey: .livePreviewEnabled) ?? false
            self.liveWindowNumber = try container.decodeIfPresent(Int.self, forKey: .liveWindowNumber)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(success, forKey: .success)
            try container.encodeIfPresent(previewID, forKey: .previewID)
            try container.encodeIfPresent(message, forKey: .message)
            try container.encodeIfPresent(previewImagePNGBase64, forKey: .previewImagePNGBase64)
            try container.encodeIfPresent(imageFilePath, forKey: .imageFilePath)
            try container.encodeIfPresent(sharedMemoryTag, forKey: .sharedMemoryTag)
            try container.encodeIfPresent(frameSize, forKey: .frameSize)
            try container.encodeIfPresent(frameWidth, forKey: .frameWidth)
            try container.encodeIfPresent(frameHeight, forKey: .frameHeight)
            try container.encodeIfPresent(bytesPerRow, forKey: .bytesPerRow)
            try container.encodeIfPresent(diagnostics, forKey: .diagnostics)
            try container.encode(isFallback, forKey: .isFallback)
            try container.encode(livePreviewEnabled, forKey: .livePreviewEnabled)
            try container.encodeIfPresent(liveWindowNumber, forKey: .liveWindowNumber)
        }

        public init(_ response: LumiPreviewPackage.RenderResponse) {
            self.init(
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
    }
}
