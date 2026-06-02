import Foundation

public extension LumiPreviewFacade {
/// 单个预览环境注入项。
///
/// 当前阶段它作为宿主通信协议中的稳定描述，用于记录调用方希望注入的
/// `@EnvironmentObject` 或其他 mock。真实 SwiftUI 视图装载接入后，宿主可按
/// `typeName` 和 `mockIdentifier` 解析具体对象。
struct PreviewEnvironmentInjection: Codable, Sendable, Equatable, Hashable {
    /// 被注入对象的 Swift 类型名。
    public let typeName: String

    /// 调用方维护的 mock 标识符。
    public let mockIdentifier: String

    /// 可选展示名，用于预览面板或日志。
    public let displayName: String?

    /// 创建一个环境注入描述。
    ///
    /// - Parameters:
    ///   - typeName: 被注入对象的 Swift 类型名。
    ///   - mockIdentifier: 调用方维护的 mock 标识符。
    ///   - displayName: 可选展示名。
    public init(
        typeName: String,
        mockIdentifier: String,
        displayName: String? = nil
    ) {
        self.typeName = typeName
        self.mockIdentifier = mockIdentifier
        self.displayName = displayName
    }
}

/// 单次预览渲染配置。
struct PreviewRenderConfiguration: Codable, Sendable, Equatable, Hashable {
    /// 空配置。
    public static let empty = PreviewRenderConfiguration()

    /// 需要注入到预览中的环境对象 mock。
    public let environmentInjections: [PreviewEnvironmentInjection]

    /// 创建渲染配置。
    ///
    /// - Parameter environmentInjections: 需要注入到预览中的环境对象 mock。
    public init(environmentInjections: [PreviewEnvironmentInjection] = []) {
        self.environmentInjections = environmentInjections
    }

    /// 是否包含任何环境注入。
    public var hasEnvironmentInjections: Bool {
        !environmentInjections.isEmpty
    }
}

}
