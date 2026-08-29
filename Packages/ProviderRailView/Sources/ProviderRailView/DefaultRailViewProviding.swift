import LumiUI
import SwiftUI

/// `RailViewProviding` 的默认实现：持有注入的 `RailTabItem`，
/// 渲染为「顶部标签栏 + 内容区」的侧边栏（与旧版 `FactoryCore.RailView` 视觉一致）。
///
/// 点击 tab 切换选中项并展示对应内容。
@MainActor
public final class DefaultRailViewProviding: RailViewProviding, ObservableObject {
    @Published public private(set) var tabs: [RailTabItem] = []
    @Published public private(set) var visibleCategories: Set<RailViewCategory>
    @Published public private(set) var visibleTabID: String?
    @Published public private(set) var activeTabID: String?

    public init(visibleCategories: Set<RailViewCategory> = Set(RailViewCategory.allCases), visibleTabID: String? = nil) {
        self.visibleCategories = visibleCategories
        self.visibleTabID = visibleTabID
    }

    public func registerTabs(_ tabs: [RailTabItem]) {
        self.tabs = tabs.sorted { $0.order < $1.order }
        reconcileActiveTab()
    }

    public func activateTab(id: String?) {
        guard let id else {
            activeTabID = nil
            return
        }
        guard visibleTabs.contains(where: { $0.id == id }) else { return }
        activeTabID = id
    }

    public func setVisibleCategories(_ categories: Set<RailViewCategory>) {
        guard visibleCategories != categories || visibleTabID != nil else { return }
        visibleCategories = categories
        // 分类过滤和指定 tab 过滤是两种互斥的显示模式；切换回分类模式时，
        // 必须清除上一个插件留下的 tab id，否则可能把分类内所有 tab 都过滤掉。
        visibleTabID = nil
        reconcileActiveTab()
    }

    public func setVisibleTabID(_ id: String?) {
        guard visibleTabID != id else { return }
        visibleTabID = id
        reconcileActiveTab()
    }

    public func makeRailView() -> AnyView {
        AnyView(RailView(provider: self))
    }

    fileprivate var visibleTabs: [RailTabItem] {
        tabs.filter { tab in
            visibleCategories.contains(tab.category)
                && (visibleTabID == nil || tab.id == visibleTabID)
        }
    }

    private func reconcileActiveTab() {
        guard !visibleTabs.isEmpty else {
            activeTabID = nil
            return
        }
        if let activeTabID, visibleTabs.contains(where: { $0.id == activeTabID }) {
            return
        }
        activeTabID = visibleTabs[0].id
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
///   并带 `borderBottom` + `shadowMd`；仅在 tab 数量大于一个时显示；
/// - 内容区直接渲染激活 tab 视图（`.id` 保持切换动画），无内容时透明占位；
/// - 整栏 `minWidth 200`、背景 `theme.surface`。
private struct RailView: View {
    @ObservedObject var provider: DefaultRailViewProviding
    @LumiTheme private var theme

    var body: some View {
        let visibleTabs = provider.visibleTabs

        VStack(spacing: 0) {
            // 标签栏：仅在 tab 数量大于一个时显示（复刻旧版 showsTabBar）。
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
