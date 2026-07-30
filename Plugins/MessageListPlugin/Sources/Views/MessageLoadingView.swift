import LumiUI
import SwiftUI

/// Loading state view shown while the message list is fetching data.
struct MessageLoadingView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(theme.textSecondary.opacity(0.5))

            Text("Loading messages…")
                .font(.body)
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
