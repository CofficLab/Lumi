import LumiUI
import SwiftUI

/// Loading state view shown while the message list is fetching data.
///
/// Renders a shimmering conversation skeleton so the user sees a preview of
/// what the loaded list will look like, instead of an empty screen. A small
/// "Loading messages…" caption sits at the bottom to keep the loading state
/// explicit.
struct MessageLoadingView: View {
    @LumiTheme private var theme

    static let useSimple: Bool = true

    var body: some View {
        if Self.useSimple {
            ProgressView()
        } else {
            VStack(spacing: 0) {
                // Conversation-shaped skeleton: user/assistant bubbles interleaved
                // a few times. Takes all available space so the caption can sit at
                // the bottom of the panel rather than the center.
                MessageSkeletonView()

                // Trailing caption — explicit loading affordance for users who
                // don't notice the skeleton animation.
                Text(String(localized: "Loading messages…", bundle: .module))
                    .font(.caption)
                    .foregroundColor(theme.textSecondary.opacity(0.7))
                    .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview("Message loading") {
    MessageLoadingView()
        .frame(width: 480, height: 600)
}
