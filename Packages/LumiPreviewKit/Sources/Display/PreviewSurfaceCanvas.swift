import AppKit
import SuperLogKit
import os
import SwiftUI

public extension LumiPreviewFacade {
    /// SwiftUI 包装：在视图树中嵌入 `PreviewSurfaceView`。
    ///
    /// 上层只需绑定一个 `surfaceID`（可选）+ `onSizeChange`；
    /// Phase 3 起新增 `isInteractive` + `onInputEvent`，开启后会把鼠标 / 滚轮 / 键盘
    /// 事件转成 `PreviewInputEvent` 上抛给 ViewModel，由其走 `forwardInputEvent` 命令送子进程。
    struct PreviewSurfaceCanvas: NSViewRepresentable, SuperLog {
        nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "LumiPreviewKit.PreviewSurfaceCanvas")
        public nonisolated static let emoji = "🖥"
        public nonisolated static let verbose: Bool = true
        // MARK: - 属性

        public let surfaceID: UInt32?
        public let isInteractive: Bool
        public let cursorShape: PreviewCursorShape
        public let onSizeChange: (CGSize, CGFloat) -> Void
        public let onInputEvent: (PreviewInputEvent) -> Void

        // MARK: - 初始化

        public init(
            surfaceID: UInt32?,
            isInteractive: Bool = false,
            cursorShape: PreviewCursorShape = .arrow,
            onSizeChange: @escaping (CGSize, CGFloat) -> Void = { _, _ in },
            onInputEvent: @escaping (PreviewInputEvent) -> Void = { _ in }
        ) {
            self.surfaceID = surfaceID
            self.isInteractive = isInteractive
            self.cursorShape = cursorShape
            self.onSizeChange = onSizeChange
            self.onInputEvent = onInputEvent
        }

        // MARK: - NSViewRepresentable

        public func makeNSView(context: Context) -> PreviewSurfaceView {
            if LumiPreviewFacade.verbose {
                Self.logger.info("\(self.t)📺 创建 NSView — surfaceID: \(surfaceID.map { String($0) } ?? "nil")")
            }
            let view = PreviewSurfaceView()
            configure(view)
            if LumiPreviewFacade.verbose {
                Self.logger.info("\(self.t) NSView 已创建：frame=\(view.frame.width)×\(view.frame.height), bounds=\(view.bounds.width)×\(view.bounds.height), superview=\(view.superview != nil)")
            }
            return view
        }

        public func updateNSView(_ nsView: PreviewSurfaceView, context: Context) {
            // 去重：surfaceID 和 isInteractive 都没变化时跳过 configure
            let unchanged = surfaceID == nsView.currentSurfaceID && isInteractive == nsView.isInteractive
            guard !unchanged else { return }
            configure(nsView)
        }

        func configure(_ nsView: PreviewSurfaceView) {
            nsView.onSizeChange = onSizeChange
            nsView.onInputEvent = onInputEvent
            nsView.isInteractive = isInteractive
            nsView.setCursorShape(cursorShape)
            if let surfaceID {
                nsView.attach(surfaceID: surfaceID)
            } else {
                nsView.detach()
            }
        }
    }
}
