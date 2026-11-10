import Foundation
import ProviderMessage
import SwiftUI
import Testing
@testable import PluginMessageRenderer

/// V5（ChatGPT）timeline marker 呈现规格测试。
///
/// 基准是 V5 方案第 2.6 节：
/// - compact / model switch / retry 等系统事件使用低强调小 marker；
/// - 内容只来自**真实**的 metadata 字段，缺失时不伪造。
@Suite("V5 timeline marker 规格")
struct ChatGPTTimelineMarkerTests {

    private func message(
        role: MessageRole = .system,
        content: String = "",
        renderKind: String? = nil,
        metadata: [String: String] = [:]
    ) -> Message {
        Message(
            id: UUID(),
            conversationID: UUID(),
            role: role,
            content: content,
            metadata: metadata,
            renderKind: renderKind
        )
    }

    @Test("有正文或真实元数据时渲染")
    func rendersWithContentOrMetadata() {
        #expect(ChatGPTTimelineMarkerStyle.shouldRender(message: message(content: "压缩完成")))
        #expect(ChatGPTTimelineMarkerStyle.shouldRender(message: message(
            metadata: [MessageTimelineEvent.modelSwitchedToModelNameKey: "gpt-5.5"]
        )))
    }

    @Test("空正文且无元数据时不渲染")
    func doesNotRenderEmptyShell() {
        #expect(!ChatGPTTimelineMarkerStyle.shouldRender(message: message()))
        #expect(!ChatGPTTimelineMarkerStyle.shouldRender(message: message(content: "   \n ")))
    }

    @Test("model-switch 显示真实模型名，缺失时不显示")
    func modelSwitchUsesRealModelName() {
        let withModel = message(
            renderKind: MessageTimelineEvent.modelSwitchedRenderKind,
            metadata: [MessageTimelineEvent.modelSwitchedToModelNameKey: "gpt-5.5"]
        )
        #expect(ChatGPTTimelineMarkerStyle.modelName(for: withModel) == "gpt-5.5")
        #expect(ChatGPTTimelineMarkerStyle.displayText(for: withModel) == "gpt-5.5")

        // 没有真实字段时返回 nil —— 绝不伪造模型名。
        let withoutModel = message(renderKind: MessageTimelineEvent.modelSwitchedRenderKind)
        #expect(ChatGPTTimelineMarkerStyle.modelName(for: withoutModel) == nil)
    }

    @Test("agent-loop-retry 显示真实重试原因")
    func retryUsesRealReason() {
        let retry = message(
            role: .status,
            renderKind: MessageTimelineEvent.agentLoopRetryRenderKind,
            metadata: [MessageTimelineEvent.agentLoopRetryReasonKey: "网络超时"]
        )
        #expect(ChatGPTTimelineMarkerStyle.retryReason(for: retry) == "网络超时")
        #expect(ChatGPTTimelineMarkerStyle.displayText(for: retry) == "网络超时")
    }

    @Test("goal 标题来自真实字段，缺失时为空数组")
    func goalTitlesRequireRealField() {
        let goal = message(
            renderKind: MessageTimelineEvent.goalTaskContinuationRenderKind,
            metadata: [
                MessageTimelineEvent.goalTaskContinuationGoalTitlesKey: "目标 A\n\n目标 B",
            ]
        )
        #expect(ChatGPTTimelineMarkerStyle.goalTitles(for: goal) == ["目标 A", "目标 B"])

        let withoutGoal = message(renderKind: MessageTimelineEvent.goalTaskContinuationRenderKind)
        #expect(ChatGPTTimelineMarkerStyle.goalTitles(for: withoutGoal).isEmpty)
    }

    @Test("图标按事件类型选择，都是系统 SF Symbol")
    func iconsAreSystemSymbols() {
        let cases: [(String, String)] = [
            ("turn-completed", "checkmark.circle"),
            (MessageTimelineEvent.contextCompactionRenderKind, "arrow.down.right.and.arrow.up.left"),
            (MessageTimelineEvent.agentLoopRetryRenderKind, "arrow.clockwise"),
            (MessageTimelineEvent.goalTaskContinuationRenderKind, "flag"),
            (MessageTimelineEvent.modelSwitchedRenderKind, "arrow.left.arrow.right"),
        ]
        for (renderKind, expectedIcon) in cases {
            let event = message(renderKind: renderKind)
            #expect(ChatGPTTimelineMarkerStyle.iconName(for: event) == expectedIcon)
        }
        // 未知事件回落到 info.circle。
        #expect(ChatGPTTimelineMarkerStyle.iconName(for: message(renderKind: "unknown")) == "info.circle")
    }

    @Test("turn-completed 标记不显示多余文本")
    func turnCompletedHasNoExtraText() {
        let completed = message(
            role: .assistant,
            content: LumiChatMarkers.turnCompleted,
            renderKind: "turn-completed"
        )
        #expect(ChatGPTTimelineMarkerStyle.displayText(for: completed).isEmpty)
    }

    @Test("timeline marker 没有气泡、头像与旧 chrome")
    func noChrome() {
        #expect(ChatGPTTimelineMarkerStyle.hasBubble == false)
        #expect(ChatGPTTimelineMarkerStyle.hasAvatar == false)
        #expect(ChatGPTTimelineMarkerStyle.hasSenderName == false)
        #expect(ChatGPTTimelineMarkerStyle.usesLegacyMessageChrome == false)
        #expect(ChatGPTTimelineMarkerStyle.hasLargeVerticalSpacing == false)
        #expect(ChatGPTTimelineMarkerStyle.verticalSpacing == 0)
    }
}
