import Foundation
import SwiftUI
import LumiUI

/// 模型列表中的单行视图
struct ModelListItem: View {
    @LumiTheme private var theme

    let displayName: String
    let model: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.system(size: 13))
                        .foregroundColor(isSelected ? theme.primary : theme.textPrimary)

                    Text(model)
                        .font(.system(size: 11))
                        .foregroundColor(theme.textTertiary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(theme.primary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? theme.primary.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}
