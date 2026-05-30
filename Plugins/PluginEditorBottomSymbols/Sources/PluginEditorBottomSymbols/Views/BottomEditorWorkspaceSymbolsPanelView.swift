import LumiUI
import SwiftUI

public struct BottomEditorWorkspaceSymbolsPanelView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @ObservedObject var service: EditorService
    public var showsHeader: Bool = true

    public var body: some View {
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
                Text(String(localized: "Workspace symbols not available", table: "EditorBottomSymbols"))
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(panelTitle)
                .font(.appCaptionEmphasized)
                .foregroundColor(theme.textPrimary)

            Spacer(minLength: 0)

            Button {
                service.performPanelCommand(.closeWorkspaceSymbolSearch)
            } label: {
                Image(systemName: "xmark")
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var panelTitle: String {
        let count = service.workspaceSymbolProvider.symbols.count
        return count > 0 ? String(localized: "Workspace Symbols (\(count))", table: "EditorBottomSymbols") : String(localized: "Workspace Symbols", table: "EditorBottomSymbols")
    }
}
