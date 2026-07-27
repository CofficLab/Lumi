import LumiUI
import SwiftUI

/// 错误提示视图
struct InputErrorView: View {
    @LumiTheme private var theme

    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)

            Text(message)
                .font(.caption)
                .foregroundColor(theme.textPrimary)
                .lineLimit(2)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
    }
}
