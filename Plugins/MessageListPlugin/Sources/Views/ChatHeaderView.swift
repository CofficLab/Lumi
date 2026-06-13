import LumiUI
import SwiftUI

struct ChatHeaderView: View {
    @LumiTheme private var theme

    let title: String
    let isSending: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .foregroundColor(theme.primary)

            Text(title)
                .font(.appSectionTitle)
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)

            if isSending {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.72)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
        .appSurface(style: .toolbar, cornerRadius: 0)
    }
}
