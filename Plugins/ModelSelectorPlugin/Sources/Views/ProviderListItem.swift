import Foundation
import SwiftUI
import LumiKernel
import LumiUI

struct ProviderListItem: View {
    @LumiTheme private var theme
    let info: LumiLLMProviderInfo
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                // 左侧图标：本地用芯片，远程用云
                Image(systemName: info.isLocal ? "cpu" : "cloud")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(info.isLocal ? theme.primary : theme.textSecondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(info.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isSelected ? theme.primary : theme.textPrimary)

                    Text("\(info.availableModels.count) models")
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
