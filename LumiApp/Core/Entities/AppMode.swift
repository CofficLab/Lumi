import Foundation

/// 应用模式枚举
public enum AppMode: String, CaseIterable, Identifiable, Sendable, Codable {
    case app = "App"
    case agent = "Agent"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .app: return "app.badge"
        case .agent: return "terminal.fill"
        }
    }
}
