import SwiftUI
import LumiCoreKit
import LumiUI

// MARK: - Turn Completed Divider

/// 对话轮次结束的分隔线视图
/// 显示为一条横线，中间写上"结束"和时间
public struct TurnCompletedDivider: View {
    public let message: ChatMessage

    @LumiMotionPreferenceReader private var motionPreference
    private var endText: String {
        switch MessageRendererRuntime.languagePreference {
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

    public var body: some View {
        AppLabeledDivider(title: endText, detail: timeText)
            .appStatusPresentationTransition(preference: motionPreference)
    }
}
