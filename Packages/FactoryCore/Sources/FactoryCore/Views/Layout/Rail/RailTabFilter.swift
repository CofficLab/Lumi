import KernelLumi

/// 计算当前视图容器应展示的侧边栏 rail tabs。
///
/// 过滤规则（方案 A —— 容器专属独占）：
/// 1. 先按既有条件过滤：`visibility` 在当前容器可见，且满足容器对项目的
///    `supportsProject` 与 chat 支持要求；
/// 2. 若当前容器拥有「专属 rail tab」（`visibility == .viewContainer(id: 当前容器)`），
///    则**只保留这些专属 tab**，不再混入 `.always` 等全局 tab；
/// 3. 否则维持既有行为（全局 tab + 匹配的专属 tab 全部展示）。
///
/// 这样带专属 rail tab 的插件容器（Resume、BookletMaker、Git、MindMap、
/// AppIconDesigner、AppStoreConnect 等）在侧边栏只会看到自己的 rail view；
/// 默认聊天容器没有专属 tab，行为与之前完全一致，无回归风险。
///
/// `PanelRailTabItem` 为 `@MainActor` 类型，本函数需在主线程调用（视图层天然满足）。
@MainActor
func filteredRailTabs(
    _ allTabs: [PanelRailTabItem],
    containerID: String,
    supportsProject: Bool,
    supportsChat: Bool
) -> [PanelRailTabItem] {
    // 容器是否拥有专属 rail tab（visibility 精确指向当前容器）。
    let ownsExclusiveTabs = allTabs.contains {
        $0.visibility == .viewContainer(id: containerID)
    }

    // 既有过滤条件：容器可见性 + 项目支持 + chat 支持。
    let visibleTabs = allTabs.filter {
        $0.visibility.isVisible(in: containerID)
            && (!$0.requiresProjectSupport || supportsProject)
            && (!$0.requiresChatSupport || supportsChat)
    }

    // 独占：容器有专属 tab 时只保留专属 tab；否则维持现状。
    guard ownsExclusiveTabs else { return visibleTabs }
    return visibleTabs.filter {
        $0.visibility == .viewContainer(id: containerID)
    }
}
