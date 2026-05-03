import SwiftUI
import MagicKit

/// 符号面包屑导航栏（Sticky Symbol Bar）
///
/// 显示当前光标所在位置的代码符号层级路径（例如：`Class` › `Method` › `Block`）。
/// 提供快速导航功能，点击任意符号可跳转到对应代码位置。
/// 固定在编辑器顶部区域，滚动代码时始终可见，帮助开发者在大型或深层嵌套的文件中保持上下文感知。
struct EditorStickySymbolBarView: View {
    @EnvironmentObject private var themeVM: ThemeVM

    /// 编辑器状态（用于获取光标行号、执行符号跳转等操作）
    @ObservedObject private var state: EditorState
    /// 当前光标所在的符号层级路径列表（从根到当前节点）
    let symbols: [EditorDocumentSymbolItem]

    init(state: EditorState, symbols: [EditorDocumentSymbolItem]) {
        self._state = ObservedObject(wrappedValue: state)
        self.symbols = symbols
    }

    var body: some View {
        HStack(spacing: 10) {
            // 左侧提示标签
            Label(String(localized: "Current Symbol", table: "LumiEditor"), systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())

            // 中间：可横向滚动的符号面包屑链
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(symbols.enumerated()), id: \.element.id) { index, symbol in
                        symbolChip(symbol)

                        // 在符号之间添加右箭头分隔符
                        if index < symbols.count - 1 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(themeVM.activeAppTheme.workspaceTertiaryTextColor())
                        }
                    }
                }
            }

            // 右侧弹性占位，将行号推到最右边
            Spacer(minLength: 0)

            // 当前光标行号指示器
            Text(String(localized: "Ln \(state.cursorLine)", table: "LumiEditor"))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(themeVM.activeAppTheme.workspaceTextColor().opacity(0.05))
                .clipShape(Capsule())
        }
        // 整体背景色与底部细线分隔
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.035))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.08))
                .frame(height: 1)
        }
    }

    /// 渲染单个符号胶囊按钮
    /// - Parameter symbol: 文档符号项（包含名称、图标、详情等）
    @ViewBuilder
    private func symbolChip(_ symbol: EditorDocumentSymbolItem) -> some View {
        Button {
            // 点击执行符号跳转导航
            state.performOpenItem(.documentSymbol(symbol))
        } label: {
            HStack(spacing: 5) {
                // 符号类型图标（如 struct、func、var 等）
                Image(systemName: symbol.iconSymbol)
                    .font(.system(size: 9, weight: .semibold))
                Text(symbol.name)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(themeVM.activeAppTheme.workspaceTextColor())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(themeVM.activeAppTheme.workspaceTextColor().opacity(0.05))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        // 鼠标悬停时显示符号详情
        .help(symbol.detail ?? symbol.name)
    }
}
