import SwiftUI

/// 深度警告模型
struct DepthWarning: Identifiable, Equatable {
    let id = UUID()
    let currentDepth: Int
    let maxDepth: Int
    let warningType: WarningType

    enum WarningType {
        case approaching  // 接近最大深度 (≥ 7)
        case critical     // 接近最大深度 (≥ 9)
        case reached      // 达到最大深度 (10)
    }

    var percentage: Double {
        Double(currentDepth) / Double(maxDepth)
    }

    var warningMessage: String {
        switch warningType {
        case .approaching:
            return "对话深度 \(currentDepth)/\(maxDepth) - 建议精简任务"
        case .critical:
            return "⚠️ 对话深度 \(currentDepth)/\(maxDepth) - 即将停止"
        case .reached:
            return "🛑 已达到最大深度 \(maxDepth) - 对话已终止"
        }
    }

    var iconColor: Color {
        switch warningType {
        case .approaching:
            return Color.orange
        case .critical:
            return Color.red
        case .reached:
            return Color.red
        }
    }
}
