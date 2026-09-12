import LumiUI
import SwiftUI

/// 插件管理页左侧列表中的单行渲染。
///
/// 行为完全对齐旧版：左侧展示分类图标 + 启用状态点，
/// 右侧两行文字（名称 + 描述），整体被 `AppListRow` 包裹以提供选中态。
struct PluginListRow: View {
    @LumiTheme private var theme

    let plugin: PluginManagementItem
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        AppListRow(isSelected: isSelected, action: onSelect) {
            HStack(alignment: .top, spacing: 10) {
                leadingAccessory
                textContent
            }
        }
    }

    private var leadingAccessory: some View {
        VStack(spacing: 6) {
            Image(systemName: plugin.metadata.category.systemImage)
                .font(.appBody)
                .foregroundStyle(isSelected ? theme.primary : theme.textSecondary)
                .frame(width: 22, height: 22)

            Circle()
                .fill(plugin.isEnabled ? theme.success : theme.textTertiary.opacity(0.5))
                .frame(width: 6, height: 6)
        }
        .frame(width: 22)
    }

    private var textContent: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(plugin.metadata.name)
                .font(.appCaptionEmphasized)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)

            Text(plugin.metadata.description.isEmpty ? plugin.id : plugin.metadata.description)
                .font(.appMicro)
                .foregroundStyle(theme.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
