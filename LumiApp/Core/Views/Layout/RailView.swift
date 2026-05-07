import SwiftUI

/// Rail 视图：位于活动栏与面板内容区之间的辅助栏
///
/// 内核负责渲染 Tab Bar 和内容区布局，插件通过 `addRailTabs()` 提供 tab 定义，
/// 通过 `addRailContentView(tabId:)` 提供对应的内容视图。
struct RailView: View {
    @EnvironmentObject private var pluginProvider: PluginVM
    @EnvironmentObject private var themeVM: ThemeVM

    @State private var selectedTabId: String?

    /// Rail 栏默认最小宽度
    static let minWidth: CGFloat = 200

    /// Rail 栏默认最大宽度
    static let maxWidth: CGFloat = 300

    /// 持久化 key
    private let selectedTabStorageKey = "Split.Rail.SelectedTab"

    var body: some View {
        let tabs = pluginProvider.getRailTabs()

        Group {
            if !tabs.isEmpty {
                VStack(spacing: 0) {
                    // Tab Bar
                    railTabBar(tabs: tabs)
                    GlassDivider()
                    // Content Area
                    railContent(tabs: tabs)
                }
                .frame(minWidth: Self.minWidth, maxWidth: Self.maxWidth)
            } else {
                EmptyView()
            }
        }
        .background(themeVM.activeAppTheme.sidebarBackgroundColor())
        .onAppear {
            if selectedTabId == nil {
                restoreSelection(from: tabs)
            }
        }
        .onChange(of: tabs.map(\.id)) { _, newIds in
            if let current = selectedTabId, !newIds.contains(current) {
                selectedTabId = tabs.first?.id
            }
        }
    }

    // MARK: - Tab Bar

    private func railTabBar(tabs: [RailTab]) -> some View {
        HStack(spacing: 6) {
            ForEach(tabs) { tab in
                Button {
                    selectedTabId = tab.id
                    persistSelection(tab.id)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 12, weight: .semibold))
                            .frame(height: 16)
                        Rectangle()
                            .fill(
                                selectedTabId == tab.id
                                    ? AppUI.Color.semantic.primary.opacity(0.9)
                                    : Color.clear
                            )
                            .frame(height: 2)
                    }
                    .foregroundColor(
                        selectedTabId == tab.id
                            ? AppUI.Color.semantic.textPrimary
                            : AppUI.Color.semantic.textSecondary
                    )
                    .padding(.horizontal, 6)
                    .padding(.top, 2)
                    .contentShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help(tab.title)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.05), Color.black.opacity(0.03)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Content

    private func railContent(tabs: [RailTab]) -> some View {
        let currentId = selectedTabId ?? tabs.first?.id
        let contentView = currentId.flatMap { pluginProvider.getRailContentView(tabId: $0) }

        return Group {
            if let contentView {
                contentView
            } else {
                Color.clear
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Persistence

    private func restoreSelection(from tabs: [RailTab]) {
        if let saved = UserDefaults.standard.string(forKey: selectedTabStorageKey),
           tabs.contains(where: { $0.id == saved }) {
            selectedTabId = saved
        } else {
            selectedTabId = tabs.first?.id
        }
    }

    private func persistSelection(_ tabId: String) {
        UserDefaults.standard.set(tabId, forKey: selectedTabStorageKey)
    }
}
