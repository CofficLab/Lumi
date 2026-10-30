import Foundation
import LumiUI
import ProviderLLMManager
import KitLLM
import SwiftUI

/// 供应商列表中的单行视图（由旧版复刻）。
struct ProviderListItem: View {
    @LumiTheme private var theme
    let info: LLMProviderInfo
    /// 浏览高亮：用户当前点开的供应商，只表示右栏正在展示谁的模型。
    let isBrowsing: Bool
    /// 已生效：当前对话/全局设置真正在用的供应商，右侧显示对号。
    ///
    /// 与 `isBrowsing` 分开，才能在浏览其他供应商时仍看得出当前在用谁。
    let isActive: Bool
    let onSelect: () -> Void
    /// 动态模型池中的模型数量；缺省时回退静态清单。
    ///
    /// 用动态池才能反映远程刷新后新增的模型。
    var modelCount: Int? = nil
    var canRefreshModels: Bool = false
    var onRefreshModels: (() -> Void)? = nil

    var body: some View {
        AppListRow(isSelected: isBrowsing, action: onSelect) {
            HStack(spacing: 10) {
                // 左侧图标：本地用芯片，远程用云
                Image(systemName: info.isLocal ? "cpu" : "cloud")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(info.isLocal ? theme.primary : theme.textSecondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(info.displayName)
                        .font(.appCallout)
                        .foregroundColor(isActive || isBrowsing ? theme.primary : theme.textPrimary)

                    HStack(spacing: 4) {
                        Text("\(modelCount ?? info.models.count) models")
                            .font(.appMicro)
                            .foregroundColor(theme.textTertiary)
                            .accessibilityIdentifier("lumi.model-selector.provider.\(info.id).count")
                    }
                }

                Spacer()

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(theme.primary)
                        .accessibilityLabel(pluginLocalization.string("In Use"))
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
