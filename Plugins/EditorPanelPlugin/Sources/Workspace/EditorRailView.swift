import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

struct EditorRailView: View {
    @LumiTheme private var theme
    @ObservedObject var layoutState: EditorWorkspaceLayoutState

    @EnvironmentObject private var projectVM: WindowProjectVM
    @EnvironmentObject private var editorContext: EditorContext
    @EnvironmentObject private var conversationVM: WindowConversationVM

    @ObservedObject private var service: EditorService

    init(layoutState: EditorWorkspaceLayoutState, service: EditorService) {
        self.layoutState = layoutState
        self._service = ObservedObject(wrappedValue: service)
    }

    var body: some View {
        VStack(spacing: 0) {
            railTabBar
            Divider()
            railContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 240)
        .background(theme.surface)
    }

    private var railTabBar: some View {
        HStack(spacing: 8) {
            railTabButton(id: "explorer", title: String(localized: "Explorer", bundle: .module), systemImage: "folder")
            railTabButton(id: "problems", title: String(localized: "Problems", bundle: .module), systemImage: "exclamationmark.bubble")
            railTabButton(id: "references", title: String(localized: "References", bundle: .module), systemImage: "arrow.triangle.branch")
            railTabButton(id: "search", title: String(localized: "Search", bundle: .module), systemImage: "magnifyingglass")
            railTabButton(id: "symbols", title: String(localized: "Symbols", bundle: .module), systemImage: "number")
            railTabButton(id: "outline", title: String(localized: "Outline", bundle: .module), systemImage: "list.bullet.indent")
            railTabButton(id: "call-hierarchy", title: String(localized: "Calls", bundle: .module), systemImage: "point.3.connected.trianglepath.dotted")
            if let outline = activeLanguageOutlineRegistration {
                railTabButton(id: outline.tabID, title: outline.title, systemImage: outline.systemImage)
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

    private func railTabButton(id: String, title: String, systemImage: String) -> some View {
        Button {
            layoutState.activeRailTabID = id
        } label: {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: layoutState.activeRailTabID == id ? .semibold : .medium))
            }
            .foregroundStyle(layoutState.activeRailTabID == id ? theme.textPrimary : theme.textSecondary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var railContent: some View {
        switch layoutState.activeRailTabID {
        case "problems":
            BottomEditorProblemsPanelView(service: service, showsHeader: false)
        case "references":
            BottomEditorReferencesWorkspacePanelView(service: service, showsHeader: false)
        case "search":
            BottomEditorWorkspaceSearchPanelView(service: service, showsToolbar: true)
        case "symbols":
            BottomEditorWorkspaceSymbolsPanelView(service: service, showsHeader: false)
        case "outline":
            if let provider = service.documentSymbolProvider as? DocumentSymbolProvider {
                EditorOutlinePanelView(service: service, provider: provider, showsHeader: false, showsResizeHandle: false)
            } else {
                Text(String(localized: "Outline not available", bundle: .module))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case "call-hierarchy":
            BottomEditorCallHierarchyPanelView(service: service, showsHeader: false)
        default:
            if let outline = activeLanguageOutlineRegistration,
               layoutState.activeRailTabID == outline.tabID {
                outline.makeView()
            } else {
                EditorFileTreeView()
            }
        }
    }

    private var activeLanguageOutlineRegistration: EditorRailOutlineRegistration? {
        guard let languageId = service.detectedLanguage?.tsName else { return nil }
        return service.editorExtensions.railOutlineRegistration(for: languageId)
    }
}
