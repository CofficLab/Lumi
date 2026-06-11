import LumiCoreKit
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
            return LumiPluginLocalization.string("Current Provider", bundle: .module)
        case .frequent:
            return LumiPluginLocalization.string("Frequent", bundle: .module)
        case .fast:
            return LumiPluginLocalization.string("Fast", bundle: .module)
        case .auto:
            return "Auto"
        case .availability:
            return LumiPluginLocalization.string("Availability", bundle: .module)
        case .all:
            return LumiPluginLocalization.string("All", bundle: .module)
        case .provider:
            return ""  // 供应商标题由外部传入
        }
    }
}
