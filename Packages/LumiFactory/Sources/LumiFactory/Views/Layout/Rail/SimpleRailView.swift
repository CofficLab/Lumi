import Foundation
import LumiKernel
import LumiUI
import SwiftUI

/// 简化版 Rail 视图，仅显示 rail tabs
///
/// 自己从 kernel 获取 tabs 和可见性状态，AppLayoutView 不需要了解其内部细节。
struct SimpleRailView: View {
    @ObservedObject var kernel: LumiKernel

    @LumiTheme private var theme

    private var tabs: [PanelRailTabItem] {
        kernel.panel?.allPanelRailTabItems ?? []
    }

    private var isRailVisible: Bool {
        kernel.layoutManager?.isRailVisible ?? true
    }

    private var activeRailTabID: String {
        kernel.layoutManager?.activeRailTabID ?? "explorer"
    }

    var body: some View {
        if isRailVisible {
            railContent
        }
    }

    private var railContent: some View {
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
            if let tab = tabs.first(where: { $0.id == activeRailTabID }) {
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
        .appThemedAppearance()
    }

    private func railTabButton(_ tab: PanelRailTabItem) -> some View {
        let isSelected = activeRailTabID == tab.id
        return Button {
            kernel.layoutManager?.presentRailTab(id: tab.id)
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
