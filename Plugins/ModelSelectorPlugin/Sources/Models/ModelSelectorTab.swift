/// 模型选择器 Tab 类型
public enum ModelSelectorTab: Equatable {
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
    public var displayTitle: String {
        switch self {
        case .current:
            return String(localized: "Current Provider", bundle: .module)
        case .frequent:
            return String(localized: "Frequent", bundle: .module)
        case .fast:
            return String(localized: "Fast", bundle: .module)
        case .auto:
            return "Auto"
        case .availability:
            return String(localized: "Availability", bundle: .module)
        case .all:
            return String(localized: "All", bundle: .module)
        case .provider:
            return ""  // 供应商标题由外部传入
        }
    }
}
