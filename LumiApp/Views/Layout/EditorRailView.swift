import LumiCoreKit
import LumiUI
import SwiftUI

struct EditorRailView: View {
    @LumiTheme private var theme

    let tabs: [LumiEditorRailTabItem]
    @ObservedObject var layoutState: EditorPanelLayoutState

    private static let minWidth: CGFloat = 200
    private static let maxWidth: CGFloat = 420

    var body: some View {
        VStack(spacing: 0) {
            railTabBar
            AppDivider()
            railContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: Self.minWidth, maxWidth: Self.maxWidth)
        .background(theme.surface)
        .onAppear {
            ensureValidSelection()
        }
        .onChange(of: tabs.map(\.id)) { _, _ in
            ensureValidSelection()
        }
    }

    private var railTabBar: some View {
        HStack(spacing: 8) {
            ForEach(tabs) { tab in
                Button {
                    layoutState.activeRailTabID = tab.id
                    layoutState.persistActiveRailTabID()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 10, weight: .semibold))
                        Text(tab.title)
                            .font(
                                .system(
                                    size: 11,
                                    weight: layoutState.activeRailTabID == tab.id ? .semibold : .medium
                                )
                            )
                    }
                    .foregroundStyle(
                        layoutState.activeRailTabID == tab.id ? theme.textPrimary : theme.textSecondary
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button {
                layoutState.railVisible = false
                layoutState.persistRailVisible()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
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
