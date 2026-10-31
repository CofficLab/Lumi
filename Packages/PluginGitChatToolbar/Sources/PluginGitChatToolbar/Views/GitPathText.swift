import SwiftUI

/// 文件路径文本：内容超出可视宽度时可横向滚动查看完整路径。
///
/// 列表宽度有限，等宽字体下的长路径若强行截断会丢掉中间的目录层级，
/// 因此这里改为横向可滚动：短路径照常左对齐显示，长路径可横向拖动查看，
/// 滚动条常驻提示「还有内容」。
struct GitPathText: View {
    let path: String
    var font: Font = .system(size: 11, design: .monospaced)
    var color: Color = .primary

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            Text(path)
                .font(font)
                .foregroundColor(color)
                .fixedSize(horizontal: true, vertical: false)
                .textSelection(.enabled)
        }
        .frame(height: 16)
        .help(path)
    }
}
