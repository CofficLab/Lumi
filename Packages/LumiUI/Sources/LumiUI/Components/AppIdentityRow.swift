import SwiftUI

public struct AppIdentityRow: View {
    let title: String
    let metadata: [String]
    let titleColor: Color
    let metadataColor: Color

    public init(
        title: String,
        metadata: [String] = [],
        titleColor: Color? = nil,
        metadataColor: Color? = nil
    ) {
        self.title = title
        self.metadata = metadata.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        self.titleColor = titleColor ?? DesignTokens.Color.semantic.textPrimary
        self.metadataColor = metadataColor ?? DesignTokens.Color.semantic.textSecondary
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 4) {
            Text(title)
                .font(DesignTokens.Typography.caption1)
                .fontWeight(.medium)
                .foregroundColor(titleColor)
                .lineLimit(1)

            ForEach(Array(metadata.enumerated()), id: \.offset) { _, item in
                Text("·")
                    .foregroundColor(metadataColor)
                Text(item)
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(metadataColor)
                    .lineLimit(1)
            }
        }
    }
}
