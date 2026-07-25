import SwiftUI
import EditorService

/// 编辑器次光标高亮层。
///
/// 负责在多光标编辑场景下绘制非主光标对应的高亮轮廓，帮助用户区分多个
/// 同时激活的编辑位置。
struct EditorSecondaryCursorOverlayView: View {
    let highlights: [EditorMultiCursorHighlight]

    init(highlights: [EditorMultiCursorHighlight]) {
        self.highlights = highlights
    }

    var body: some View {
        if !highlights.isEmpty {
            ZStack(alignment: .topLeading) {
                ForEach(highlights) { highlight in
                    RoundedRectangle(cornerRadius: highlight.cornerRadius)
                        .fill(highlight.fillColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: highlight.cornerRadius)
                                .stroke(
                                    highlight.strokeColor,
                                    style: StrokeStyle(lineWidth: highlight.lineWidth, dash: highlight.dash)
                                )
                        )
                        .frame(width: max(highlight.rect.width, 2), height: max(highlight.rect.height, 2))
                        .offset(x: highlight.rect.minX, y: highlight.rect.minY)
                }
            }
            .allowsHitTesting(false)
        }
    }
}
