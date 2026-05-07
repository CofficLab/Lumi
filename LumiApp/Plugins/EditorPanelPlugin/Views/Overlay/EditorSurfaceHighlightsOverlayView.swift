import SwiftUI

/// 编辑器表面高亮层。
///
/// 负责在源码视图表面绘制范围高亮、诊断背景或其他矩形覆盖效果。该视图
/// 只处理渲染，不参与高亮数据的筛选与布局计算。
struct EditorSurfaceHighlightsOverlayView: View {
    let highlights: [EditorSurfaceHighlight]

    var body: some View {
        let renderableHighlights = highlights.filter(Self.isRenderable)

        if !renderableHighlights.isEmpty {
            ZStack(alignment: .topLeading) {
                ForEach(renderableHighlights) { highlight in
                    RoundedRectangle(cornerRadius: highlight.style.cornerRadius)
                        .fill(highlight.style.fillColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: highlight.style.cornerRadius)
                                .stroke(highlight.style.strokeColor, lineWidth: highlight.style.lineWidth)
                        )
                        .frame(
                            width: max(highlight.rect.width, highlight.style.minimumWidth),
                            height: max(highlight.rect.height, highlight.style.minimumHeight)
                        )
                        .offset(x: highlight.rect.minX, y: highlight.rect.minY)
                        .zIndex(highlight.style.zIndex)
                }
            }
            .allowsHitTesting(false)
        }
    }

    private static func isRenderable(_ highlight: EditorSurfaceHighlight) -> Bool {
        let width = max(highlight.rect.width, highlight.style.minimumWidth)
        let height = max(highlight.rect.height, highlight.style.minimumHeight)

        return highlight.rect.minX.isFinite
            && highlight.rect.minY.isFinite
            && width.isFinite
            && height.isFinite
            && width > 0
            && height > 0
    }
}
