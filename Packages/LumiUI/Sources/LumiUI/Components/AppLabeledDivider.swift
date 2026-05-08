import SwiftUI

public struct AppLabeledDivider: View {
    let title: String
    let detail: String?

    public init(title: String, detail: String? = nil) {
        self.title = title
        self.detail = detail
    }

    public var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(AppUI.Color.semantic.textSecondary.opacity(0.3))
                .frame(height: 1)

            HStack(spacing: 6) {
                Text(title)
                    .font(AppUI.Typography.caption1)
                    .fontWeight(.medium)

                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(AppUI.Typography.caption2)
                }
            }
            .foregroundColor(AppUI.Color.semantic.textSecondary)

            Rectangle()
                .fill(AppUI.Color.semantic.textSecondary.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.vertical, 8)
    }
}
