import SwiftUI

/// 文档颜色预览圆点。
///
/// 用于在编辑器中以小色块形式展示 LSP `textDocument/documentColor` 返回的颜色信息。
/// 该视图只负责渲染颜色本身和 tooltip，不负责请求颜色或处理颜色替换；
/// 数据由 `DocumentColorProvider` 维护。
struct ColorPreview: View {
    let color: EditorDocumentColor

    var body: some View {
        Circle()
            .fill(Color(nsColor: color.nsColor))
            .frame(width: 12, height: 12)
            .overlay(Circle().stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
            .help(color.hexString)
    }
}
