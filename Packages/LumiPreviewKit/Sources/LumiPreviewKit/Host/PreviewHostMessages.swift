import Foundation

public extension LumiPreviewPackage {
/// 预览宿主支持的命令类型。
enum PreviewHostCommand: String, Codable, Sendable {
    /// 根据源码发现结果渲染一个预览。
    case render

    /// 刷新当前预览。
    case refresh

    /// 捕获当前预览画面，不重新编译或重载预览入口。
    case captureFrame

    /// 加载已编译并签名的预览 dylib。
    case loadDylib

    /// 启动 Live 预览：加载当前 preview dylib，创建真实 NSHostingView/NSView。
    case startLivePreview

    /// 更新 Live 预览窗口的屏幕坐标和尺寸。
    case updateLiveFrame

    /// 显示 Live 预览窗口。
    case showLivePreview

    /// 隐藏 Live 预览窗口。
    case hideLivePreview

    /// 重新加载 Live 预览（加载新 dylib，替换 root view）。
    case reloadLivePreview

    /// 停止 Live 预览并关闭 live window。
    case stopLivePreview
}

/// 发送给预览宿主进程的请求消息。
struct RenderRequest: Codable, Sendable {
    /// 请求命令。
    public let command: PreviewHostCommand

    /// 渲染命令使用的预览发现结果。
    public let discovery: PreviewDiscovery?

    /// 需要动态加载的 dylib 路径。
    public let dylibPath: String?

    /// dylib 中可选的预览入口符号名。
    public let previewEntrySymbol: String?

    /// 本次渲染使用的配置。
    public let configuration: PreviewRenderConfiguration

    /// Live 预览窗口的屏幕坐标、尺寸和 scale（用于 updateLiveFrame）。
    /// JSON 格式：{"x": 100, "y": 200, "width": 320, "height": 180, "scale": 2}
    public let liveFrame: LiveFrameRequest?

    /// 捕获当前帧时使用的选项。
    public let captureFrame: CaptureFrameRequest?

    /// 创建一个宿主请求消息。
    ///
    /// - Parameters:
    ///   - command: 请求命令。
    ///   - discovery: 渲染用的预览发现结果。
    ///   - dylibPath: 需要动态加载的 dylib 路径。
    ///   - previewEntrySymbol: dylib 中的预览入口符号名。
    ///   - configuration: 本次渲染使用的配置。
    ///   - liveFrame: Live 预览窗口的屏幕坐标和尺寸。
    ///   - captureFrame: 捕获当前帧时使用的选项。
    public init(
        command: PreviewHostCommand,
        discovery: PreviewDiscovery? = nil,
        dylibPath: String? = nil,
        previewEntrySymbol: String? = nil,
        configuration: PreviewRenderConfiguration = .empty,
        liveFrame: LiveFrameRequest? = nil,
        captureFrame: CaptureFrameRequest? = nil
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

/// Live 预览窗口的屏幕坐标和尺寸请求。
///
/// 使用 AppKit 坐标系（y 轴原点在屏幕左下角）。
struct LiveFrameRequest: Codable, Sendable, Equatable {
    /// 屏幕坐标 x（AppKit 坐标系，左下角原点）。
    public let x: Double
    /// 屏幕坐标 y（AppKit 坐标系，左下角原点）。
    public let y: Double
    /// 窗口宽度。
    public let width: Double
    /// 窗口高度。
    public let height: Double
    /// 当前屏幕 scale factor，用于像素对齐。
    public let scale: Double

    /// 创建一个 Live Frame 请求。
    ///
    /// - Parameters:
    ///   - x: 屏幕坐标 x。
    ///   - y: 屏幕坐标 y。
    ///   - width: 窗口宽度。
    ///   - height: 窗口高度。
    ///   - scale: 当前屏幕 scale factor。
    public init(x: Double, y: Double, width: Double, height: Double, scale: Double = 1) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.scale = scale
    }

    private enum CodingKeys: String, CodingKey {
        case x
        case y
        case width
        case height
        case scale
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.x = try container.decode(Double.self, forKey: .x)
        self.y = try container.decode(Double.self, forKey: .y)
        self.width = try container.decode(Double.self, forKey: .width)
        self.height = try container.decode(Double.self, forKey: .height)
        self.scale = try container.decodeIfPresent(Double.self, forKey: .scale) ?? 1
    }
}

/// 捕获预览帧时的请求选项。
struct CaptureFrameRequest: Codable, Sendable, Equatable {
    /// 是否随 surface 元数据一起返回 PNG 兜底图。
    public let includeImageFallback: Bool

