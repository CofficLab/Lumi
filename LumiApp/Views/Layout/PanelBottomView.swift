import LumiCoreKit
import LumiUI
import SwiftUI

struct PanelBottomView: View {
    @LumiTheme private var theme

    let tabs: [LumiPanelBottomTabItem]
    @ObservedObject var layoutState: PanelLayoutState

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            AppDivider()
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minHeight: SplitViewHeightPersistence.minimumHeight)
        .background(theme.surface)
        .background {
            SplitViewHeightPersistence(layoutState: layoutState)
        }
        .onAppear {
            ensureValidSelection()
        }
        .onChange(of: tabs.map(\.id)) { _, _ in
            ensureValidSelection()
        }
    }

    private var tabBar: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(tabs) { tab in
                        tabButton(for: tab)
                            .id(tab.id)
                    }
                }
                .padding(.horizontal, 8)
            }
            .onChange(of: layoutState.activeBottomTabID) { _, tabID in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(tabID, anchor: .center)
                }
            }
            .onAppear {
                proxy.scrollTo(layoutState.activeBottomTabID, anchor: .center)
            }
        }
        .frame(maxWidth: .infinity)
        .background(theme.surface.opacity(0.85))
    }

    private func tabButton(for tab: LumiPanelBottomTabItem) -> some View {
        let isSelected = layoutState.activeBottomTabID == tab.id

        return Button {
            layoutState.activeBottomTabID = tab.id
        } label: {
            HStack(spacing: 4) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 10, weight: .semibold))
                Text(tab.title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.plain)
        .help(tab.title)
    }

    @ViewBuilder
    private var tabContent: some View {
        if let tab = tabs.first(where: { $0.id == layoutState.activeBottomTabID }) ?? tabs.first {
            tab.makeView()
                .id(tab.id)
        } else {
            Color.clear
        }
    }

    private func ensureValidSelection() {
        guard !tabs.isEmpty else { return }

        if tabs.contains(where: { $0.id == layoutState.activeBottomTabID }) {
            return
        }

        layoutState.activeBottomTabID = tabs[0].id
    }
}
