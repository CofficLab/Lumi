import LumiCoreKit
import LumiUI
import SwiftUI

struct RailView: View {
    @LumiTheme private var theme

    /// Set to `false` to hide the rail edge border.
    static let showsBorder = true

    let tabs: [LumiPanelRailTabItem]
    @ObservedObject var layoutState: PanelLayoutState

    private static let minWidth: CGFloat = 200

    private var showsTabBar: Bool {
        tabs.count > 1
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsTabBar {
                railTabBar
                AppDivider()
            }
            railContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: Self.minWidth, maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.surface)
        .overlay(alignment: .trailing) {
            if Self.showsBorder {
                AppDivider(.vertical)
            }
        }
        .onAppear {
            ensureValidSelection()
        }
        .onChange(of: tabs.map(\.id)) { _, _ in
            ensureValidSelection()
        }
    }

    private var railTabBar: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(tabs) { tab in
                        railTabButton(for: tab)
                            .id(tab.id)
                    }
                }
                .padding(.horizontal, 10)
            }
            .onChange(of: layoutState.activeRailTabID) { _, tabID in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(tabID, anchor: .center)
                }
            }
            .onAppear {
                proxy.scrollTo(layoutState.activeRailTabID, anchor: .center)
            }
        }
        .padding(.vertical, 8)
    }

    private func railTabButton(for tab: LumiPanelRailTabItem) -> some View {
        Button {
            layoutState.activeRailTabID = tab.id
            layoutState.persistActiveRailTabID()
        } label: {
            Image(systemName: tab.systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(
                    layoutState.activeRailTabID == tab.id ? theme.textPrimary : theme.textSecondary
                )
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .help(tab.title)
    }

    @ViewBuilder
    private var railContent: some View {
        if let tab = tabs.first(where: { $0.id == layoutState.activeRailTabID }) ?? tabs.first {
            tab.makeView()
                .id(tab.id)
        } else {
            Color.clear
        }
    }

    private func ensureValidSelection() {
        guard !tabs.isEmpty else { return }

        if tabs.contains(where: { $0.id == layoutState.activeRailTabID }) {
            return
        }

        layoutState.activeRailTabID = tabs[0].id
        layoutState.persistActiveRailTabID()
    }
}
