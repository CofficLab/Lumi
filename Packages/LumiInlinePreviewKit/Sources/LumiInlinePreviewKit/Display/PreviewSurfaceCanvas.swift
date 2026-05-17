import AppKit
import MagicKit
import os
import SwiftUI

public extension LumiInlinePreviewFacade {
    /// SwiftUI 包装：在视图树中嵌入 `PreviewSurfaceView`。
    ///
    /// 上层只需绑定一个 `surfaceID`（可选）+ `onSizeChange`；
    /// Phase 3 起新增 `isInteractive` + `onInputEvent`，开启后会把鼠标 / 滚轮 / 键盘
    /// 事件转成 `PreviewInputEvent` 上抛给 ViewModel，由其走 `forwardInputEvent` 命令送子进程。
    struct PreviewSurfaceCanvas: NSViewRepresentable, SuperLog {
        nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "LumiInlinePreviewKit.PreviewSurfaceCanvas")
        public nonisolated static let emoji = "🖥"
        public nonisolated static let verbose: Bool = true
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
            if LumiInlinePreviewFacade.verbose {
                Self.logger.info("\(self.t)📺 创建 NSView — surfaceID: \(surfaceID.map { String($0) } ?? "nil")")
            }
            let view = PreviewSurfaceView()
            view.onSizeChange = onSizeChange
            view.onInputEvent = onInputEvent
            view.isInteractive = isInteractive
            if let surfaceID {
                view.attach(surfaceID: surfaceID)
            }
            if LumiInlinePreviewFacade.verbose {
                Self.logger.info("\(self.t) NSView 已创建：frame=\(view.frame.width)×\(view.frame.height), bounds=\(view.bounds.width)×\(view.bounds.height), superview=\(view.superview != nil)")
            }
            return view
        }

        public func updateNSView(_ nsView: PreviewSurfaceView, context: Context) {
            if LumiInlinePreviewFacade.verbose {
                Self.logger.info("\(self.t)🔄 更新 NSView — surfaceID: \(surfaceID.map { String($0) } ?? "nil"), 可交互: \(isInteractive), view.frame=\(nsView.frame.width)×\(nsView.frame.height), view.bounds=\(nsView.bounds.width)×\(nsView.bounds.height)")
            }
            nsView.onSizeChange = onSizeChange
            nsView.onInputEvent = onInputEvent
            nsView.isInteractive = isInteractive
            if let surfaceID {
                nsView.attach(surfaceID: surfaceID)
                // 🔍 诊断：检查视图层级和 layer 状态
                if LumiInlinePreviewFacade.verbose {
                    let winStr = nsView.window != nil ? "yes" : "no"
                    let supStr = nsView.superview != nil ? "yes" : "no"
                    let layerStr = nsView.layer != nil ? "yes" : "no"
                    let hiddenStr = nsView.isHidden ? "yes" : "no"
                    let alphaStr = String(format: "%.2f", nsView.alphaValue)
                    Self.logger.info("\(self.t) 层级诊断：window=\(winStr), superview=\(supStr), layer=\(layerStr), hidden=\(hiddenStr), alpha=\(alphaStr), frame=\(nsView.frame.width)×\(nsView.frame.height)")
                }
            } else {
                nsView.detach()
            }
        }
    }
}
