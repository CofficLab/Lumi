import Foundation

/// 插件开发阶段
///
/// 表示插件的成熟度和稳定性级别。
public enum LumiPluginStage: String, Sendable, CaseIterable, Comparable {
    /// 内部开发阶段，功能可能不完整或不稳定
    case dev
    
    /// Alpha 阶段，早期测试版本，可能存在较多问题
    case alpha
    
    /// Beta 阶段，功能基本完整，可能仍有 bug
    case beta
    
    /// 稳定版本，推荐使用
    case stable
    
    /// 已废弃，不建议继续使用
    case deprecated
    
    public var displayName: String {
        switch self {
        case .dev:
            return "Dev"
        case .alpha:
            return "Alpha"
        case .beta:
            return "Beta"
        case .stable:
            return "Stable"
        case .deprecated:
            return "Deprecated"
        }
    }
    
    public var description: String {
        switch self {
        case .dev:
            return "内部开发版本"
        case .alpha:
            return "早期测试版本"
        case .beta:
            return "公测版本"
        case .stable:
            return "稳定版本"
        case .deprecated:
            return "已废弃"
        }
    }
    
    /// 阶段顺序值，用于排序和比较
    private var order: Int {
        switch self {
        case .dev: return 0
        case .alpha: return 1
        case .beta: return 2
        case .stable: return 3
        case .deprecated: return 4
        }
    }
    
    public static func < (lhs: LumiPluginStage, rhs: LumiPluginStage) -> Bool {
        lhs.order < rhs.order
    }
}
