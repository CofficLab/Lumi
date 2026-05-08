import SwiftUI
import MagicKit

/// 编辑器代码动作悬浮层。
///
/// 负责在源码视图上方绘制 quick fix 指示器，并在用户展开时展示
/// 代码动作面板。该视图只关心展示和交互转发，不负责计算动作来源。
struct EditorCodeActionOverlayView: View {
    @ObservedObject var state: EditorState
    let lineTable: LineOffsetTable?

    var body: some View {
        GeometryReader { proxy in
            if let textView = state.focusedTextView,
               let lineTable,
               let placement = state.codeActionIndicatorPlacement(
                    textView: textView,
                    lineTable: lineTable,
                    containerSize: proxy.size
               ) {
                let actions = state.currentCodeActionOverlayActions
                VStack(alignment: .leading, spacing: 0) {
                    codeActionIndicatorButton(actionCount: actions.count)
                        .offset(x: placement.origin.x, y: placement.origin.y)

                    if state.isCodeActionPanelPresented {
                        CodeActionPanel(
                            actions: actions,
                            selectedIndex: Binding(
                                get: { state.selectedCodeActionIndex },
                                set: { state.selectCodeAction(at: $0) }
                            )
                        ) { action in
                            Task { @MainActor in
                                await state.performCodeActionOverlayAction(action)
                            }
                        }
                        .offset(x: placement.panelOrigin.x, y: placement.panelOrigin.y)
                        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .topLeading)))
                    }
                }
                .animation(.easeOut(duration: 0.14), value: state.isCodeActionPanelPresented)
            }
        }
    }

    private func codeActionIndicatorButton(actionCount: Int) -> some View {
        let style = EditorCodeActionOverlayStyle.standard
        return Button {
            state.toggleCodeActionPanel()
        } label: {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: style.indicatorCornerRadius)
                    .fill(Color(hex: "FF9F0A").opacity(state.isCodeActionPanelPresented ? 0.24 : 0.16))
                    .overlay(
                        RoundedRectangle(cornerRadius: style.indicatorCornerRadius)
                            .stroke(Color(hex: "FF9F0A").opacity(state.isCodeActionPanelPresented ? 0.7 : 0.45), lineWidth: 1)
                    )
                    .frame(width: style.indicatorSize, height: style.indicatorSize)

                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: "FF9F0A"))

                if actionCount > 1 {
                    Text("\(actionCount)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(Color(hex: "7C6FFF"))
                        )
                        .offset(x: 8, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
        .help(String(localized: "Quick Fix", table: "LumiEditor"))
    }
}
