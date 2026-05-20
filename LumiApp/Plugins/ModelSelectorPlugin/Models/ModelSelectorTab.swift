/// 模型选择器 Tab 类型
enum ModelSelectorTab: Equatable {
    // MARK: - 快捷 Tab

    /// 当前供应商
    case current
    /// 常用模型（跨供应商）
    case frequent
    /// TPS 较快的模型
    case fast
    /// 自动模型路由
    case auto
    /// 模型可用性
    case availability

    // MARK: - 供应商 Tab

    /// 全部供应商
    case all
    /// 指定供应商（关联 providerId）
    case provider(String)

    // MARK: - 显示标题

    /// Tab 显示标题
    var displayTitle: String {
        switch self {
        case .current:
            return String(localized: "Current Provider", table: "AgentChat")
        case .frequent:
            return String(localized: "Frequent", table: "AgentChat")
        case .fast:
            return String(localized: "Fast", table: "AgentChat")
        case .auto:
            return "Auto"
        case .availability:
            return String(localized: "Availability", table: "LLMAvailability")
        case .all:
            return String(localized: "All", table: "AgentChat")
        case .provider:
            return ""  // 供应商标题由外部传入
        }
    }
}
