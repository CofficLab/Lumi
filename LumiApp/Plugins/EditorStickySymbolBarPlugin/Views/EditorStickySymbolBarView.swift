import SwiftUI

/// 编辑器符号面包屑头部视图。
struct EditorStickySymbolBarHeaderView: View {
    @EnvironmentObject private var editorVM: WindowEditorVM

    private var service: EditorService { editorVM.service }

    private var activeDocumentSymbolTrail: [EditorDocumentSymbolItem] {
        service.documentSymbolProvider.activeItems(for: service.cursorLine)
    }

    var body: some View {
        if !activeDocumentSymbolTrail.isEmpty {
            EditorStickySymbolBarView(
                service: service,
                symbols: activeDocumentSymbolTrail
            )
        }
    }
}

/// 符号面包屑导航栏（Sticky Symbol Bar）
///
/// 显示当前光标所在位置的代码符号层级路径（例如：`Class` › `Method` › `Block`）。
/// 提供快速导航功能，点击任意符号可跳转到对应代码位置。
/// 固定在编辑器顶部区域，滚动代码时始终可见，帮助开发者在大型或深层嵌套的文件中保持上下文感知。
struct EditorStickySymbolBarView: View {
    @EnvironmentObject private var themeVM: AppThemeVM

    /// 编辑器服务门面（用于获取光标行号、执行符号跳转等操作）
    @ObservedObject private var service: EditorService
    /// 当前光标所在的符号层级路径列表（从根到当前节点）
    let symbols: [EditorDocumentSymbolItem]

    init(service: EditorService, symbols: [EditorDocumentSymbolItem]) {
        self._service = ObservedObject(wrappedValue: service)
        self.symbols = symbols
    }

    var body: some View {
        HStack(spacing: 10) {
            Label(String(localized: "Current Symbol", table: "LumiEditor"), systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(themeVM.activeChromeTheme.workspaceSecondaryTextColor())

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(symbols.enumerated()), id: \.element.id) { index, symbol in
                        symbolChip(symbol)

                        if index < symbols.count - 1 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(themeVM.activeChromeTheme.workspaceTertiaryTextColor())
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            Text(String(localized: "Ln \(service.cursorLine)", table: "LumiEditor"))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(themeVM.activeChromeTheme.workspaceSecondaryTextColor())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(themeVM.activeChromeTheme.workspaceTextColor().opacity(0.05))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(themeVM.activeChromeTheme.workspaceTertiaryTextColor().opacity(0.035))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(themeVM.activeChromeTheme.workspaceTertiaryTextColor().opacity(0.08))
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func symbolChip(_ symbol: EditorDocumentSymbolItem) -> some View {
        Button {
            service.performOpenItem(.documentSymbol(symbol))
        } label: {
            HStack(spacing: 5) {
                Image(systemName: symbol.iconSymbol)
                    .font(.system(size: 9, weight: .semibold))
                Text(symbol.name)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(themeVM.activeChromeTheme.workspaceTextColor())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(themeVM.activeChromeTheme.workspaceTextColor().opacity(0.05))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(symbol.detail ?? symbol.name)
    }
}
