import Foundation
import SwiftUI
import KernelLumi
import LumiUI

struct ProviderListItem: View {
    @LumiTheme private var theme
    let info: LumiLLMProviderInfo
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        AppListRow(isSelected: isSelected, action: onSelect) {
            HStack(spacing: 10) {
                // 左侧图标：本地用芯片，远程用云
                Image(systemName: info.isLocal ? "cpu" : "cloud")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(info.isLocal ? theme.primary : theme.textSecondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(info.displayName)
                        .font(.appCallout)
                        .foregroundColor(isSelected ? theme.primary : theme.textPrimary)

                    Text("\(info.availableModels.count) models")
                        .font(.appMicro)
                        .foregroundColor(theme.textTertiary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(theme.primary)
                }
            }
        }
    }
}