    /// 创建一个捕获请求。
    ///
    /// - Parameter includeImageFallback: 是否返回 PNG 兜底图。
    public init(includeImageFallback: Bool = true) {
        self.includeImageFallback = includeImageFallback
    }

    private enum CodingKeys: String, CodingKey {
        case includeImageFallback
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.includeImageFallback = try container.decodeIfPresent(Bool.self, forKey: .includeImageFallback) ?? true
    }
}

/// 预览宿主进程返回的成功或失败响应。
struct RenderResponse: Codable, Sendable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case success
        case previewID
        case message
        case previewImagePNGBase64
        case surfaceFrame
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

    /// 宿主进程当前预览画面的跨进程 IOSurface 元数据。
    public let surfaceFrame: PreviewSurfaceFrame?

    /// 可展示给用户的结构化诊断信息，例如真实 view entry 编译失败日志。
    public let diagnostics: String?

    /// 本次响应是否来自降级预览入口。
    public let isFallback: Bool

    /// 宿主进程是否支持 Live 预览模式（成功加载了真实 NSView entry）。
    public let livePreviewEnabled: Bool

    /// Live 预览窗口在宿主进程中的窗口编号，用于跨进程窗口层级协调。
    public let liveWindowNumber: Int?

    /// 创建一个宿主响应。
    ///
    /// - Parameters:
    ///   - success: 请求是否成功。
    ///   - previewID: 相关预览标识符。
    ///   - message: 可展示或记录的响应消息。
    ///   - previewImagePNGBase64: 宿主进程当前预览画面的 PNG 数据，Base64 编码。
    ///   - surfaceFrame: 宿主进程当前预览画面的跨进程 IOSurface 元数据。
    ///   - diagnostics: 可展示给用户的结构化诊断信息。
    ///   - isFallback: 本次响应是否来自降级预览入口。
    ///   - livePreviewEnabled: 宿主进程是否支持 Live 预览模式。
    ///   - liveWindowNumber: Live 预览窗口编号。
    public init(
        success: Bool,
        previewID: String? = nil,
        message: String? = nil,
        previewImagePNGBase64: String? = nil,
        surfaceFrame: PreviewSurfaceFrame? = nil,
        diagnostics: String? = nil,
        isFallback: Bool = false,
        livePreviewEnabled: Bool = false,
        liveWindowNumber: Int? = nil
    ) {
        self.success = success
        self.previewID = previewID
        self.message = message
        self.previewImagePNGBase64 = previewImagePNGBase64
        self.surfaceFrame = surfaceFrame
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
        self.surfaceFrame = try container.decodeIfPresent(PreviewSurfaceFrame.self, forKey: .surfaceFrame)
        self.diagnostics = try container.decodeIfPresent(String.self, forKey: .diagnostics)
        self.isFallback = try container.decodeIfPresent(Bool.self, forKey: .isFallback) ?? false
        self.livePreviewEnabled = try container.decodeIfPresent(Bool.self, forKey: .livePreviewEnabled) ?? false
        self.liveWindowNumber = try container.decodeIfPresent(Int.self, forKey: .liveWindowNumber)
    }
}

/// 跨进程预览帧的 IOSurface 描述。
struct PreviewSurfaceFrame: Codable, Sendable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case transport
        case surfaceID
        case width
        case height
        case scale
        case pixelFormat
        case bytesPerRow
    }

    public let transport: PreviewSurfaceTransport
    public let width: Int
    public let height: Int
    public let scale: Double
    public let pixelFormat: String
    public let bytesPerRow: Int

    public var globalIOSurfaceID: UInt32? {
        if case let .globalIOSurfaceID(surfaceID) = transport {
            return surfaceID
        }
        return nil
    }

    public var transportKind: String {
        transport.kind
    }

    public init(
        surfaceID: UInt32,
        width: Int,
        height: Int,
        scale: Double,
        pixelFormat: String,
        bytesPerRow: Int
    ) {
        self.init(
            transport: .globalIOSurfaceID(surfaceID),
            width: width,
            height: height,
            scale: scale,
            pixelFormat: pixelFormat,
            bytesPerRow: bytesPerRow
        )
    }

    public init(
        transport: PreviewSurfaceTransport,
        width: Int,
        height: Int,
        scale: Double,
        pixelFormat: String,
        bytesPerRow: Int
    ) {
        self.transport = transport
        self.width = width
        self.height = height
        self.scale = scale
        self.pixelFormat = pixelFormat
        self.bytesPerRow = bytesPerRow
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let transport = try container.decodeIfPresent(PreviewSurfaceTransport.self, forKey: .transport) {
            self.transport = transport
        } else {
            self.transport = .globalIOSurfaceID(try container.decode(UInt32.self, forKey: .surfaceID))
        }
        self.width = try container.decode(Int.self, forKey: .width)
        self.height = try container.decode(Int.self, forKey: .height)
        self.scale = try container.decode(Double.self, forKey: .scale)
        self.pixelFormat = try container.decode(String.self, forKey: .pixelFormat)
        self.bytesPerRow = try container.decode(Int.self, forKey: .bytesPerRow)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(transport, forKey: .transport)
        try container.encodeIfPresent(globalIOSurfaceID, forKey: .surfaceID)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode(scale, forKey: .scale)
        try container.encode(pixelFormat, forKey: .pixelFormat)
        try container.encode(bytesPerRow, forKey: .bytesPerRow)
    }
}

