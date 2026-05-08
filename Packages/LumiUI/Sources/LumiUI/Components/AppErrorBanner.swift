import SwiftUI

public struct AppErrorBanner: View {
    let message: LocalizedStringKey
    let retryTitle: LocalizedStringKey?
    let onRetry: (() -> Void)?

    public init(message: LocalizedStringKey) {
        self.message = message
        self.retryTitle = nil
        self.onRetry = nil
    }

    public init(message: LocalizedStringKey, retryTitle: LocalizedStringKey, onRetry: @escaping () -> Void) {
        self.message = message
        self.retryTitle = retryTitle
        self.onRetry = onRetry
    }

    public var body: some View {
        HStack(spacing: AppUI.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(AppUI.Color.semantic.error)

            Text(message)
                .font(AppUI.Typography.caption1)
                .foregroundColor(AppUI.Color.semantic.error)
                .lineLimit(nil)

            Spacer()

            if let retryTitle, let onRetry {
                AppButton(retryTitle, style: .ghost, size: .small, action: onRetry)
            }
        }
        .padding(.horizontal, AppUI.Spacing.md)
        .padding(.vertical, AppUI.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppUI.Radius.sm)
                .fill(AppUI.Color.semantic.error.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppUI.Radius.sm)
                .stroke(AppUI.Color.semantic.error.opacity(0.2), lineWidth: 1)
        )
    }
}
