import AppKit
import SwiftUI

public extension LumiInlinePreviewFacade {
    /// SwiftUI 包装：在视图树中嵌入 `PreviewSurfaceView`。
    ///
    /// 上层只需绑定一个 `surfaceID`（可选）+ `onSizeChange`；
    /// Phase 3 起新增 `isInteractive` + `onInputEvent`，开启后会把鼠标 / 滚轮 / 键盘
    /// 事件转成 `PreviewInputEvent` 上抛给 ViewModel，由其走 `forwardInputEvent` 命令送子进程。
    struct PreviewSurfaceCanvas: NSViewRepresentable {

        // MARK: - 属性

        public let surfaceID: UInt32?
        public let isInteractive: Bool
        public let onSizeChange: (CGSize, CGFloat) -> Void
        public let onInputEvent: (PreviewInputEvent) -> Void

        // MARK: - 初始化

        public init(
            surfaceID: UInt32?,
            isInteractive: Bool = false,
            onSizeChange: @escaping (CGSize, CGFloat) -> Void = { _, _ in },
            onInputEvent: @escaping (PreviewInputEvent) -> Void = { _ in }
        ) {
            self.surfaceID = surfaceID
            self.isInteractive = isInteractive
            self.onSizeChange = onSizeChange
            self.onInputEvent = onInputEvent
        }

        // MARK: - NSViewRepresentable

        public func makeNSView(context: Context) -> PreviewSurfaceView {
            let view = PreviewSurfaceView()
            view.onSizeChange = onSizeChange
            view.onInputEvent = onInputEvent
            view.isInteractive = isInteractive
            if let surfaceID {
                view.attach(surfaceID: surfaceID)
            }
            return view
        }

        public func updateNSView(_ nsView: PreviewSurfaceView, context: Context) {
            nsView.onSizeChange = onSizeChange
            nsView.onInputEvent = onInputEvent
            nsView.isInteractive = isInteractive
            if let surfaceID {
                nsView.attach(surfaceID: surfaceID)
            } else {
                nsView.detach()
            }
        }
    }
}
