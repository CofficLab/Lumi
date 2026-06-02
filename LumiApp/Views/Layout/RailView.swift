import LumiCoreKit
import SwiftUI
import LumiUI

/// Rail 视图：位于活动栏与面板内容区之间的辅助栏
///
/// 内核负责渲染 Tab Bar 和内容区布局，插件通过 `addRailTabs()` 提供 tab 定义，
/// 通过 `addRailContentView(tabId:)` 提供对应的内容视图。
struct RailView: View {
    @LumiMotionPreferenceReader private var motionPreference
    @EnvironmentObject private var pluginProvider: AppPluginVM
    @EnvironmentObject private var layoutVM: WindowLayoutVM
    @EnvironmentObject private var themeVM: AppThemeVM
    @Environment(\.windowContainer) private var windowContainer

    @State private var selectedTabId: String?

    /// Rail 栏默认最小宽度
    static let minWidth: CGFloat = 200

    /// Rail 栏默认最大宽度
    static let maxWidth: CGFloat = 420

    /// 持久化 key
    private let selectedTabStorageKey = "Split.Rail.SelectedTab"

    var body: some View {
        let activeIcon = layoutVM.activeViewContainerIcon
        let activeContainer = pluginProvider.getActiveViewContainer(activeIcon: activeIcon)
        let pluginContext = PluginContext(
            activeIcon: activeIcon,
            isEditorVisible: layoutVM.editorVisible,
            supportsAIChat: activeContainer?.supportsAIChat ?? false,
            showsProjectToolbar: activeContainer?.showsProjectToolbar ?? false,
            windowId: windowContainer?.id
        )
        let tabs = pluginProvider.getRailTabs(context: pluginContext)

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
        .background(themeVM.activeChromeTheme.sidebarBackgroundColor())
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
            AppTabBar(
                tabs: tabs.map { AppTabBar.Tab(title: $0.title, icon: $0.systemImage, id: $0.id) },
                selectedTab: Binding(
                    get: { selectedTabId ?? tabs.first?.id ?? "" },
                    set: { newValue in
                        selectedTabId = newValue
                        persistSelection(newValue)
                    }
                ),
                showText: false
            )
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
        let activeIcon = layoutVM.activeViewContainerIcon
        let activeContainer = pluginProvider.getActiveViewContainer(activeIcon: activeIcon)
        let railContext = PluginContext(
            activeIcon: activeIcon,
            isEditorVisible: layoutVM.editorVisible,
            supportsAIChat: activeContainer?.supportsAIChat ?? false,
            showsProjectToolbar: activeContainer?.showsProjectToolbar ?? false,
            windowId: windowContainer?.id
        )
        let contentView = currentId.flatMap { pluginProvider.getRailContentView(tabId: $0, context: railContext) }

        return Group {
            if let contentView {
                contentView
                    // Rail 内容切换时平滑过渡
                    .transition(.opacity.animation(LumiMotion.enabled(LumiMotion.reveal, preference: motionPreference)))
                    .id(currentId ?? "empty")
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
