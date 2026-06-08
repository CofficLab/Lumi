public enum LumiPluginCategory: String, Sendable, Codable, CaseIterable {
    case general
    case system
    case agent
    case llmProvider
    case theme
    case development

    public var displayName: String {
        switch self {
        case .general:
            "通用"
        case .system:
            "系统"
        case .agent:
            "智能体"
        case .llmProvider:
            "模型供应商"
        case .theme:
            "主题"
        case .development:
            "开发"
        }
    }

    public var systemImage: String {
        switch self {
        case .general:
            "puzzlepiece.extension"
        case .system:
            "desktopcomputer"
        case .agent:
            "bubble.left.and.bubble.right"
        case .llmProvider:
            "cpu"
        case .theme:
            "paintbrush"
        case .development:
            "chevron.left.forwardslash.chevron.right"
        }
    }

    public var sortOrder: Int {
        switch self {
        case .general:
            10
        case .system:
            20
        case .agent:
            25
        case .llmProvider:
            26
        case .theme:
            30
        case .development:
            40
        }
    }
}
