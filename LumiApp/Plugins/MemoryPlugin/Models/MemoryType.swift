import Foundation

/// 记忆类型
///
/// 与 Claude Code memdir 系统的四种记忆类型保持一致。
/// 核心原则：只记从代码/Git 推导不出来的信息。
enum MemoryType: String, Codable, CaseIterable, Sendable {
    /// 用户角色、偏好、知识水平（始终私有/全局）
    case user
    /// 用户对 Lumi 行为的指导（默认全局，项目级约定可存项目级）
    case feedback
    /// 项目上下文：目标、决策、非代码可得信息（项目级）
    case project
    /// 外部系统指针：Linear/Grafana/文档链接等（项目级）
    case reference

    /// 显示名称
    var displayName: String {
        switch self {
        case .user: return "User"
        case .feedback: return "Feedback"
        case .project: return "Project"
        case .reference: return "Reference"
        }
    }

    /// 中文显示名称
    var displayNameZh: String {
        switch self {
        case .user: return "用户"
        case .feedback: return "反馈"
        case .project: return "项目"
        case .reference: return "引用"
        }
    }

    /// 默认作用域
    var defaultScope: MemoryScope {
        switch self {
        case .user, .feedback:
            return .global
        case .project, .reference:
            // 项目级需要外部提供 projectPath
            return .global // fallback
        }
    }
}
