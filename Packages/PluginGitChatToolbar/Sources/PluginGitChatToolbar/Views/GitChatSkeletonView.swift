import LumiUI
import SwiftUI

/// 弹层加载态骨架屏。
struct GitChatSkeletonView: View {
    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { _ in
                AppSkeletonText(lineWidths: [1])
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
