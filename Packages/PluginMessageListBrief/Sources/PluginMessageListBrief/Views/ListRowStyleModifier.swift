import SwiftUI

/// List 行样式扩展：去掉默认行背景/分隔线，并用统一的水平 16 / 垂直 4 内边距替代
/// List 默认行内边距（与原 VStack 行布局一致）。
///
/// 供 ListV1View / ListV2View / ListV3View 共用，确保三个模式的视觉一致性。
extension View {
    func plainMessageListRow(
        insets: EdgeInsets = EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16)
    ) -> some View {
        listRowInsets(insets)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}
