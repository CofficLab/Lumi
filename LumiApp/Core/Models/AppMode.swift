import Foundation

/// 应用模式枚举
enum AppMode: String, CaseIterable, Identifiable {
    case app = "应用模式"
    case agent = "Agent 模式"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .app: return "app.badge"
        case .agent: return "terminal.fill"
        }
    }
}
