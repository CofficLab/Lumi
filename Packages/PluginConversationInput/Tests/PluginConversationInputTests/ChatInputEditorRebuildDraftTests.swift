import AppKit
import SwiftUI
import Testing
@testable import PluginConversationInput

/// 隐藏再恢复聊天区后，未发送的草稿必须保留。
///
/// ## 回归背景（#601，真实用户缺陷）
///
/// 终端、数据库管理等插件通过 `ChatSectionProviding.setVisible(false/true)`
/// 移除并重建聊天输入区。重建时 SwiftUI 调 `makeNSView` 新建一个**空的**
/// `EditorTextView`，但 binding 里仍持有用户未发送的草稿。
///
/// 旧实现没有用 binding 初始化编辑器，协调器的 `lastSyncedBindingText` 又是
/// `nil`，于是首次 `updateNSView` 把「空编辑器 ≠ 非空 binding」误判成
/// 「编辑器侧产生了 binding 不知情的新内容」，调 `publishEditorTextUp("")`
/// 把空串回写 binding —— 草稿被静默清空。
///
/// 修复：`makeNSView` 用 binding 文本初始化编辑器，并把这次下发记入协调器
/// （`noteBindingTextPushedDown`），首次刷新两边一致，不再误上报。
///
/// - Important: 本测试在真实 `NSHostingView` 里渲染生产组件，跑的是真正的
///   `makeNSView` + `updateNSView`。settling 用 `await` 让出主 actor，而不是
///   `RunLoop.main.run` 同步阻塞——后者会饿死同包内基于 2s 轮询的异步用例。
@MainActor
@Suite("ChatInputEditorView 重建保留草稿")
struct ChatInputEditorRebuildDraftTests {

    @Test("重建输入框时用 binding 草稿初始化编辑器，首次刷新不清空草稿")
    func rebuiltEditorInitializesFromBindingAndKeepsDraft() async throws {
        let box = DraftBox(text: "draft")
        let (window, hosting) = await host(makeView(box: box))
        defer { teardown(window: window, hosting: hosting) }

        let editor = try #require(findEditor(in: hosting), "应找到原生编辑器")
        #expect(editor.string == "draft", "重建后的编辑器应显示 binding 里的草稿")
        #expect(box.text == "draft", "首次 updateNSView 不得把空编辑器回写清空草稿")
    }

    @Test("隐藏再恢复聊天区后草稿仍在")
    func hideAndReshowPreservesDraft() async throws {
        let box = DraftBox(text: "draft")

        // 第一次渲染（聊天区可见）。
        let first = await host(makeView(box: box))
        #expect(box.text == "draft")
        // 隐藏：移除宿主视图，编辑器随之 dismantle。
        teardown(window: first.window, hosting: first.hosting)
        await settle()

        // 恢复：用同一个 binding 重建聊天区，触发全新的 makeNSView。
        let second = await host(makeView(box: box))
        defer { teardown(window: second.window, hosting: second.hosting) }

        let editor = try #require(findEditor(in: second.hosting), "恢复后应找到原生编辑器")
        #expect(editor.string == "draft", "恢复后的编辑器应重新显示草稿")
        #expect(box.text == "draft", "隐藏再恢复不得清空未发送的草稿")
    }

    // MARK: - 夹具

    private func makeView(box: DraftBox) -> ChatInputEditorView {
        var height = ChatInputEditorView.minHeight
        var focused = false
        var cursor = 0
        var dragging = false
        return ChatInputEditorView(
            text: Binding(get: { box.text }, set: { box.text = $0 }),
            height: Binding(get: { height }, set: { height = $0 }),
            onSubmit: {},
            isFocused: Binding(get: { focused }, set: { focused = $0 }),
            cursorPosition: Binding(get: { cursor }, set: { cursor = $0 }),
            isImageDragHovering: Binding(get: { dragging }, set: { dragging = $0 })
        )
    }

    private func host(_ view: ChatInputEditorView) async -> (window: NSWindow, hosting: NSHostingView<AnyView>) {
        let hosting = NSHostingView(rootView: AnyView(view.frame(width: 480, height: 120)))
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

/// 用引用类型持有草稿，让 Binding 的 get/set 闭包可以跨多次重建共享同一份状态。
private final class DraftBox {
    var text: String
    init(text: String) { self.text = text }
}