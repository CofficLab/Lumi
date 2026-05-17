import Foundation

public extension LumiPreviewFacade {
    /// 渲染帧的尺寸描述。
    struct HotFrameSize: Codable, Sendable, Equatable {
        public let width: Int
        public let height: Int

        public init(width: Int, height: Int) {
            self.width = width
            self.height = height
        }
    }

    /// 渲染帧的传输方式。
    enum HotFrameTransport: String, Codable, Sendable, Equatable {
        /// 通过 Base64 编码的 PNG 内嵌在 JSON 中。
        case base64
        /// 通过文件系统路径引用 PNG 文件。
        case file
        /// 通过共享内存（mmap 或 POSIX shm）传输像素数据。
        case sharedMemory
        /// 通过 IOSurface 跨进程传输。
        case surface
        /// 无帧数据。
        case none
    }

    /// Hot 预览管线使用的响应模型。
    ///
    /// 保持与 `RenderResponse` 的兼容性，同时支持文件路径和共享内存等
    /// 新的帧传输方式。包含帧数据、诊断信息、Live 预览状态等。
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

        /// 请求是否成功。
        public let success: Bool
        /// 相关预览标识符。
        public let previewID: String?
        /// 可展示或记录的响应消息。
        public let message: String?
        /// 宿主进程当前预览画面的 PNG 数据，Base64 编码。
        public let previewImagePNGBase64: String?
        /// 宿主进程当前预览画面的 PNG 文件路径。
        public let imageFilePath: String?
        /// 共享内存帧的唯一标识标签。
        public let sharedMemoryTag: String?
        /// 帧尺寸。
        public let frameSize: HotFrameSize?
        /// 帧宽度（便捷访问 `frameSize?.width`）。
        public var frameWidth: Int? { frameSize?.width }
        /// 帧高度（便捷访问 `frameSize?.height`）。
        public var frameHeight: Int? { frameSize?.height }
        /// 帧每行字节数。
        public let bytesPerRow: Int?
        /// 结构化诊断信息。
        public let diagnostics: String?
        /// 本次响应是否来自降级预览入口。
        public let isFallback: Bool
        /// 宿主进程是否支持 Live 预览模式。
        public let livePreviewEnabled: Bool
        /// Live 预览窗口编号。
        public let liveWindowNumber: Int?

        /// 推荐的帧传输方式，按共享内存 > 文件 > Base64 优先级选择。
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

        /// 从旧版 `RenderResponse` 创建 `HotRenderResponse`。
        public init(_ response: LumiPreviewFacade.RenderResponse) {
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
