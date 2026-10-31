import AppKit
import ProviderMessageSender
import SwiftUI
import Testing
@testable import PluginConversationInput

/// 回车发送后输入框必须清空。
///
/// ## 回归背景（真实用户缺陷）
///
/// 用户在输入框打字 → 回车 → 消息已发出，但**输入框里的文字仍然留在原地**。
/// 消息确实提交了，所以问题不在发送链路，而在「清空草稿」这一步被编辑器内容
/// 顶了回去。
///
/// 复现链路（每一步都可在下面对应断言里看到）：
///
/// 1. 用户逐字输入，`textDidChange` → `publishCommittedText` 把文本上报给 binding。
///    此时 binding 与编辑器内容一致，**但协调器没有留下任何「这段内容我已经
///    上报过」的记录**。
/// 2. 回车 → `submitFromEnter` → `ViewModel.send()` 把 `capability.text` 置空并
///    `refresh()`，binding 变成 `""`。
/// 3. SwiftUI 用新的 binding 调 `updateNSView`。编辑器仍持有旧文本，于是
///    `textChanged == true`，接着用 `shouldPublishEditorTextUp` 判定差异方向。
///    由于第 1 步没留下记录，`lastSyncedBindingText` 为 `nil`，判定返回
///    `true` —— 把「binding 被清空」误判为「编辑器有 binding 不知道的新内容」。
/// 4. `publishEditorTextUp` 把旧文本**写回 binding**，输入框因此停在原地。
///
/// 关键点：第 1 步的「上报」和第 4 步的「上报」在代码里长得一模一样，
/// 只有「此前是否已经上报过同样的内容」能区分二者。
@MainActor
@Suite("ChatInputEditorView 发送后清空")
struct ChatInputEditorSendClearTests {

    @Test("逐键上报过的编辑器内容不会在发送清空后被回灌")
    func editorTextIsNotRepublishedAfterSendClearsDraft() {
        let capability = SendActionBarTestCapability()
        capability.commit = MessageSendCommit(
            conversationID: UUID(),
            userMessageID: UUID()
        )
        let viewModel = ConversationInputViewModel(capability: capability)

        var height = ChatInputEditorView.minHeight
        var focused = true
        var cursor = 0
        var dragging = false

        let view = ChatInputEditorView(
            text: Binding(
                get: { viewModel.text },
                set: { viewModel.setText($0) }
            ),
            height: Binding(get: { height }, set: { height = $0 }),
            onSubmit: { viewModel.send() },
            onEnter: { viewModel.send() },
            isFocused: Binding(get: { focused }, set: { focused = $0 }),
            cursorPosition: Binding(get: { cursor }, set: { cursor = $0 }),
            isImageDragHovering: Binding(get: { dragging }, set: { dragging = $0 })
        )
        let coordinator = view.makeCoordinator()
        let textView = PlainTextTestView()
        coordinator.attach(to: textView)

        // 1. 用户逐字输入：走 delegate 的正常上报路径。
        textView.string = "继续"
        textView.setSelectedRange(NSRange(location: 2, length: 0))
        coordinator.textDidChange(
            Notification(name: NSText.didChangeNotification, object: textView)
        )
        #expect(viewModel.text == "继续", "输入应上报给 binding")

        // 2. 回车发送，草稿被清空。
        coordinator.textView(
            textView,
            doCommandBy: #selector(NSResponder.insertNewline(_:))
        )
        #expect(viewModel.text.isEmpty, "发送后草稿应被清空")
        #expect(capability.commits.count == 1, "消息应已提交")

        // 3. SwiftUI 带着空 binding 刷新，`updateNSView` 需要判断差异方向。
        //    编辑器仍持有「继续」，但这段内容第 1 步已经上报过了 —— 差异来自
        //    binding 侧（被清空），必须下发清空，绝不能重新上报回 binding。
        let staleEditorText = textView.string
        #expect(
            !coordinator.shouldPublishEditorTextUp(staleEditorText),
            "已上报过的编辑器内容差异属于 binding 侧变化，应下发而非上报"
        )
    }

    @Test("真正由编辑器产生的、binding 未知的写入仍然向上上报")
    func editorOnlyContentStillPublishesUp() {
        var draft = ""
        var height = ChatInputEditorView.minHeight
        var focused = false
        var cursor = 0
        var dragging = false

        let view = ChatInputEditorView(
            text: Binding(get: { draft }, set: { draft = $0 }),
            height: Binding(get: { height }, set: { height = $0 }),
            onSubmit: {},
            isFocused: Binding(get: { focused }, set: { focused = $0 }),
            cursorPosition: Binding(get: { cursor }, set: { cursor = $0 }),
            isImageDragHovering: Binding(get: { dragging }, set: { dragging = $0 })
        )
        let coordinator = view.makeCoordinator()
        let textView = PlainTextTestView()
        coordinator.attach(to: textView)

        // 逐键上报「a」。
        textView.string = "a"
        coordinator.textDidChange(
            Notification(name: NSText.didChangeNotification, object: textView)
        )
        #expect(draft == "a")

        // 粘贴 / 语音输入 / UI 测试 typeText：一次性合成整段文本，
        // 不触发 delegate，binding 完全不知情，必须上报。
        #expect(
            coordinator.shouldPublishEditorTextUp("a pasted block"),
            "binding 未知的编辑器内容必须上报，否则输入框有内容而状态层认为为空"
        )
    }

    @Test("binding 下发后编辑器的同值差异仍按下发方向处理")
    func bindingPushedDownStillWinsForMatchingText() {
        var draft = ""
        var height = ChatInputEditorView.minHeight
        var focused = false
        var cursor = 0
        var dragging = false

        let view = ChatInputEditorView(
            text: Binding(get: { draft }, set: { draft = $0 }),
            height: Binding(get: { height }, set: { height = $0 }),
            onSubmit: {},
            isFocused: Binding(get: { focused }, set: { focused = $0 }),
            cursorPosition: Binding(get: { cursor }, set: { cursor = $0 }),
            isImageDragHovering: Binding(get: { dragging }, set: { dragging = $0 })
        )
        let coordinator = view.makeCoordinator()
        let textView = PlainTextTestView()
        coordinator.attach(to: textView)

        textView.string = "old"
        coordinator.textDidChange(
            Notification(name: NSText.didChangeNotification, object: textView)
        )
        // 外部把 binding 改成 "new" 并下发。
        coordinator.noteBindingTextPushedDown("new")

        #expect(
            !coordinator.shouldPublishEditorTextUp("new"),
            "刚下发过的内容与编辑器同值时不应再上报"
        )
        #expect(
            coordinator.shouldPublishEditorTextUp("edited by user"),
            "下发后用户又改了内容，仍应上报"
        )
    }
}

/// 不带 marked text 的普通 `NSTextView`，用于驱动协调器的差异方向判定。
///
/// 与 `ChatInputEditorViewTests.MarkedTextTestView` 同形但独立：本文件需要
/// 「非 IME 组合中」这一默认行为，不能依赖那个文件里的 private 类型。
private final class PlainTextTestView: NSTextView {
    override func hasMarkedText() -> Bool { false }
}
