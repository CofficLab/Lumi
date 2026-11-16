import AppKit
import SwiftUI
import Testing
@testable import PluginConversationInput

/// 「发送到对话」把代码选区递交给输入框后，键盘焦点必须真正移到 Composer。
///
/// ## 回归背景（#803，真实用户缺陷）
///
/// 生产代码（`SendSelectionToConversationContributor` / `ConversationInputViewModel`）
/// 把 `isInputFocused` 置 true，`ComposerView` 把它作为 binding 传给编辑器。但
/// `ChatInputEditorView.updateNSView` 只处理文本、光标与折叠块，从不消费该 binding、
/// 从不请求第一响应者——布尔变 true ≠ 焦点真的移动。用户不点 Composer 直接继续
/// 打字，字符仍写进代码编辑器而非草稿。
///
/// 修复：`updateNSView` 在 false→true 边沿调 `window.makeFirstResponder`；编辑器失去
/// 第一响应者时复位边沿并把 binding 写回 false，使再次发送能重新聚焦。
///
/// - Important: 在真实 `NSHostingView` + `NSWindow` 里渲染生产组件，跑真正的
///   makeNSView + updateNSView，并检查 `window.firstResponder`。settling 用 await
///   让出主 actor，不用 RunLoop.main.run 同步阻塞（会饿死同包异步用例）。
@MainActor
@Suite("ChatInputEditorView 焦点移交（#803）")
struct ChatInputEditorFocusTests {

    @Test("发送到对话置 isFocused=true 后 Composer 成为第一响应者（**回归 #803**）")
    func handoverMovesFirstResponderToComposer() async throws {
        let box = FocusBox()
        let (window, hosting) = await host(box)
        defer { teardown(window: window, hosting: hosting) }
        let editor = try #require(findEditor(in: hosting), "应找到原生编辑器")

        // 模拟用户当前在代码编辑器：先把焦点从 Composer 移走，排除 window
        // 成为 key 时 AppKit 自动聚焦带来的假阳性。
        let other = try #require(makeOtherEditor(in: window))
        window.makeFirstResponder(other)
        await settle()
        #expect(window.firstResponder === other, "前置：焦点应在代码编辑器侧")
        #expect(box.focused == false)

        // 发送到对话：生产路径把 isInputFocused 置 true。
        box.focused = true
        await settle()

        #expect(window.firstResponder === editor, "递交后键盘焦点必须真正移到 Composer，而非只把布尔置 true")
    }

    @Test("焦点离开后再次发送能重新聚焦，且离开时 binding 写回 false（**回归 #803**）")
    func refocusesAfterFocusLoss() async throws {
        let box = FocusBox()
        let (window, hosting) = await host(box)
        defer { teardown(window: window, hosting: hosting) }
        let editor = try #require(findEditor(in: hosting), "应找到原生编辑器")
        let other = try #require(makeOtherEditor(in: window))

        // 第一次发送 → 聚焦 Composer。
        window.makeFirstResponder(other)
        box.focused = true
        await settle()
        #expect(window.firstResponder === editor)

        // 用户点回代码编辑器 → Composer 失去第一响应者。
        window.makeFirstResponder(other)
        await settle()
        #expect(window.firstResponder === other)
        #expect(box.focused == false, "失去焦点必须把 binding 写回 false，否则下次发送无法重新触发边沿")

        // 再次发送 → 必须重新聚焦。
        box.focused = true
        await settle()
        #expect(window.firstResponder === editor, "再次发送到对话应重新把焦点移回 Composer")
    }

    @Test("isFocused=false 时不抢占焦点（**回归 #803**）")
    func doesNotStealFocusWhenNotRequested() async throws {
        let box = FocusBox()
        let (window, hosting) = await host(box)
        defer { teardown(window: window, hosting: hosting) }
        _ = try #require(findEditor(in: hosting), "应找到原生编辑器")
        let other = try #require(makeOtherEditor(in: window))

        window.makeFirstResponder(other)
        box.focused = false
        await settle()
        // 多轮刷新（模拟其它 binding 变化触发的 updateNSView）不得把焦点抢回。
        await settle()
        #expect(window.firstResponder === other, "未请求聚焦时不得从代码编辑器抢回焦点")
    }

    // MARK: - 夹具

    private func host(_ box: FocusBox) async -> (window: NSWindow, hosting: NSHostingView<AnyView>) {
        let hosting = NSHostingView(rootView: AnyView(FocusHost(box: box).frame(width: 480, height: 120)))
        hosting.frame = NSRect(x: 0, y: 0, width: 480, height: 120)
        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView?.addSubview(hosting)
        window.makeKeyAndOrderFront(nil)
        window.layoutIfNeeded()
        await settle()
        return (window, hosting)
    }

    /// 代码编辑器替身：一个直接接受第一响应者的普通视图，挂到同一 window。
    /// 不用 NSTextField——它编辑时 window.firstResponder 会变成共享 field editor，
    /// 而非该控件本身，无法用 `===` 稳定断言。
    private func makeOtherEditor(in window: NSWindow) -> OtherResponder? {
        let view = OtherResponder(frame: NSRect(x: 0, y: 0, width: 120, height: 24))
        window.contentView?.addSubview(view)
        return view
    }

    private func teardown(window: NSWindow, hosting: NSHostingView<AnyView>) {
        hosting.removeFromSuperview()
        window.orderOut(nil)
    }

    /// 让出主 actor 若干轮，给 SwiftUI/AppKit 完成 makeNSView + updateNSView 的机会。
    private func settle() async {
        for _ in 0..<20 {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    private func findEditor(in view: NSView) -> EditorTextView? {
        if let editor = view as? EditorTextView { return editor }
        for subview in view.subviews {
            if let editor = findEditor(in: subview) { return editor }
        }
        return nil
    }
}

/// 用 @Published 持有焦点状态：binding 的 get 读它、set 写它，变更触发 SwiftUI
/// 在同一个协调器上重跑 updateNSView（而不是重建视图），从而验证边沿跟踪。
@MainActor
private final class FocusBox: ObservableObject {
    @Published var focused = false
}

private struct FocusHost: View {
    @ObservedObject var box: FocusBox
    var body: some View {
        ChatInputEditorView(
            text: .constant(""),
            height: .constant(ChatInputEditorView.minHeight),
            onSubmit: {},
            isFocused: Binding(get: { box.focused }, set: { box.focused = $0 }),
            cursorPosition: .constant(0),
            isImageDragHovering: .constant(false)
        )
    }
}

/// 直接接受第一响应者的普通视图，作为「代码编辑器」替身。
private final class OtherResponder: NSView {
    override var acceptsFirstResponder: Bool { true }
}