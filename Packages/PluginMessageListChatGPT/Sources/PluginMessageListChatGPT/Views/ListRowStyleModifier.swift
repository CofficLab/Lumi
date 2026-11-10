import SwiftUI

/// List 行样式扩展：去掉默认行背景/分隔线，并用统一的水平 16 / 垂直 4 内边距
/// 替代 List 默认行内边距。
///
/// - Note: 与其它档位的同名扩展分处不同 module，故各自一份；
///   两个包互不依赖（插件不得依赖插件）。
extension View {
    func plainMessageListRow(
        insets: EdgeInsets = EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16)
    ) -> some View {
        listRowInsets(insets)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}
