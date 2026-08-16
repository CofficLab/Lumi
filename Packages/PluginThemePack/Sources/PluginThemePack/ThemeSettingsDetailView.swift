import ProviderTheme
import SwiftUI

/// 外观设置详情视图：列出全部主题（内置 + 复刻），高亮当前选中，
/// 点击调用 `selectTheme(id:)` 切换并持久化。
///
/// 主题列表与选中状态来自 `ThemeProviding`；通过 `onReceive(objectWillChange)`
/// 感知主题切换（含其他窗口触发）并同步选中态。
@MainActor
struct ThemeSettingsDetailView: View {
    /// 主题管理能力（插件保证已注册，非可选）。
    let theme: any ThemeProviding

    @State private var selectedID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("外观")
                .font(.title2)

            Text("选择应用主题，切换后立即生效并自动保存")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(theme.themes) { item in
                        row(item, selectedID: selectedID ?? theme.selectedThemeId)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            selectedID = theme.selectedThemeId
        }
        .onReceive(theme.objectWillChange) { _ in
            // 主题切换（含其他窗口）后同步选中态。
            selectedID = theme.selectedThemeId
        }
    }

    private func row(_ item: LumiTheme, selectedID: String?) -> some View {
        let isSelected = item.id == selectedID
        return Button {
            try? theme.selectTheme(id: item.id)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.iconName)
                    .font(.system(size: 15))
                    .foregroundStyle(item.resolvedIconColor)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayName)
                        .font(.body)
                    if !item.description.isEmpty {
                        Text(item.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.accentColor.opacity(0.4) : Color.clear,
                        lineWidth: 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
