import SwiftUI
import EditorService

/// 编辑器表面高亮层。
///
/// 负责在源码视图表面绘制范围高亮、诊断背景或其他矩形覆盖效果。该视图
/// 只处理渲染，不参与高亮数据的筛选与布局计算。
public struct EditorSurfaceHighlightsOverlayView: View {
    public let highlights: [EditorSurfaceHighlight]

    public init(highlights: [EditorSurfaceHighlight]) {
        self.highlights = highlights
    }

    public var body: some View {
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
                            width: Self.effectiveSize(for: highlight).width,
                            height: Self.effectiveSize(for: highlight).height
                        )
                        .offset(x: highlight.rect.minX, y: highlight.rect.minY)
                        .zIndex(highlight.style.zIndex)
                }
            }
            .allowsHitTesting(false)
        }
    }

    static func effectiveSize(
        rect: CGRect,
        minimumWidth: CGFloat,
        minimumHeight: CGFloat
    ) -> CGSize {
        CGSize(
            width: max(rect.width, minimumWidth),
            height: max(rect.height, minimumHeight)
        )
    }

    static func isRenderable(
        rect: CGRect,
        minimumWidth: CGFloat,
        minimumHeight: CGFloat
    ) -> Bool {
        let size = effectiveSize(rect: rect, minimumWidth: minimumWidth, minimumHeight: minimumHeight)

        return rect.minX.isFinite
            && rect.minY.isFinite
            && size.width.isFinite
            && size.height.isFinite
            && size.width > 0
            && size.height > 0
    }

    private static func effectiveSize(for highlight: EditorSurfaceHighlight) -> CGSize {
        effectiveSize(
            rect: highlight.rect,
            minimumWidth: highlight.style.minimumWidth,
            minimumHeight: highlight.style.minimumHeight
        )
    }

    private static func isRenderable(_ highlight: EditorSurfaceHighlight) -> Bool {
        isRenderable(
            rect: highlight.rect,
            minimumWidth: highlight.style.minimumWidth,
            minimumHeight: highlight.style.minimumHeight
        )
    }
}
