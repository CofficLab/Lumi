import SwiftUI

struct BottomEditorWorkspaceSymbolsPanelView: View {
    @ObservedObject var service: EditorService
    var showsHeader: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            if showsHeader {
                header
                Divider()
            }
            if let provider = service.workspaceSymbolProvider as? WorkspaceSymbolProvider {
                WorkspaceSymbolItemSearchView(provider: provider) { symbol in
                    service.performOpenItem(.workspaceSymbol(symbol))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Workspace symbols not available")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(panelTitle)
                .font(.system(size: 12, weight: .semibold))

            Spacer(minLength: 0)

            Button {
                service.performPanelCommand(.closeWorkspaceSymbolSearch)
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
        let count = service.workspaceSymbolProvider.symbols.count
        return count > 0 ? "Workspace Symbols (\(count))" : "Workspace Symbols"
    }
}
