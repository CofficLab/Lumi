import LumiCoreKit
import SwiftUI
import LumiUI

/// Rail 视图：位于活动栏与面板内容区之间的辅助栏
///
/// 内核负责渲染 Tab Bar 和内容区布局，插件通过 `addRailItems()` 同时提供 tab 定义和内容视图。
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
            showChat: activeContainer?.showChat ?? .hidden,
            showsProjectToolbar: activeContainer?.showsProjectToolbar ?? false,
            showsRail: activeContainer?.showsRail ?? false,
            showsBottomPanel: activeContainer?.showsBottomPanel ?? false,
            windowId: windowContainer?.id
        )
        let items = pluginProvider.getRailItems(context: pluginContext)

        Group {
            if !items.isEmpty {
                VStack(spacing: 0) {
                    // Tab Bar
                    railTabBar(items: items)
                    GlassDivider()
                    // Content Area
                    railContent(items: items)
                }
                .frame(minWidth: Self.minWidth, maxWidth: Self.maxWidth)
            } else {
                EmptyView()
            }
        }
        .background(themeVM.activeChromeTheme.sidebarBackgroundColor())
        .onAppear {
            if selectedTabId == nil {
                restoreSelection(from: items)
            }
        }
        .onChange(of: items.map(\.id)) { _, newIds in
            if let current = selectedTabId, !newIds.contains(current) {
                selectedTabId = items.first?.id
            }
        }
    }

    // MARK: - Tab Bar

    private func railTabBar(items: [RailItem]) -> some View {
        HStack(spacing: 6) {
            AppTabBar(
                tabs: items.map { AppTabBar.Tab(title: $0.title, icon: $0.systemImage, id: $0.id) },
                selectedTab: Binding(
                    get: { selectedTabId ?? items.first?.id ?? "" },
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

    private func railContent(items: [RailItem]) -> some View {
        let currentId = selectedTabId ?? items.first?.id ?? "empty"
        let activeItem = items.first { $0.id == currentId }

        return Group {
            if let activeItem {
                RailTabContentHost(tabId: activeItem.id, makeView: activeItem.makeView)
                    // Rail 内容切换时平滑过渡
                    .transition(.opacity.animation(LumiMotion.enabled(LumiMotion.reveal, preference: motionPreference)))
                    .id(activeItem.id)
            } else {
                Color.clear
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Persistence

    private func restoreSelection(from items: [RailItem]) {
        if let saved = UserDefaults.standard.string(forKey: selectedTabStorageKey),
           items.contains(where: { $0.id == saved }) {
            selectedTabId = saved
        } else {
            selectedTabId = items.first?.id
        }
    }

    private func persistSelection(_ tabId: String) {
        UserDefaults.standard.set(tabId, forKey: selectedTabStorageKey)
    }
}

/// 缓存 Rail 标签内容，避免父视图每次 body 求值都调用 `makeView()` 导致子视图状态丢失。
private struct RailTabContentHost: View {
    let tabId: String
    let makeView: @MainActor () -> AnyView

    @State private var hostedTabId: String?
    @State private var hostedView: AnyView?

    var body: some View {
        Group {
            if let hostedView, hostedTabId == tabId {
                hostedView
            } else {
                Color.clear
            }
        }
        .onAppear(perform: ensureHostedView)
        .onChange(of: tabId) { _, _ in ensureHostedView() }
    }

    private func ensureHostedView() {
        guard hostedTabId != tabId else { return }
        hostedTabId = tabId
        hostedView = makeView()
    }
}
