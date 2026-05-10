import SwiftUI

/// Inlay Hint 标签视图。
///
/// 用于把 LSP `textDocument/inlayHint` 返回的单个提示渲染为编辑器中的内联标签，
/// 例如类型推断、参数名提示等。
/// 该视图只负责显示样式，不负责请求 hint、计算位置或参与编辑器布局；
/// hint 数据由 `InlayHintProvider` 维护，实际叠加位置由消费 Provider 的编辑器 UI 决定。
struct InlayHintLabel: View {
    
    let hint: InlayHintItem
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Text(hint.text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(
                hint.isTypeHint
                    ? Color(nsColor: .secondaryLabelColor)
                    : Color(nsColor: .tertiaryLabelColor)
            )
            .padding(.horizontal, hint.paddingLeft ? 6 : 0)
            .padding(.horizontal, hint.paddingRight ? 6 : 0)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            )
            .help(hint.tooltip ?? "")
    }
}
