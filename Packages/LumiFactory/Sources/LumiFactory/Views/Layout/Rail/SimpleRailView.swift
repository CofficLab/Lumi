import Foundation
import LumiKernel
import LumiUI
import SwiftUI

/// 简化版 Rail 视图，仅显示 rail tabs
struct SimpleRailView: View {
    let tabs: [PanelRailTabItem]
    @ObservedObject var layoutState: LayoutState

    @LumiTheme private var theme

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            if tabs.count > 1 {
                ForEach(tabs) { tab in
                    railTabButton(tab)
                }
            }

            if tabs.count > 0 {
                Divider()
            }

            // Active tab content
            let activeTabID = layoutState.activeRailTabID
            if let tab = tabs.first(where: { $0.id == activeTabID }) {
                tab.makeView()
            } else if let firstTab = tabs.first {
                firstTab.makeView()
            } else {
                Text("No rail tabs")
                    .font(.caption)
                    .foregroundStyle(theme.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.surface)
        // 让 SwiftUI 控件（含 List/NSTableView 的默认背景、Picker 等）按当前
        // Lumi 主题解析明暗，而不是仅依赖 NSWindow.appearance 的异步同步——
        // 后者在启动期无法及时穿透到内嵌 List，会导致列表背景初显暗色。
        .appThemedAppearance()
    }

    private func railTabButton(_ tab: PanelRailTabItem) -> some View {
        let isSelected = layoutState.activeRailTabID == tab.id
        return Button {
            layoutState.activeRailTabID = tab.id
        } label: {
            HStack {
                Image(systemName: tab.systemImage)
                    .frame(width: 20)
                Text(tab.title)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? theme.primary.opacity(0.1) : Color.clear)
            .foregroundColor(isSelected ? theme.primary : theme.textSecondary)
        }
        .buttonStyle(.plain)
    }
}
