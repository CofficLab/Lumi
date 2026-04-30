import SwiftUI

struct EditorWorkspaceSymbolsPanelView: View {
    @ObservedObject var state: EditorState
    var showsHeader: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            if showsHeader {
                header
                Divider()
            }
            WorkspaceSymbolItemSearchView(provider: state.workspaceSymbolProvider) { symbol in
                state.performOpenItem(.workspaceSymbol(symbol))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(panelTitle)
                .font(.system(size: 12, weight: .semibold))

            Spacer(minLength: 0)

            Button {
                state.performPanelCommand(.closeWorkspaceSymbolSearch)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var panelTitle: String {
        let count = state.workspaceSymbolProvider.symbols.count
        return count > 0 ? "Workspace Symbols (\(count))" : "Workspace Symbols"
    }
}
