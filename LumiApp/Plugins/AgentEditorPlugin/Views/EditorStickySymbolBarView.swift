import SwiftUI
import MagicKit

struct EditorStickySymbolBarView: View {
    @EnvironmentObject private var themeManager: ThemeManager

    @ObservedObject private var state: EditorState
    let symbols: [EditorDocumentSymbolItem]

    init(state: EditorState, symbols: [EditorDocumentSymbolItem]) {
        self._state = ObservedObject(wrappedValue: state)
        self.symbols = symbols
    }

    var body: some View {
        HStack(spacing: 10) {
            Label("Current Symbol", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(themeManager.activeAppTheme.workspaceSecondaryTextColor())

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(symbols.enumerated()), id: \.element.id) { index, symbol in
                        symbolChip(symbol)

                        if index < symbols.count - 1 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(themeManager.activeAppTheme.workspaceTertiaryTextColor())
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            Text("Ln \(state.cursorLine)")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(themeManager.activeAppTheme.workspaceSecondaryTextColor())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(themeManager.activeAppTheme.workspaceTextColor().opacity(0.05))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(themeManager.activeAppTheme.workspaceTertiaryTextColor().opacity(0.035))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(themeManager.activeAppTheme.workspaceTertiaryTextColor().opacity(0.08))
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func symbolChip(_ symbol: EditorDocumentSymbolItem) -> some View {
        Button {
            state.performOpenItem(.documentSymbol(symbol))
        } label: {
            HStack(spacing: 5) {
                Image(systemName: symbol.iconSymbol)
                    .font(.system(size: 9, weight: .semibold))
                Text(symbol.name)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(themeManager.activeAppTheme.workspaceTextColor())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(themeManager.activeAppTheme.workspaceTextColor().opacity(0.05))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(symbol.detail ?? symbol.name)
    }
}
