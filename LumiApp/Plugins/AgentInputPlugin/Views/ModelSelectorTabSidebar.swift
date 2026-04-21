import SwiftUI

/// 模型选择器 Tab 侧边栏
struct ModelSelectorTabSidebar: View {
    /// 当前选中的 Tab
    @Binding var selectedTab: ModelSelectorTab
    /// 当前 hover 的 Tab
    @Binding var hoveringTab: ModelSelectorTab?

    var body: some View {
        VStack(spacing: 4) {
            ForEach(ModelSelectorTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    HStack(spacing: 8) {
                        Image(systemName: tabIconName(for: tab))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppUI.Color.semantic.textSecondary)
                            .frame(width: 16, alignment: .center)
                        Text(tab.displayTitle)
                            .font(AppUI.Typography.body)
                            .lineLimit(1)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(tabBackgroundColor(for: tab))
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    hoveringTab = hovering ? tab : nil
                }
            }
            Spacer()
        }
        .padding(8)
    }

    // MARK: - Helper

    /// Tab 图标
    private func tabIconName(for tab: ModelSelectorTab) -> String {
        switch tab {
        case .all: return "globe"
        case .current: return "scope"
        case .frequent: return "clock.arrow.circlepath"
        case .fast: return "bolt.fill"
        case .local: return "laptopcomputer"
        case .remote: return "cloud"
        }
    }

    /// Tab 背景色
    private func tabBackgroundColor(for tab: ModelSelectorTab) -> Color {
        if selectedTab == tab {
            return Color.accentColor.opacity(0.15)
        }
        if hoveringTab == tab {
            return Color.accentColor.opacity(0.08)
        }
        return Color.clear
    }
}
