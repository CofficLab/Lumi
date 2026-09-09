import LumiUI
import ProviderConversation
import SwiftUI

struct MessageLoadingView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: ResponseVerbosity.standard.iconName)
                .font(.largeTitle)
                .foregroundStyle(theme.textSecondary)
                .opacity(0.55)

            VStack(spacing: 3) {
                Text(LumiPluginLocalization.string("Loading messages…"))
                    .font(.system(size: 13, weight: .medium))
                Text(LumiPluginLocalization.string("Standard mode"))
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .foregroundStyle(theme.textSecondary)
        .accessibilityElement(children: .combine)
    }
}
