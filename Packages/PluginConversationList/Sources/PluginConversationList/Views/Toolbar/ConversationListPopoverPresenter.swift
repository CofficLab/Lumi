#if os(macOS)
import AppKit
import SwiftUI

/// macOS 工具栏对话列表 popover 的 AppKit 宿主。
///
/// 为什么不用 SwiftUI `.popover`：
/// macOS 上 SwiftUI `.popover` 内部固定使用 `NSPopover.behavior = .transient`，
/// 没有公开 API 能改成常驻。要实现「图钉后点击应用内其它区域、切换前台应用都不收起」，
/// 必须直接持有 `NSPopover` 并在钉住时切换到 `.applicationDefined`。
///
/// 实现方式：
/// - 在按钮背景放一个不参与命中测试的透明 `NSView` 作为锚点；
/// - 用 `NSHostingController` 承载现有 SwiftUI popover 内容，不重写列表；
/// - 未钉住时点击外部由 `NSPopover` 自行收起，delegate 把关闭同步回 SwiftUI 状态；
/// - 钉住时 `popoverShouldClose` 拒绝非程序化关闭，作为 `.applicationDefined` 之外的第二道保险。
struct ConversationListPopoverPresenter<Content: View>: NSViewRepresentable {
    @Binding var isPresented: Bool
    @Binding var isPinned: Bool
    let content: () -> Content

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSView {
        let view = AnchorView()
        context.coordinator.anchorView = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.anchorView = nsView
        context.coordinator.syncPopover()
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.teardown()
    }

    @MainActor
    final class Coordinator: NSObject, NSPopoverDelegate {
        var parent: ConversationListPopoverPresenter
        weak var anchorView: NSView?

        private var popover: NSPopover?
        private var hostingController: NSHostingController<AnyView>?
        /// SwiftUI 要求关闭时不一定伴随用户事件；把关闭动作推迟到当前视图更新之外，
        /// 避免在 `updateNSView` 里同步写回状态。
        private var pendingClose = false

        init(parent: ConversationListPopoverPresenter) {
            self.parent = parent
        }

        func syncPopover() {
            if parent.isPresented {
                guard let anchorView else { return }
                showIfNeeded(relativeTo: anchorView)
                applyBehavior()
            } else if popover?.isShown == true {
                scheduleClose()
            }
        }

        private func showIfNeeded(relativeTo anchorView: NSView) {
            let popover = makePopoverIfNeeded()
            guard !popover.isShown else { return }
            popover.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .minY)
        }

        private func makePopoverIfNeeded() -> NSPopover {
            if let popover { return popover }

            let hostingController = NSHostingController(rootView: AnyView(parent.content()))
            let popover = NSPopover()
            popover.animates = true
            popover.delegate = self
            popover.contentViewController = hostingController
            popover.contentSize = NSSize(width: 300, height: 360)

            self.hostingController = hostingController
            self.popover = popover
            return popover
        }

        private func applyBehavior() {
            guard let popover else { return }
            let behavior: NSPopover.Behavior = parent.isPinned ? .applicationDefined : .transient
            if popover.behavior != behavior {
                popover.behavior = behavior
            }
        }

        private func scheduleClose() {
            guard !pendingClose else { return }
            pendingClose = true
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.pendingClose = false
                // 关闭请求排队期间如果又被打开，以最新的打开状态为准。
                guard !self.parent.isPresented else { return }
                self.popover?.close()
                self.resetPinState()
            }
        }

        private func resetPinState() {
            if parent.isPinned {
                parent.isPinned = false
            }
            if popover?.behavior != .transient {
                popover?.behavior = .transient
            }
        }

        func teardown() {
            popover?.delegate = nil
            popover?.close()
            popover = nil
            hostingController = nil
            anchorView = nil
        }

        // MARK: - NSPopoverDelegate

        /// 钉住时拒绝 `NSPopover` 因点击外部 / 应用失活等非程序化原因发起的关闭。
        /// 程序化关闭走 `close()`，不会经过这里。
        func popoverShouldClose(_ popover: NSPopover) -> Bool {
            !parent.isPinned
        }

        func popoverDidClose(_ notification: Notification) {
            parent.isPresented = false
            if parent.isPinned {
                parent.isPinned = false
            }
            popover?.behavior = .transient
        }
    }

    /// 透明锚点：不参与命中测试，保证点击仍然落到工具栏按钮上。
    final class AnchorView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
#endif
