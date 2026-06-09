import EditorBottomCallHierarchyPlugin
import EditorBottomProblemsPlugin
import EditorBottomReferencesPlugin
import EditorBottomSearchPlugin
import EditorBottomSymbolsPlugin
import EditorBottomTerminalPlugin
import EditorPreviewPlugin
import EditorRailFileTreePlugin
import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

struct EditorBottomPanelView: View {
    @LumiTheme private var theme
    @ObservedObject var layoutState: EditorWorkspaceLayoutState
    let service: EditorService

    private let tabs: [(id: String, title: String, systemImage: String)] = [
        ("editor-bottom-problems", "Problems", "exclamationmark.bubble"),
        ("editor-bottom-references", "References", "arrow.triangle.branch"),
        ("editor-bottom-symbols", "Symbols", "list.bullet.rectangle"),
        ("editor-bottom-search", "Search", "magnifyingglass"),
        ("editor-bottom-call-hierarchy", "Call Hierarchy", "point.3.connected.trianglepath.dotted"),
        ("editor-bottom-terminal", "Terminal", "terminal"),
        ("editor-bottom-inline-preview", "Preview", "rectangle.inset.filled"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: layoutState.bottomPanelHeight)
        .background(theme.surface)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.id) { tab in
                Button {
                    layoutState.activeBottomTabID = tab.id
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 10, weight: .semibold))
                        Text(tab.title)
                            .font(.system(size: 11, weight: layoutState.activeBottomTabID == tab.id ? .semibold : .medium))
                    }
                    .foregroundStyle(layoutState.activeBottomTabID == tab.id ? theme.textPrimary : theme.textSecondary)
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
        switch layoutState.activeBottomTabID {
        case "editor-bottom-problems":
            BottomEditorProblemsPanelView(service: service, showsHeader: false)
        case "editor-bottom-references":
            BottomEditorReferencesWorkspacePanelView(service: service, showsHeader: false)
        case "editor-bottom-symbols":
            BottomEditorWorkspaceSymbolsPanelView(service: service, showsHeader: false)
        case "editor-bottom-search":
            BottomEditorWorkspaceSearchPanelView(service: service, showsToolbar: true)
        case "editor-bottom-call-hierarchy":
            BottomEditorCallHierarchyPanelView(service: service, showsHeader: false)
        case "editor-bottom-terminal":
            EditorBottomTerminalPanelView()
        case "editor-bottom-inline-preview":
            EditorPreviewDetailView()
        default:
            BottomEditorProblemsPanelView(service: service, showsHeader: false)
        }
    }
}
