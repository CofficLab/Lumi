import AppKit
import SwiftUI
import Testing
@testable import PluginConversationInput

/// 高度上报必须对亚像素抖动免疫，但真实换行仍然生效。
///
/// ## 问题背景
///
/// `updateHeight` 每帧测量一次 `layoutManager.usedRect(for:)`，然后经
/// `scheduleHeightBindingUpdate` 写 `height` binding。`ComposerView` 用
/// `.frame(height: viewModel.inputHeight)` 消费它，而这个输入框是
/// `bottomFixed` 的——高度一变，整条消息列表跟着重排。
///
/// AppKit 的文本布局返回值带有亚像素误差：`usedRect(for:)` 在同一行内容下
/// 相邻两次调用可能相差零点几个点。若把这种抖动原样上报，SwiftUI 就会在
/// 「64.0 → 64.5 → 64.0」之间反复改 frame，每个字符都触发一次全聊天区重排。
///
/// 这里锁定的口径：**行数**变了必须上报，**行内亚像素抖动**必须吞掉。
@MainActor
@Suite("编辑器高度上报的抖动抑制")
struct ChatInputEditorHeightStabilityTests {

    @Test("同一行内容下的亚像素抖动不产生新高度")
    func subpixelJitterIsSuppressed() {
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)

        var height = ChatInputEditorView.minHeight

        let view = ChatInputEditorView(
            text: Binding(
                get: { viewModel.text },
                set: { viewModel.setText($0) }
            ),
            height: Binding(get: { height }, set: { height = $0 }),
            onSubmit: {},
            isFocused: .constant(false),
            cursorPosition: .constant(0),
            isImageDragHovering: .constant(false)
        )
        let coordinator = view.makeCoordinator()

        // 模拟同一行内容被反复测量出微小差异的情况。
        let first = ChatInputEditorView.measuredHeight(
            usedRectHeight: 56.0,
            insetHeight: 8,
            availableWidth: 640
        )
        #expect(first == ChatInputEditorView.minHeight)

        // 直接验证稳定化纯函数的行为。
        let baseline = ChatInputEditorView.stabilizedHeight(
            first,
            previous: ChatInputEditorView.minHeight,
            lineHeight: 19
        )
        #expect(baseline == ChatInputEditorView.minHeight)

        // 0.5pt 的抖动应被吸收。
        let jittered = ChatInputEditorView.stabilizedHeight(
            ChatInputEditorView.minHeight + 0.5,
            previous: ChatInputEditorView.minHeight,
            lineHeight: 19
        )
        #expect(
            jittered == ChatInputEditorView.minHeight,
            "0.5pt 抖动应被吞掉，实际得到 \(jittered)"
        )

        _ = coordinator
    }

    @Test("行数变化仍然上报")
    func lineCountChangeIsReported() {
        // 19pt 一行：63 → 82 → 101，各多一行，必须与行数对齐。
        let lineHeight: CGFloat = 19

        let twoLines = ChatInputEditorView.stabilizedHeight(82, previous: 63, lineHeight: lineHeight)
        let threeLines = ChatInputEditorView.stabilizedHeight(101, previous: twoLines, lineHeight: lineHeight)

        #expect(twoLines == 82, "多一行应上报，得到 \(twoLines)")
        #expect(threeLines == 101, "再多一行应上报，得到 \(threeLines)")
    }

    @Test("归位到最小高度不会被误判为抖动")
    func returnToMinHeightIsNotSwallowed() {
        // 发送清空后高度从 120 回落到 64，行数确实变了，必须上报。
        let resolved = ChatInputEditorView.stabilizedHeight(
            ChatInputEditorView.minHeight,
            previous: 120,
            lineHeight: 19
        )
        #expect(resolved == ChatInputEditorView.minHeight)
    }

    @Test("非法输入返回原值不做归一化")
    func invalidHeightFallsBackToMeasured() {
        let resolved = ChatInputEditorView.stabilizedHeight(
            nil,
            previous: 64,
            lineHeight: 19
        )
        #expect(resolved == 64, "测量失败时沿用上一次高度，不应归零")
    }
}
