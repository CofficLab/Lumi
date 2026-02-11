import SwiftUI

struct PreviewMenuRow: View {
    let item: RClickMenuItem

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.type.iconName)
                .font(.system(size: 14))
                .frame(width: 16)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            Text(item.title)
                .font(.system(size: 13))
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

            Spacer()

            if item.type == .newFile {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.clear)
        .contentShape(Rectangle())
    }
}
