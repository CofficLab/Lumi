import LumiUI
import ProviderPanelBottom
import SwiftUI

/// 底部面板单个入口在内容区 ZStack 中的呈现状态。
///
/// 已挂载的非激活入口保留在 ZStack 中以复用状态（终端等），但透明视图仍会
/// 参与 SwiftUI 命中测试；只有激活入口可以接收输入，并且必须位于最上层，
/// 否则 order 更高的隐藏入口会拦截当前入口的点击与滚动（#1017）。
struct PanelBottomItemPresentation: Equatable {
    let isActive: Bool

    var opacity: Double { isActive ? 1 : 0 }
    var allowsHitTesting: Bool { isActive }
    var zIndex: Double { isActive ? 1 : 0 }

    init(itemID: String, activeItemID: String?) {
        isActive = itemID == activeItemID
    }
}

/// 底部面板 tab 容器（content footer 的内容视图）。
///
/// 由 `PanelBottomPlugin` 注入 content footer 插槽：
/// 上方一排入口 tab（复用 LumiUI `AppTabBar`），下方渲染入口内容。
///
/// 内容区采用「首次激活懒加载 + 之后保活」：
/// - 入口内容视图在对应 tab **首次激活**时才构造（如终端会话按需创建，
///   避免用户未打开 Terminal tab 就拉起 PTY）；
/// - 一旦构造过就保持挂载，切走时仅以 opacity 隐藏 ——
///   与 `TerminalMainView` 的 tab 策略一致，避免终端 NSView 反复销毁重建丢状态。
@MainActor
struct PanelBottomView: View {
    @ObservedObject var provider: PanelBottomProvider
    @State private var mountedIDs: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            content
        }
        .debugViewBadge("Panel Bottom", alignment: .bottomLeading)
        .onAppear { mountActiveItem() }
        .onChange(of: provider.activeItemID) { _ in
            mountActiveItem()
        }
    }

    // MARK: - 入口栏

    private var tabBar: some View {
        AppTabBar(
            tabs: provider.items.map {
                AppTabBar.Tab(title: $0.title, icon: $0.systemImage, id: $0.id)
            },
            selectedTab: Binding(
                get: { provider.activeItemID ?? provider.items.first?.id ?? "" },
                set: { provider.selectItem(id: $0) }
            )
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    // MARK: - 入口内容

    private var content: some View {
        ZStack {
            ForEach(provider.items) { item in
                if mountedIDs.contains(item.id) {
                    let presentation = PanelBottomItemPresentation(
                        itemID: item.id,
                        activeItemID: provider.activeItemID
                    )
                    item.makeView()
                        .opacity(presentation.opacity)
                        .allowsHitTesting(presentation.allowsHitTesting)
                        .zIndex(presentation.zIndex)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .debugViewBadge(item.id)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    /// 挂载当前激活的入口内容（幂等）。
    private func mountActiveItem() {
        guard let active = provider.activeItemID else { return }
        guard !mountedIDs.contains(active) else { return }
        mountedIDs.insert(active)
    }
}
