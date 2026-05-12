import SwiftUI
import MagicKit
import EditorService

/// 编辑器悬停提示悬浮层。
///
/// 负责根据主视图传入的容器尺寸与缓存的卡片尺寸，定位并展示 hover 文档
/// 气泡，同时回写气泡实际尺寸以便后续定位更稳定。
public struct EditorHoverOverlayView: View, SuperLog {
    nonisolated public static let emoji = "📝"
    nonisolated public static let verbose: Bool = true

    @ObservedObject var state: EditorState
    let containerSize: CGSize
    @Binding var hoverPopoverSize: CGSize

    public init(state: EditorState, containerSize: CGSize, hoverPopoverSize: Binding<CGSize>) {
        self.state = state
        self.containerSize = containerSize
        self._hoverPopoverSize = hoverPopoverSize
    }

    public var body: some View {
        if let hoverText = state.currentHoverOverlayText {
            let style = EditorHoverOverlayStyle.standard
            let placement = state.hoverOverlayPlacement(
                in: containerSize,
                popoverSize: hoverPopoverSize,
                style: style
            )

            HoverPopoverView(markdownText: hoverText)
                .frame(
                    width: placement.cardSize.width,
                    height: placement.cardSize.height,
                    alignment: .topLeading
                )
                .fixedSize(horizontal: false, vertical: false)
                .background(
                    GeometryReader { popoverGeo in
                        Color.clear
                            .onAppear {
                                hoverPopoverSize = popoverGeo.size
                            }
                            .onChange(of: popoverGeo.size) { _, newSize in
                                hoverPopoverSize = newSize
                            }
                    }
                )
                .offset(x: placement.origin.x, y: placement.origin.y)
                .transition(.asymmetric(
                    insertion: .opacity.combined(
                        with: .scale(
                            scale: 0.97,
                            anchor: placement.isPresentedAboveSymbol ? .bottomLeading : .topLeading
                        )
                    ),
                    removal: .opacity
                ))
                .animation(.easeOut(duration: 0.14), value: state.currentHoverOverlayText)
                .animation(.easeOut(duration: 0.12), value: placement.origin)
        }
    }
}
