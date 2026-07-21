import LumiUI
import SwiftUI

/// Error view shown when the message renderer service is unavailable.
struct MessageRendererUnavailableView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.orange)

            Text("Message Renderer Unavailable")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            Text("The message renderer service is not available. Please check plugin configuration.")
                .font(.body)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
