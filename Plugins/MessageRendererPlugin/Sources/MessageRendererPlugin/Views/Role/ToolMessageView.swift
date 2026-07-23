import LumiKernel
import LumiKernel
import LumiUI
import SwiftUI

struct ToolMessageView: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    @Binding var showRawMessage: Bool

    var body: some View {
        MessageViewChrome(message: message, showRawMessage: $showRawMessage) {
            BorderedUtilityContent(tint: theme.success, role: .tool) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: message.isError ? "exclamationmark.triangle.fill" : "doc.text.magnifyingglass")
                            .foregroundColor(message.isError ? theme.error : theme.success)
                        Text(message.toolCallID.map { "Tool Result \($0)" } ?? "Tool Result")
                            .font(.appCaptionEmphasized)
                            .foregroundColor(theme.textPrimary)
                    }

                    Text(message.content)
                        .font(.appMonoCaption)
                        .foregroundColor(theme.textPrimary)
                        .textSelection(.enabled)
                }
            }
        }
    }
}
