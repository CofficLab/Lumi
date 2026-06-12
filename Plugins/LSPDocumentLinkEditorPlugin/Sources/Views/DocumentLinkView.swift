import SwiftUI

/// 文档链接文本视图。
///
/// 用于把 LSP `textDocument/documentLink` 返回的链接范围渲染为可点击文本。
/// 该视图只负责视觉样式和点击回调，不负责请求、解析或打开链接；
/// 链接数据由 `DocumentLinkProvider` 维护，实际跳转行为由上层通过 `onTap` 注入。
public struct DocumentLinkView: View {
    public let text: String
    public let link: EditorDocumentLink
    public let onTap: () -> Void
    
    public var body: some View {
        Text(text)
            .font(.system(size: NSFont.systemFontSize, design: .monospaced))
            .foregroundColor(.blue)
            .underline()
            .onTapGesture(perform: onTap)
            .help(link.tooltip ?? link.target ?? "")
    }
}
