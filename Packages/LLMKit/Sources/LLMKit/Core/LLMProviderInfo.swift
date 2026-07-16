import Foundation

/// 供应商信息模型
public struct LLMProviderInfo: Identifiable, Equatable, Sendable {
    /// 供应商唯一 ID
    public let id: String

    /// 显示名称
    public let displayName: String

    /// 简写名称（用于工具栏等空间受限区域）
    public let shortName: String

    /// 供应商描述
    public let description: String

    /// 供应商官网地址
    public let websiteURL: String?

    /// 可用模型列表
    public let availableModels: [String]

    /// 默认模型
    public let defaultModel: String

    /// 是否为本地供应商（如 MLX 等本地推理）
    public let isLocal: Bool

    /// 是否启用（可通过供应商定义文件配置）
    public let isEnabled: Bool

    /// 模型上下文窗口大小映射（模型名 → Token 数）
    public let contextWindowSizes: [String: Int]

    public init(
        id: String,
        displayName: String,
        shortName: String,
        description: String,
        websiteURL: String?,
        availableModels: [String],
        defaultModel: String,
        isLocal: Bool,
        isEnabled: Bool,
        contextWindowSizes: [String: Int]
    ) {
        self.id = id
        self.displayName = displayName
        self.shortName = shortName
        self.description = description
        self.websiteURL = websiteURL
        self.availableModels = availableModels
        self.defaultModel = defaultModel
        self.isLocal = isLocal
        self.isEnabled = isEnabled
        self.contextWindowSizes = contextWindowSizes
    }
}
