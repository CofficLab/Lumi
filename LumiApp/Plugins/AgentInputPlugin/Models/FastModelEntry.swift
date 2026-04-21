/// TPS 较快的模型条目
struct FastModelEntry: Identifiable {
    /// 唯一标识（providerId + modelName 组合）
    let id: String
    /// 供应商 ID
    let providerId: String
    /// 供应商显示名称
    let providerDisplayName: String
    /// 模型名称
    let modelName: String
    /// 平均 TPS
    let avgTPS: Double
    /// 样本数量
    let sampleCount: Int
}
