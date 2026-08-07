import LumiKernel
import SwiftUI

/// Live-resize 期间的轻量占位行。
///
/// 用纯色块替代 `MessageRowView` 的完整富文本子树,使 SwiftUI 在 resize 每帧
/// 不再遍历昂贵的 Markdown layout。高度按消息内容长度估算,尽量接近真实行高,
/// 避免 resize 结束换回富文本时滚动位置明显跳动。
///
/// 极度轻量:只有 `RoundedRectangle` + `Color`,没有 `Text`/`AttributedString`/
/// `NSHostingView` 等 layout 开销源。
struct MessageResizePlaceholder: View {
    let message: LumiChatMessage

    /// 用于高度估算的内容(含正文 + 推理内容)。
    private var textLength: Int {
        var len = message.content.count
        if let reasoning = message.reasoningContent {
            len += reasoning.count
        }
        return len
    }

    /// 按内容长度估算行高。纯启发式,只求 resize 期间占位高度大致合理。
    /// 每字符约 0.4pt 高度 + 上下基础留白,并夹在合理区间内。
    private var estimatedHeight: CGFloat {
        let raw = CGFloat(textLength) * 0.4 + 48
        return min(max(raw, 40), 400)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.gray.opacity(0.08))
            .frame(height: estimatedHeight)
            .accessibilityHidden(true)
    }
}
