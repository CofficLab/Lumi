import SwiftUI
import MagicKit

struct EditorCallHierarchyPanelView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject var state: EditorState
    var showsHeader: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            if showsHeader {
                header
                Divider()
            }
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(panelTitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(themeManager.activeAppTheme.workspaceTextColor())

            Spacer(minLength: 0)

            Button {
                state.performPanelCommand(.closeCallHierarchy)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(themeManager.activeAppTheme.workspaceSecondaryTextColor())
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        if state.callHierarchyProvider.isLoading {
            emptyState("Loading Call Hierarchy...", systemImage: "arrow.triangle.branch")
        } else if state.callHierarchyProvider.rootItem == nil {
            emptyState("No Call Hierarchy", systemImage: "point.3.connected.trianglepath.dotted")
        } else {
            HStack(spacing: 0) {
                callHierarchyColumn(title: "Incoming", calls: state.callHierarchyProvider.incomingCalls)
                Divider()
                callHierarchyColumn(title: "Outgoing", calls: state.callHierarchyProvider.outgoingCalls)
            }
        }
    }

    private var panelTitle: String {
        let count = state.callHierarchyProvider.incomingCalls.count + state.callHierarchyProvider.outgoingCalls.count
        return count > 0 ? "Call Hierarchy (\(count))" : "Call Hierarchy"
    }

    private func callHierarchyColumn(title: String, calls: [EditorCallHierarchyCall]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(themeManager.activeAppTheme.workspaceSecondaryTextColor())
                .padding(.horizontal, 10)
                .padding(.top, 10)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if calls.isEmpty {
                        emptyState("Empty", systemImage: "minus.circle")
                    } else {
                        ForEach(calls) { call in
                            Button {
                                state.performOpenItem(.callHierarchyItem(call.item))
                            } label: {
                                panelCard(
                                    title: call.item.name,
                                    subtitle: call.item.kindDisplayName,
                                    badge: URL(string: call.item.uri)?.lastPathComponent ?? "Symbol"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func panelCard(title: String, subtitle: String, badge: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(themeManager.activeAppTheme.workspaceTextColor())
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(badge)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(themeManager.activeAppTheme.workspaceSecondaryTextColor())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(themeManager.activeAppTheme.workspaceTextColor().opacity(0.05))
                    .clipShape(Capsule())
            }

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(themeManager.activeAppTheme.workspaceSecondaryTextColor())
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(themeManager.activeAppTheme.workspaceTextColor().opacity(0.05))
        )
    }

    private func emptyState(_ title: String, systemImage: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .thin))
                .foregroundColor(themeManager.activeAppTheme.workspaceTertiaryTextColor())
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(themeManager.activeAppTheme.workspaceSecondaryTextColor())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
    }
}
