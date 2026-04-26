/// 模型选择器 Tab 类型
enum ModelSelectorTab: String, CaseIterable {
    /// 全部供应商与模型
    case all
    /// 当前供应商
    case current
    /// 常用模型（跨供应商）
    case frequent
    /// TPS 较快的模型
    case fast
    /// 本地供应商
    case local
    /// 远程供应商
    case remote

    /// Tab 显示标题
    var displayTitle: String {
        switch self {
        case .all:
            return String(localized: "All", table: "AgentInput")
        case .current:
            return String(localized: "Current Provider", table: "AgentInput")
        case .frequent:
            return String(localized: "Frequent", table: "AgentInput")
        case .fast:
            return String(localized: "Fast", table: "AgentInput")
        case .local:
            return String(localized: "Local Providers", table: "AgentInput")
        case .remote:
            return String(localized: "Remote Providers", table: "AgentInput")
        }
    }
}
