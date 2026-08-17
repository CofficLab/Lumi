import Foundation
import LumiUI
import ProviderLLMManager
import ProviderLLMVendors
import SwiftUI

/// 供应商列表中的单行视图（由旧版复刻）。
struct ProviderListItem: View {
    @LumiTheme private var theme
    let info: LLMProviderInfo
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

                    HStack(spacing: 4) {
                        Text("\(info.models.count) models")
                            .font(.appMicro)
                            .foregroundColor(theme.textTertiary)

                        // API 协议格式（如 OpenAI / Anthropic / Responses）
                        Text("· \(info.apiFormat.displayName)")
                            .font(.appMicro)
                            .foregroundColor(theme.textTertiary)
                    }
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
