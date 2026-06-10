import EditorService
import SwiftUI

struct EditorHeaderView: View {
    @ObservedObject var layoutState: EditorWorkspaceLayoutState
    let service: EditorService

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                EditorTabHeaderView(service: service)
                    .frame(maxWidth: .infinity, alignment: .leading)

                EditorWorkspaceLayoutButtons(layoutState: layoutState)
            }

            Divider()
            BreadcrumbNavHeaderView(service: service)
            EditorStickySymbolBarHeaderView(service: service)
        }
    }
}

private struct EditorWorkspaceLayoutButtons: View {
    @ObservedObject var layoutState: EditorWorkspaceLayoutState

    var body: some View {
        HStack(spacing: 4) {
            if !layoutState.railVisible {
                Button {
                    layoutState.railVisible = true
                    layoutState.persistRailVisible()
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .buttonStyle(.borderless)
                .help("Show Sidebar")
            }

            Button {
                layoutState.bottomPanelVisible.toggle()
                layoutState.persistBottomPanelVisible()
            } label: {
                Image(systemName: "square.bottomthird.inset.filled")
            }
            .buttonStyle(.borderless)
            .help("Toggle Bottom Panel")
        }
        .padding(.trailing, 8)
    }
}
