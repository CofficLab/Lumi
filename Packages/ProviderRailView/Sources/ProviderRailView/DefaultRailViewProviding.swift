import LumiUI
import SwiftUI

/// `RailViewProviding` 的默认实现：持有注入的 `RailTabItem`，
/// 渲染为「顶部标签栏 + 内容区」的侧边栏（与旧版 `FactoryCore.RailView` 视觉一致）。
///
/// 点击 tab 切换选中项并展示对应内容。
@MainActor
public final class DefaultRailViewProviding: RailViewProviding, ObservableObject {
    @Published public private(set) var tabs: [RailTabItem] = []
    @Published public private(set) var activeGroupID: String?
    @Published public private(set) var activeTabID: String?

    /// 记住每个分组最后一次选中的标签。
    private var rememberedTabIDs: [String: String] = [:]

    public init() {}

    public func registerTabs(_ tabs: [RailTabItem]) {
        self.tabs = tabs.sorted { $0.order < $1.order }
        reconcileActiveTab()
    }

    public func activateGroup(id: String?) {
        guard activeGroupID != id else {
            reconcileActiveTab()
            return
        }
        rememberActiveTab()
        activeGroupID = id
        reconcileActiveTab()
    }

    public func activateTab(id: String?) {
        guard let groupID = activeGroupID else {
            activeTabID = nil
            return
        }
        guard let id else {
            activeTabID = nil
            rememberedTabIDs[groupID] = nil
            return
        }
        guard visibleTabs.contains(where: { $0.id == id }) else { return }
        activeTabID = id
        rememberedTabIDs[groupID] = id
    }

    public func makeRailView() -> AnyView {
        AnyView(RailView(provider: self))
    }

    fileprivate var visibleTabs: [RailTabItem] {
        guard let activeGroupID else { return [] }
        return tabs.filter { $0.groupID == activeGroupID }
    }

    private func rememberActiveTab() {
        guard let groupID = activeGroupID, let activeTabID else { return }
        rememberedTabIDs[groupID] = activeTabID
    }

    private func reconcileActiveTab() {
        let candidates = visibleTabs
        guard let groupID = activeGroupID, !candidates.isEmpty else {
            activeTabID = nil
            return
        }
        if let activeTabID, candidates.contains(where: { $0.id == activeTabID }) {
            rememberedTabIDs[groupID] = activeTabID
            return
        }
        if let remembered = rememberedTabIDs[groupID],
           candidates.contains(where: { $0.id == remembered }) {
            activeTabID = remembered
        } else {
            activeTabID = candidates[0].id
        }
        rememberedTabIDs[groupID] = activeTabID
    }
}

/// 渲染「标签栏 + 内容区」的 Rail 视图。
///
/// 视觉与旧版 `FactoryCore` 的 `RailView` + `RailTabBarView` + `RailContentView`
/// 完全一致：
/// - 顶层 `VStack(spacing: 0)`：标签栏 + 内容区（无自带右侧分隔线，
///   分隔线由宿主的 `HSplitView` / `AppDivider` 提供）；
/// - 标签栏复用 `AppToolbarContainer`（height 40、`.panel` 背景、
///   上下 8 / 左右 10 内边距）+ `AppTabBar(showText: false)`（图标式），
///   并带 `borderBottom` + `shadowMd`；仅在当前分组多于一个 tab 时显示；
/// - 内容区直接渲染激活 tab 视图（`.id` 保持切换动画），无内容时透明占位；
/// - 整栏 `minWidth 200`、背景 `theme.surface`。
private struct RailView: View {
    @ObservedObject var provider: DefaultRailViewProviding
    @LumiTheme private var theme

    var body: some View {
        let visibleTabs = provider.visibleTabs

        VStack(spacing: 0) {
            // 标签栏：仅在当前分组多于一个 tab 时显示（复刻旧版 showsTabBar）。
            if let firstTab = visibleTabs.first, visibleTabs.count > 1 {
                AppToolbarContainer(
                    height: 40,
                    backgroundStyle: .panel,
                    padding: EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
                ) {
                    AppTabBar(
                        tabs: visibleTabs.map {
                            AppTabBar.Tab(title: $0.title, icon: $0.systemImage, id: $0.id)
                        },
                        selectedTab: Binding(
                            get: { provider.activeTabID ?? firstTab.id },
                            set: { provider.activateTab(id: $0) }
                        ),
                        showText: false
                    )
                }
                .borderBottom()
                .shadowMd()
            }

            // 内容区：激活 tab 视图；未命中时回退首个 tab；无任何 tab 时透明占位。
            if let active = visibleTabs.first(where: { $0.id == provider.activeTabID }) {
                active.makeView()
                    .id(active.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let first = visibleTabs.first {
                first.makeView()
                    .id(first.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Color.clear
            }
        }
        .frame(minWidth: 200, maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.surface)
    }
}
