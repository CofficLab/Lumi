import LumiUI
import SwiftUI

struct MessageLoadingView: View {
    @LumiTheme private var theme
    @State private var breathing = false

    var body: some View {
        Image(systemName: "bubble.left.and.bubble.right")
            .font(.largeTitle)
            .foregroundStyle(theme.textSecondary)
            .opacity(breathing ? 0.3 : 1)
            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: breathing)
            .onAppear { breathing = true }
            .accessibilityLabel(Text(LumiPluginLocalization.string("Loading messages…")))
    }
}
