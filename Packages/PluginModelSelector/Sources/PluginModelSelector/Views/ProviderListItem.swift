import Foundation
import LumiUI
import ProviderLLMManager
import KitLLM
import SwiftUI

/// 供应商列表中的单行视图（由旧版复刻）。
struct ProviderListItem: View {
    @LumiTheme private var theme
    let info: LLMProviderInfo
    let isSelected: Bool
    let onSelect: () -> Void
    /// 动态模型池中的模型数量；缺省时回退静态清单。
    ///
    /// 用动态池才能反映远程刷新后新增的模型。
    var modelCount: Int? = nil
    var canRefreshModels: Bool = false
    var onRefreshModels: (() -> Void)? = nil

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
                        Text("\(modelCount ?? info.models.count) models")
                            .font(.appMicro)
                            .foregroundColor(theme.textTertiary)
                            .accessibilityIdentifier("lumi.model-selector.provider.\(info.id).count")
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
        .contextMenu {
            if canRefreshModels {
                Button {
                    onRefreshModels?()
                } label: {
                    Label(
                        pluginLocalization.string("Refresh Models"),
                        systemImage: "arrow.clockwise"
                    )
                }
            }
        }
        .accessibilityIdentifier("lumi.model-selector.provider.\(info.id)")
    }
}
