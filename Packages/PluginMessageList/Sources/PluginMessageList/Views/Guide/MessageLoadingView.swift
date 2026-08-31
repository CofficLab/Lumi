import LumiUI
import SwiftUI

struct MessageLoadingView: View {
    @LumiTheme private var theme

    var body: some View {
        Image(systemName: "bubble.left.and.bubble.right")
            .font(.largeTitle)
            .foregroundStyle(theme.textSecondary)
            .opacity(0.55)
            .accessibilityLabel(Text(LumiPluginLocalization.string("Loading messages…")))
    }
}
