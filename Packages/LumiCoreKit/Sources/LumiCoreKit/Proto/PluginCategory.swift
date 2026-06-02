import Foundation

/// 插件分类
///
/// 定义插件所属的功能分类，用于在设置页等 UI 中分组展示插件。
public enum PluginCategory: String, CaseIterable, Codable, Sendable {
    /// 通用（默认分类）
    case general
    /// AI / Agent
    case agent
    /// 编辑器增强
    case editor
    /// LLM 供应商
    case llmProvider
    /// 主题 / 外观
    case theme
    /// 开发工具
    case developerTool
    /// 系统管理
    case system
    /// 网络
    case network
    /// 集成 / 外部服务
    case integration

    /// 显示名称
    public var displayName: String {
        switch self {
        case .general:       return "通用"
        case .agent:         return "AI 助手"
        case .editor:        return "编辑器"
        case .llmProvider:   return "LLM 供应商"
        case .theme:         return "主题"
        case .developerTool: return "开发工具"
        case .system:        return "系统"
        case .network:       return "网络"
        case .integration:   return "集成"
        }
    }

    /// SF Symbol 图标
    public var systemImage: String {
        switch self {
        case .general:       return "puzzlepiece"
        case .agent:         return "brain"
        case .editor:        return "doc.text"
        case .llmProvider:   return "cpu"
        case .theme:         return "paintpalette"
        case .developerTool: return "wrench.and.screwdriver"
        case .system:        return "gearshape"
        case .network:       return "network"
        case .integration:   return "arrow.triangle.branch"
        }
    }

    /// 分类排序优先级（数字越小越靠前）
    public var sortOrder: Int {
        switch self {
        case .agent:         return 100
        case .editor:        return 200
        case .llmProvider:   return 300
        case .theme:         return 400
        case .developerTool: return 500
        case .system:        return 600
        case .network:       return 700
        case .general:       return 800
        case .integration:   return 900
        }
    }
}
