import LumiKernel
import LumiKernel
import LumiUI
import SwiftUI

struct ToolMessageView: View {
    @Environment(\.lumiResponseVerbosity) private var verbosity
    @LumiTheme private var theme

    let message: LumiChatMessage
    @Binding var showRawMessage: Bool

    private var isBrief: Bool { verbosity == .brief }

    var body: some View {
        MessageViewChrome(message: message, showRawMessage: $showRawMessage) {
            Group {
                if isBrief {
                    briefContent
                } else {
                    BorderedUtilityContent(tint: theme.success, role: .tool) {
                        detailedContent
                    }
                }
            }
        }
    }

    private var briefContent: some View {
        detailedContent
            .font(.appCaption)
            .foregroundColor(theme.textSecondary)
    }

    private var detailedContent: some View {
                VStack(alignment: .leading, spacing: 8) {
                    if !message.userImageData.isEmpty {
                        AppImagePreviewGrid(imageDataList: message.userImageData)
                    }

                    Text(message.content.isEmpty ? "Tool Result" : message.content)
                        .font(isBrief ? .appCaption : .appMonoCaption)
                        .foregroundColor(isBrief ? theme.textSecondary : theme.textPrimary)
                        .textSelection(.enabled)
                }
    }
}
