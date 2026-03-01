import Foundation

/// 应用模式枚举
public enum AppMode: String, CaseIterable, Identifiable, Sendable {
    case app = "应用模式"
    case agent = "Agent 模式"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .app: return "app.badge"
        case .agent: return "terminal.fill"
        }
    }
}
