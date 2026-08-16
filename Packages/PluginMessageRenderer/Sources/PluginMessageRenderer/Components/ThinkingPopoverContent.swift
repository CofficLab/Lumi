import AgentToolKit
import KernelCore
import LocalizationKit
import LumiUI
import MarkdownKit
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageSender
import ProviderToolManager
import SwiftUI
import LumiUI

struct ThinkingPopoverContent: View {
    @LumiTheme private var theme
    let text: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(LumiPluginLocalization.string("思考过程", bundle: .module))
                    .font(.appCaptionEmphasized)
                    .foregroundColor(theme.textSecondary)

                Text(text)
                    .font(.appMonoCaption)
                    .foregroundColor(theme.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
        }
        .frame(width: 420)
        .frame(maxHeight: 360)
        .appThemedAppearance()
        .background {
            ThemeWindowAppearanceBridge()
        }
    }
}
