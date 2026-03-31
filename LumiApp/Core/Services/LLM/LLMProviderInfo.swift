import Foundation

/// 供应商信息模型
struct LLMProviderInfo: Identifiable, Equatable, Sendable {
    /// 供应商唯一 ID
    let id: String

    /// 显示名称
    let displayName: String

    /// 供应商描述
    let description: String

    /// 可用模型列表
    let availableModels: [String]

    /// 默认模型
    let defaultModel: String

    /// 是否为本地供应商（如 MLX 等本地推理）
    let isLocal: Bool

    /// 是否启用（可通过供应商定义文件配置）
    let isEnabled: Bool
}
