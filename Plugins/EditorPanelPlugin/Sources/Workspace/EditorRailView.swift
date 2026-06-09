import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI
import VueEditorPlugin

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
            if isVueFileActive {
                railTabButton(id: "vue-outline", title: "Vue", systemImage: "curlybraces")
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
        if layoutState.activeRailTabID == "vue-outline", isVueFileActive {
            VueOutlineRailContainer()
        } else {
            EditorFileTreeView()
        }
    }

    private var isVueFileActive: Bool {
        service.currentFileURL?.pathExtension.lowercased() == "vue"
    }
}

private struct VueOutlineRailContainer: View {
    @State private var outlineView: AnyView = AnyView(Color.clear)

    var body: some View {
        outlineView
            .task {
                outlineView = await VueEditorPlugin.shared.makeOutlineRailView()
            }
    }
}
