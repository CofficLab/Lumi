/// TPS 较快的模型条目
public struct FastModelEntry: Identifiable, Sendable {
    /// 唯一标识（providerId + modelName 组合）
    public let id: String
    /// 供应商 ID
    public let providerId: String
    /// 供应商显示名称
    public let providerDisplayName: String
    /// 模型名称
    public let modelName: String
    /// 平均 TPS
    public let avgTPS: Double
    /// 样本数量
    public let sampleCount: Int
}
