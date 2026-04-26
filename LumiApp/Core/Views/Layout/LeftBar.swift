import MagicKit
import SwiftUI

/// 活动栏：最左侧的窄图标导航栏（48px 固定宽度）
///
/// 聚合所有提供 `addPanelView()` 的插件图标，
/// 点击后通过 LayoutVM 驱动内容面板切换。
struct ActivityBar: View {
    @EnvironmentObject var pluginProvider: PluginVM
    @EnvironmentObject var layoutVM: LayoutVM
    @Environment(\.colorScheme) private var colorScheme

    /// 图标栏宽度
    static let width: CGFloat = 48

    var body: some View {
        let panelItems = pluginProvider.getPanelItems()
        let selectedId = currentSelectedId(in: panelItems)

        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(panelItems) { item in
                        ActivityBarButton(
                            icon: item.icon,
                            title: item.title,
                            isSelected: item.id == selectedId
                        ) {
                            layoutVM.selectAgentSidebarTab(item.id, reason: "Activity bar clicked")
                        }
                    }
                }
                .padding(.top, 8)
            }

            Spacer()

            ActivityBarButton(
                icon: "gearshape",
                title: "设置",
                isSelected: false
            ) {
                NotificationCenter.postOpenSettings()
            }
            .padding(.bottom, 8)
        }
        .frame(width: Self.width)
        .background(background)
        .onAppear {
            let items = pluginProvider.getPanelItems()
            layoutVM.restoreSelectedTab(from: items.map(\.id))
        }
        .onChange(of: pluginProvider.getPanelItems()) { _, newItems in
            layoutVM.restoreSelectedTab(from: newItems.map(\.id))
        }
    }

    // MARK: - Helpers

    private func currentSelectedId(in items: [PluginVM.PanelItem]) -> String {
        let id = layoutVM.selectedAgentSidebarTabId
        return items.contains(where: { $0.id == id }) ? id : (items.first?.id ?? "")
    }

    private var background: some View {
        Color(nsColor: .controlBackgroundColor).opacity(colorScheme == .dark ? 0.6 : 0.3)
    }
}

// MARK: - Panel Content View

/// 面板内容视图：显示当前选中插件的面板内容
///
/// 每个插件的宽度比例独立持久化（UserDefaults key: `Split.Panel.<pluginId>`）。
struct PanelContentView: View {
    @EnvironmentObject var pluginProvider: PluginVM
    @EnvironmentObject var layoutVM: LayoutVM

    var body: some View {
        let panelItems = pluginProvider.getPanelItems()
        let selectedId = layoutVM.selectedAgentSidebarTabId
        let selected = panelItems.first(where: { $0.id == selectedId }) ?? panelItems.first

        Group {
            if let selected {
                selected.view
                    .background(SplitViewWidthPersistence(storageKey: "Split.Panel.\(selected.id)"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Activity Bar Button

/// VS Code 风格的活动栏图标按钮
struct ActivityBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor)
                        .frame(width: 2.5, height: 20)
                }

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .help(title)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var iconColor: Color {
        if isSelected {
            return .primary
        }
        if isHovered {
            return colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.7)
        }
        return colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.4)
    }
}

// MARK: - Preview

#if os(macOS)
    #Preview("Activity Bar") {
        ActivityBar()
            .frame(width: 48, height: 600)
            .inRootView()
    }
#endif
