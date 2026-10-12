import LumiUI
import ProviderPanelBottom
import SwiftUI

/// 底部面板 tab 容器（content footer 的内容视图）。
///
/// 由 `PanelBottomSuperPlugin` 注入 content footer 插槽：
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
        .onAppear { mountActiveItem() }
        .onChange(of: provider.activeItemID) { _, _ in
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
                    item.makeView()
                        .opacity(item.id == provider.activeItemID ? 1 : 0)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
