import EditorService
import LumiUI
import SwiftUI

/// Inlay Hint 标签视图。
///
/// 用于把 LSP `textDocument/inlayHint` 返回的单个提示渲染为编辑器中的内联标签，
/// 例如类型推断、参数名提示等。
/// 该视图只负责显示样式，不负责请求 hint、计算位置或参与编辑器布局；
/// hint 数据由 `InlayHintProvider` 维护，实际叠加位置由消费 Provider 的编辑器 UI 决定。
public struct InlayHintLabel: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    
    public let hint: InlayHintItem
    
    public var body: some View {
        Text(hint.text)
            .font(.appMonoMicro)
            .foregroundColor(hint.isTypeHint ? theme.textSecondary : theme.textTertiary)
            .padding(.horizontal, hint.paddingLeft ? 6 : 0)
            .padding(.horizontal, hint.paddingRight ? 6 : 0)
            .appSurface(style: .custom(theme.appStatusMutedFill), cornerRadius: 3)
            .help(hint.tooltip ?? "")
    }
}
