import LumiKernel
import LumiUI
import SwiftUI

/// Rail 视图，显示侧边栏 tab bar 和内容
///
/// 自己从 kernel 获取 tabs 和状态，AppLayoutView 不需要了解其内部细节。
struct RailView: View {
    @ObservedObject var kernel: LumiKernel

    @LumiTheme private var theme

    private static let minWidth: CGFloat = 200

    private var tabs: [PanelRailTabItem] {
        kernel.sharedUI?.allPanelRailTabItems ?? []
    }

    private var activeRailTabID: String {
        kernel.layoutManager?.activeRailTabID ?? "explorer"
    }

    private var showsTabBar: Bool {
        tabs.count > 1
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsTabBar {
                RailTabBarView(
                    tabs: tabs,
                    selectedTabID: Binding(
                        get: { activeRailTabID },
                        set: { kernel.layoutManager?.presentRailTab(id: $0) }
                    )
                )
            }

            RailContentView(
                tabs: tabs,
                activeTabID: activeRailTabID
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: Self.minWidth, maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.surface)
        .borderTrailing()
        .onAppear {
            ensureValidSelection()
        }
        .onChange(of: tabs.map(\.id)) { _, _ in
            ensureValidSelection()
        }
    }

    private func ensureValidSelection() {
        guard !tabs.isEmpty else { return }

        if tabs.contains(where: { $0.id == activeRailTabID }) {
            return
        }

        kernel.layoutManager?.presentRailTab(id: tabs[0].id)
    }
}
