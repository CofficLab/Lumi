import Foundation

/// 供应商信息模型
struct LLMProviderInfo: Identifiable, Equatable, Sendable {
    /// 供应商唯一 ID
    let id: String

    /// 显示名称
    let displayName: String

    /// 图标名称（SF Symbols）
    ///
    /// 用于 UI 显示，与显示名称对应。
    let iconName: String

    /// 供应商描述
    let description: String

    /// 可用模型列表
    let availableModels: [String]

    /// 默认模型
    let defaultModel: String

    /// 是否为本地供应商（如 MLX 等本地推理）
    let isLocal: Bool
}
