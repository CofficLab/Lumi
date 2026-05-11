import Foundation

/// 预览宿主支持的命令类型。
public enum PreviewHostCommand: String, Codable, Sendable {
    /// 根据源码发现结果渲染一个预览。
    case render

    /// 刷新当前预览。
    case refresh

    /// 加载已编译并签名的预览 dylib。
    case loadDylib
}

/// 发送给预览宿主进程的请求消息。
public struct RenderRequest: Codable, Sendable {
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

    /// 创建一个宿主请求消息。
    ///
    /// - Parameters:
    ///   - command: 请求命令。
    ///   - discovery: 渲染用的预览发现结果。
    ///   - dylibPath: 需要动态加载的 dylib 路径。
    ///   - previewEntrySymbol: dylib 中的预览入口符号名。
    ///   - configuration: 本次渲染使用的配置。
    public init(
        command: PreviewHostCommand,
        discovery: PreviewDiscovery? = nil,
        dylibPath: String? = nil,
        previewEntrySymbol: String? = nil,
        configuration: PreviewRenderConfiguration = .empty
    ) {
        self.command = command
        self.discovery = discovery
        self.dylibPath = dylibPath
        self.previewEntrySymbol = previewEntrySymbol
        self.configuration = configuration
    }
}

/// 预览宿主进程返回的成功或失败响应。
public struct RenderResponse: Codable, Sendable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case success
        case previewID
        case message
        case previewImagePNGBase64
        case diagnostics
        case isFallback
    }

    /// 请求是否成功。
    public let success: Bool

    /// 相关预览标识符。
    public let previewID: String?

    /// 可展示或记录的响应消息。
    public let message: String?

    /// 宿主进程当前预览画面的 PNG 数据，Base64 编码。
    public let previewImagePNGBase64: String?

    /// 可展示给用户的结构化诊断信息，例如真实 view entry 编译失败日志。
    public let diagnostics: String?

    /// 本次响应是否来自降级预览入口。
    public let isFallback: Bool

    /// 创建一个宿主响应。
    ///
    /// - Parameters:
    ///   - success: 请求是否成功。
    ///   - previewID: 相关预览标识符。
    ///   - message: 可展示或记录的响应消息。
    ///   - previewImagePNGBase64: 宿主进程当前预览画面的 PNG 数据，Base64 编码。
    ///   - diagnostics: 可展示给用户的结构化诊断信息。
    ///   - isFallback: 本次响应是否来自降级预览入口。
    public init(
        success: Bool,
        previewID: String? = nil,
        message: String? = nil,
        previewImagePNGBase64: String? = nil,
        diagnostics: String? = nil,
        isFallback: Bool = false
    ) {
        self.success = success
        self.previewID = previewID
        self.message = message
        self.previewImagePNGBase64 = previewImagePNGBase64
        self.diagnostics = diagnostics
        self.isFallback = isFallback
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.success = try container.decode(Bool.self, forKey: .success)
        self.previewID = try container.decodeIfPresent(String.self, forKey: .previewID)
        self.message = try container.decodeIfPresent(String.self, forKey: .message)
        self.previewImagePNGBase64 = try container.decodeIfPresent(String.self, forKey: .previewImagePNGBase64)
        self.diagnostics = try container.decodeIfPresent(String.self, forKey: .diagnostics)
        self.isFallback = try container.decodeIfPresent(Bool.self, forKey: .isFallback) ?? false
    }
}

/// 动态预览入口返回给宿主进程的描述信息。
///
/// 这是 `dlopen` 预览入口的稳定 ABI 载荷：入口函数返回 UTF-8 JSON 字符串，
/// 宿主进程解码后用这些字段构建预览 surface。
public struct PreviewEntryDescriptor: Codable, Sendable, Equatable {
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
public struct ErrorResponse: Codable, Sendable, Equatable {
    /// 错误描述。
    public let message: String

    /// 创建一个错误响应。
    ///
    /// - Parameter message: 错误描述。
    public init(message: String) {
        self.message = message
    }
}
