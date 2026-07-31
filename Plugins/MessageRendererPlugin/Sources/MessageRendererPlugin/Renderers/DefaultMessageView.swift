import LumiKernel
import LumiKernel
import LumiUI
import SwiftUI

struct DefaultMessageView: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    let verbosity: LumiResponseVerbosity

    var body: some View {
        MessageViewChrome(message: message, verbosity: verbosity) {
            Text(message.content)
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .textSelection(.enabled)
                .lineSpacing(3)
        }
    }
}