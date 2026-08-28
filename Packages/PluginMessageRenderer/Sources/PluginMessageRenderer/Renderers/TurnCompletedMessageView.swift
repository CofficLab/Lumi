import KitAgentTool
import KernelCore
import KitLocalization
import LumiUI
import KitMarkdown
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageSender
import ProviderToolManager
import LumiUI
import SwiftUI

struct TurnCompletedMessageView: View {
    let message: Message

    private var turnDurationText: String? {
        guard let raw = message.metadata["turnDurationMs"],
              let ms = Double(raw) else { return nil }
        let seconds = ms / 1000.0
        if seconds < 1 {
            return String(format: "%d ms", Int(ms.rounded()))
        }
        return String(format: "%.1f s", seconds)
    }

    var body: some View {
        AppLabeledDivider(
            title: "结束",
            detail: MessageViewHelpers.formatTimestamp(message.createdAt) + (turnDurationText.map { " · 耗时 \($0)" } ?? "")
        )
        .padding(.vertical, 8)
    }
}
