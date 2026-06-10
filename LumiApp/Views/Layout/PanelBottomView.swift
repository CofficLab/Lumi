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
        .frame(height: layoutState.bottomPanelHeight)
        .background(theme.surface)
        .onAppear {
            ensureValidSelection()
        }
        .onChange(of: tabs.map(\.id)) { _, _ in
            ensureValidSelection()
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                Button {
                    layoutState.activeBottomTabID = tab.id
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 10, weight: .semibold))
                        Text(tab.title)
                            .font(
                                .system(
                                    size: 11,
                                    weight: layoutState.activeBottomTabID == tab.id ? .semibold : .medium
                                )
                            )
                    }
                    .foregroundStyle(
                        layoutState.activeBottomTabID == tab.id ? theme.textPrimary : theme.textSecondary
                    )
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button {
                layoutState.bottomPanelVisible = false
                layoutState.persistBottomPanelVisible()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .background(theme.surface.opacity(0.85))
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
