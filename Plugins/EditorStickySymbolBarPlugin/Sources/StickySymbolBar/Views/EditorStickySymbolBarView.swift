import EditorService
import LumiKernel
import LumiUI
import SwiftUI

@MainActor
public enum EditorStickySymbolBarBridge {
    public static var editorServiceProvider: (() -> EditorService?)?
}

/// 编辑器符号面包屑头部视图。
public struct EditorStickySymbolBarHeaderView: View {
    private let service: EditorService

    public init(service: EditorService) {
        self.service = service
    }

    public var body: some View {
        let activeDocumentSymbolTrail = service.lsp.documentSymbolProvider.activeItems(for: service.editing.cursorLine)
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
public struct EditorStickySymbolBarView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    /// 编辑器服务门面（用于获取光标行号、执行符号跳转等操作）
    @ObservedObject private var service: EditorService
    /// 当前光标所在的符号层级路径列表（从根到当前节点）
    public let symbols: [EditorDocumentSymbolItem]

    public init(service: EditorService, symbols: [EditorDocumentSymbolItem]) {
        self._service = ObservedObject(wrappedValue: service)
        self.symbols = symbols
    }

    public var body: some View {
        HStack(spacing: 10) {
            Label(LumiPluginLocalization.string("Current Symbol", bundle: .module), systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                .font(.appMicroEmphasized)
                .foregroundColor(theme.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(symbols.enumerated()), id: \.element.id) { index, symbol in
                        symbolChip(symbol)

                        if index < symbols.count - 1 {
                            Image(systemName: "chevron.right")
                                .font(.appMicroEmphasized)
                                .foregroundColor(theme.textTertiary)
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            Text(LumiPluginLocalization.string("Ln \(service.editing.cursorLine)", bundle: .module))
                .font(.appMicroEmphasized)
                .foregroundColor(theme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(theme.textPrimary.opacity(0.05))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.textTertiary.opacity(0.035))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.textTertiary.opacity(0.08))
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func symbolChip(_ symbol: EditorDocumentSymbolItem) -> some View {
        Button {
            service.navigation.performOpenItem(.documentSymbol(symbol))
        } label: {
            HStack(spacing: 5) {
                Image(systemName: symbol.iconSymbol)
                    .font(.appMicroEmphasized)
                Text(symbol.name)
                    .font(.appMicroEmphasized)
                    .lineLimit(1)
            }
            .foregroundColor(theme.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(theme.textPrimary.opacity(0.05))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(symbol.detail ?? symbol.name)
    }
}
