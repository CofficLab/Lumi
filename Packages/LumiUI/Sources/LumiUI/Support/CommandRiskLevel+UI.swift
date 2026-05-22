import SwiftUI
import ToolKit

public extension CommandRiskLevel {
    var iconName: String {
        switch self {
        case .safe: return "checkmark.shield.fill"
        case .low: return "info.circle.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .high: return "exclamationmark.octagon.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .safe: return .green
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        }
    }
}
