import Foundation
import LumiUI
import SwiftUI
import Testing
@testable import PluginMessageRenderer

/// V5（ChatGPT）渲染层的无障碍与 Reduced Motion 契约测试。
///
/// 基准是 V5 方案第 1.4 节：
/// - Reduced Motion 下关闭 shimmer、淡入和位移动画；
/// - 信息本身不能依赖动画表达；
/// - 图标按钮必须有本地化 label 与稳定 identifier。
@Suite("V5 渲染层无障碍契约")
struct ChatGPTRendererAccessibilityTests {

    // MARK: - Reduced Motion

    @Test("Reduced Motion 下关闭淡入动画")
    func reducedMotionDisablesFade() {
        #expect(ChatGPTRendererMotion.allowsFadeAnimation(
            preference: LumiMotionPreference(reduceMotion: true)
        ) == false)
        #expect(ChatGPTRendererMotion.allowsFadeAnimation(
            preference: LumiMotionPreference(reduceMotion: false)
        ) == true)
    }

    @Test("Reduced Motion 下关闭位移与 shimmer")
    func reducedMotionDisablesShiftAndShimmer() {
        #expect(ChatGPTRendererMotion.allowsShiftAnimation(
            preference: LumiMotionPreference(reduceMotion: true)
        ) == false)
        #expect(ChatGPTRendererMotion.allowsShimmer(
            preference: LumiMotionPreference(reduceMotion: true)
        ) == false)
        #expect(ChatGPTRendererMotion.allowsShiftAnimation(
            preference: LumiMotionPreference(reduceMotion: false)
        ) == true)
    }

    @Test("全局禁用动画时同样关闭")
    func globallyDisabledAnimationsAlsoOff() {
        let disabled = LumiMotionPreference(disableAnimations: true)
        #expect(ChatGPTRendererMotion.allowsFadeAnimation(preference: disabled) == false)
        #expect(ChatGPTRendererMotion.allowsShiftAnimation(preference: disabled) == false)
        #expect(ChatGPTRendererMotion.allowsShimmer(preference: disabled) == false)
    }

    // MARK: - 稳定标识符

    @Test("渲染层标识符稳定且带 chatgpt 前缀")
    func rendererIdentifiersAreStable() {
        #expect(ChatGPTRendererAccessibilityIdentifiers.userBubble == "lumi.message.chatgpt.user-bubble")
        #expect(ChatGPTRendererAccessibilityIdentifiers.userCopyButton == "lumi.message.chatgpt.user-copy")
        #expect(ChatGPTRendererAccessibilityIdentifiers.userResendButton == "lumi.message.chatgpt.user-resend")
        #expect(ChatGPTRendererAccessibilityIdentifiers.assistantBody == "lumi.message.chatgpt.assistant-body")
        #expect(ChatGPTRendererAccessibilityIdentifiers.turnCopyButton == "lumi.message.chatgpt.turn-copy")
        #expect(ChatGPTRendererAccessibilityIdentifiers.reasoningToggle == "lumi.message.chatgpt.reasoning-toggle")
        #expect(ChatGPTRendererAccessibilityIdentifiers.workHistoryToggle == "lumi.message.chatgpt.work-history-toggle")
        #expect(ChatGPTRendererAccessibilityIdentifiers.timelineMarker == "lumi.message.chatgpt.timeline-marker")
        #expect(ChatGPTRendererAccessibilityIdentifiers.errorContent == "lumi.message.chatgpt.error-content")
        #expect(ChatGPTRendererAccessibilityIdentifiers.errorRetryButton == "lumi.message.chatgpt.error-retry")
    }

    @Test("渲染层与列表层标识符前缀不同")
    func rendererAndListPrefixesDiffer() {
        // 列表层用 `lumi.message-list.chatgpt.*`，渲染层用 `lumi.message.chatgpt.*`。
        #expect(ChatGPTRendererAccessibilityIdentifiers.userBubble.hasPrefix("lumi.message.chatgpt."))
        #expect(!ChatGPTRendererAccessibilityIdentifiers.userBubble.hasPrefix("lumi.message-list.chatgpt."))
    }

    // MARK: - 流式语义

    @Test("流式不逐 token 发 announcement")
    func streamingDoesNotAnnouncePerToken() {
        // - Important: VoiceOver 不应因每个 token 播报一次。
        //   V5 的流式正文没有 live region 标记，也没有逐 token 的
        //   accessibilityValue 更新 —— 状态只由「生成中 / 已完成」表达一次。
        #expect(ChatGPTAssistantTextStyle.hasStreamingCursor == false)
        #expect(ChatGPTAssistantTextStyle.hasStreamingFadeIn == false)
        #expect(ChatGPTAssistantTextStyle.hasStreamingPulse == false)
    }

    @Test("reasoning 完成时只做一次语义更新")
    func reasoningCompletionUpdatesSemanticsOnce() {
        // 用户显式选择优先于「完成时自动收起」——
        // 因此完成事件不会反复翻转展开状态。
        var state = ChatGPTReasoningCollapseState()
        state.setExpanded(true)
        state.applyAutoCollapseOnCompletion()
        #expect(state.isExpanded)

        state.setExpanded(false)
        state.applyAutoCollapseOnCompletion()
        #expect(!state.isExpanded)
    }
}
