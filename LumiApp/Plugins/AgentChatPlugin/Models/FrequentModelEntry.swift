import Foundation

/// 常用模型条目，用于跨供应商展示最近常用的模型
struct FrequentModelEntry: Identifiable {
    /// 唯一标识（providerId + modelName 组合）
    let id: String
    /// 供应商 ID
    let providerId: String
    /// 供应商显示名称
    let providerDisplayName: String
    /// 模型名称
    let modelName: String
    /// 使用次数
    let useCount: Int
    /// 最后使用时间
    let lastUsedAt: Date
}
