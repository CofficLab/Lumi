import MagicKit
import SwiftUI
import LumiUI

// MARK: - Turn Completed Divider

/// 对话轮次结束的分隔线视图
/// 显示为一条横线，中间写上"结束"和时间
struct TurnCompletedDivider: View {
    let message: ChatMessage

    @EnvironmentObject private var projectVM: ProjectVM

    private var endText: String {
        switch projectVM.languagePreference {
        case .chinese:
            return "结束"
        case .english:
            return "End"
        }
    }

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: message.timestamp)
    }

    var body: some View {
        AppLabeledDivider(title: endText, detail: timeText)
    }
}
