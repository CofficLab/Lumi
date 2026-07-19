import LumiKernel
import LumiUI
import SwiftUI

/// ChatSectionCoordinator 不可用时的错误视图
struct ChatMessagesErrorView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    var pluginName: String = "Chat Messages"

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.appTitle)
                .foregroundColor(.red)

            Text("\(pluginName): \(LumiPluginLocalization.string("Service unavailable", bundle: .module))")
                .font(.appBody)
                .foregroundColor(theme.textPrimary)

            Text(LumiPluginLocalization.string("Unable to load messages", bundle: .module))
                .font(.appMicro)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)

            Text(LumiPluginLocalization.string("Please restart the app", bundle: .module))
                .font(.appMicro)
                .foregroundColor(theme.textTertiary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Error View") {
    ChatMessagesErrorView()
        .frame(width: 400, height: 300)
}
#endif
