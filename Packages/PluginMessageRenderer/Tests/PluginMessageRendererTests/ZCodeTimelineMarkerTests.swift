import Foundation
import ProviderMessage
import ProviderMessageRendering
import Testing
@testable import PluginMessageRenderer

/// V4（ZCode）timeline marker 契约测试。
///
/// 基准是 ZCode 3.15.1 计划第 2.1 与第 2.6 节：
/// - timeline marker 用于 compact/fork/goal/modelChange 等系统事件，
///   **不是**日期分隔线；
/// - turn-completed 不留下多余空气泡或大间距；
/// - context-compaction 是紧凑 timeline marker，不是助手 Markdown 气泡；
/// - agent-loop-retry 显示真实重试状态；只有 capability 允许时显示真实 retry；
/// - goal-task-continuation 是真实 goal 信息 marker，不伪造进度；
/// - model-switched 有真实模型字段才显示模型名；
/// - status/error/system/default：无头像、无旧 V3 chrome；
///   错误可读但不冒充工具错误样式；
/// - preferredRendererID 与第三方 renderer 分发顺序不变。
@Suite("ZCode timeline marker")
struct ZCodeTimelineMarkerTests {

    // MARK: - 可见性

    @Test("空正文且无元数据的事件不渲染 marker")
    func emptyEventIsHidden() {
        let message = Message(
            conversationID: UUID(),
            role: .status,
            content: ""
        )

        #expect(ZCodeTimelineMarkerStyle.shouldRender(message: message) == false)
    }

    @Test("有正文的事件渲染 marker")
    func eventWithContentIsRendered() {
        let message = Message(
            conversationID: UUID(),
            role: .status,
            content: "正在处理"
        )

        #expect(ZCodeTimelineMarkerStyle.shouldRender(message: message))
    }

    @Test("turn-completed 是 timeline marker 而不是气泡")
    func turnCompletedIsMarkerNotBubble() {
        let message = Message(
            conversationID: UUID(),
            role: .assistant,
            content: LumiChatMarkers.turnCompleted
        )

        // 不画空气泡。
        #expect(ZCodeTimelineMarkerStyle.hasBubble == false)
        // 但仍作为一个紧凑 marker 出现（内容非空）。
        #expect(ZCodeTimelineMarkerStyle.shouldRender(message: message))
    }

    @Test("timeline marker 没有头像与旧 chrome")
    func markerHasNoAvatarOrLegacyChrome() {
        #expect(ZCodeTimelineMarkerStyle.hasAvatar == false)
        #expect(ZCodeTimelineMarkerStyle.hasSenderName == false)
        #expect(ZCodeTimelineMarkerStyle.usesLegacyMessageChrome == false)
    }

    @Test("timeline marker 是紧凑行，不占用大间距")
    func markerIsCompact() {
        #expect(ZCodeTimelineMarkerStyle.hasLargeVerticalSpacing == false)
        #expect(ZCodeTimelineMarkerStyle.verticalSpacing == 0)
    }

    // MARK: - model-switched

    @Test("没有真实模型字段时不显示模型名")
    func modelSwitchWithoutModelFieldHidesModelName() {
        let message = Message(
            conversationID: UUID(),
            role: .status,
            content: "切换模型"
        )

        #expect(ZCodeTimelineMarkerStyle.modelName(for: message) == nil)
    }

    @Test("有真实模型字段时显示模型名")
    func modelSwitchWithModelFieldShowsModelName() {
        var message = Message(
            conversationID: UUID(),
            role: .status,
            content: "切换模型"
        )
        message.metadata[MessageTimelineEvent.modelSwitchedToModelNameKey] = "gpt-4o"

        #expect(ZCodeTimelineMarkerStyle.modelName(for: message) == "gpt-4o")
    }

    // MARK: - goal

    @Test("没有真实 goal 信息时不伪造进度")
    func goalWithoutInfoDoesNotFakeProgress() {
        let message = Message(
            conversationID: UUID(),
            role: .status,
            content: "继续任务"
        )

        #expect(ZCodeTimelineMarkerStyle.goalTitles(for: message).isEmpty)
    }

    @Test("有真实 goal 字段时显示 goal 标题")
    func goalWithInfoShowsTitles() {
        var message = Message(
            conversationID: UUID(),
            role: .status,
            content: "继续任务"
        )
        message.metadata[MessageTimelineEvent.goalTaskContinuationGoalTitlesKey] = "任务 A"

        #expect(ZCodeTimelineMarkerStyle.goalTitles(for: message) == ["任务 A"])
    }

    // MARK: - retry

    @Test("没有真实重试原因时不显示重试原因")
    func retryWithoutReasonHidesReason() {
        let message = Message(
            conversationID: UUID(),
            role: .status,
            content: "重试"
        )

        #expect(ZCodeTimelineMarkerStyle.retryReason(for: message) == nil)
    }

    @Test("有真实重试原因时显示")
    func retryWithReasonShowsReason() {
        var message = Message(
            conversationID: UUID(),
            role: .status,
            content: "重试"
        )
        message.metadata[MessageTimelineEvent.agentLoopRetryReasonKey] = "网络超时"

        #expect(ZCodeTimelineMarkerStyle.retryReason(for: message) == "网络超时")
    }

    // MARK: - 错误

    @Test("错误 marker 不冒充工具错误样式")
    func errorMarkerIsNotToolErrorStyle() {
        // 错误消息使用紧凑 marker，而不是工具失败卡片。
        #expect(ZCodeTimelineMarkerStyle.usesToolErrorStyling == false)
    }

    @Test("错误内容非空时渲染 marker")
    func errorWithContentIsRendered() {
        let message = Message(
            conversationID: UUID(),
            role: .error,
            content: "请求失败"
        )

        #expect(ZCodeTimelineMarkerStyle.shouldRender(message: message))
    }

    // MARK: - 分发顺序

    @Test("preferredRendererID 仍然优先于核心 renderer")
    func preferredRendererIDStillWins() {
        var message = Message(
            conversationID: UUID(),
            role: .assistant,
            content: "内容"
        )
        message.preferredRendererID = "third-party-renderer"

        #expect(ZCodeTimelineMarkerStyle.preferredRendererID(message) == "third-party-renderer")
    }

    @Test("没有 preferredRendererID 时为 nil")
    func nilPreferredRendererID() {
        let message = Message(
            conversationID: UUID(),
            role: .assistant,
            content: "内容"
        )

        #expect(ZCodeTimelineMarkerStyle.preferredRendererID(message) == nil)
    }
}