/// 跨进程预览帧的像素传输方式。
enum PreviewSurfaceTransport: Codable, Sendable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case surfaceID
    }

    case globalIOSurfaceID(UInt32)
    case unsupported(kind: String)

    public var kind: String {
        switch self {
        case .globalIOSurfaceID:
            "globalIOSurfaceID"
        case let .unsupported(kind):
            kind
        }
    }

    public var isSecureCrossProcessTransport: Bool {
        switch self {
        case .globalIOSurfaceID:
            false
        case .unsupported:
            false
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        switch kind {
        case "globalIOSurfaceID":
            self = .globalIOSurfaceID(try container.decode(UInt32.self, forKey: .surfaceID))
        default:
            self = .unsupported(kind: kind)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .globalIOSurfaceID(surfaceID):
            try container.encode(kind, forKey: .kind)
            try container.encode(surfaceID, forKey: .surfaceID)
        case .unsupported:
            try container.encode(kind, forKey: .kind)
        }
    }
}

/// 动态预览入口返回给宿主进程的描述信息。
///
/// 这是 `dlopen` 预览入口的稳定 ABI 载荷：入口函数返回 UTF-8 JSON 字符串，
/// 宿主进程解码后用这些字段构建预览 surface。
struct PreviewEntryDescriptor: Codable, Sendable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case title
        case subtitle
        case body
        case diagnostics
        case isFallback
    }

    /// 预览标题。
    public let title: String

    /// 可选副标题，通常是 SwiftUI View 类型名。
    public let subtitle: String?

    /// 可选正文，通常用于展示生成入口或诊断摘要。
    public let body: String?

    /// 可选诊断信息，通常是真实 view entry 构建失败日志。
    public let diagnostics: String?

    /// 该描述是否来自真实 view entry 失败后的降级入口。
    public let isFallback: Bool

    /// 创建动态预览入口描述。
    ///
    /// - Parameters:
    ///   - title: 预览标题。
    ///   - subtitle: 可选副标题。
    ///   - body: 可选正文。
    ///   - diagnostics: 可选诊断信息。
    ///   - isFallback: 该描述是否来自降级入口。
    public init(
        title: String,
        subtitle: String? = nil,
        body: String? = nil,
        diagnostics: String? = nil,
        isFallback: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.diagnostics = diagnostics
        self.isFallback = isFallback
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.title = try container.decode(String.self, forKey: .title)
        self.subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        self.body = try container.decodeIfPresent(String.self, forKey: .body)
        self.diagnostics = try container.decodeIfPresent(String.self, forKey: .diagnostics)
        self.isFallback = try container.decodeIfPresent(Bool.self, forKey: .isFallback) ?? false
    }
}

/// 预览宿主进程返回的错误响应。
struct ErrorResponse: Codable, Sendable, Equatable {
    /// 错误描述。
    public let message: String

    /// 创建一个错误响应。
    ///
    /// - Parameter message: 错误描述。
    public init(message: String) {
        self.message = message
    }
}

}
