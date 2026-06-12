import Foundation

/// 常用模型条目，用于跨供应商展示最近常用的模型
public struct FrequentModelEntry: Identifiable, Sendable {
    /// 唯一标识（providerId + modelName 组合）
    public let id: String
    /// 供应商 ID
    public let providerId: String
    /// 供应商显示名称
    public let providerDisplayName: String
    /// 模型名称
    public let modelName: String
    /// 使用次数
    public let useCount: Int
    /// 最后使用时间
    public let lastUsedAt: Date
}
