import AppKit
import CoreGraphics
import Foundation
import KitMarkdown
import LumiLocalizationKit
import LumiUI
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import SwiftUI

/// V5（ChatGPT）助手正文视图。
///
/// 与 V1–V4 的差异：
/// - 无气泡、无卡片背景、无头像、无名称、无默认模型名与时间戳，占满阅读列；
/// - 不显示旧 header、info popover；
/// - 轮尾操作栏（整轮复制）只挂在轮尾助手正文上，
///   且需要整个 turn 处于 hover 才显示；
/// - reasoning 与工具工作保持可见且可访问。
///
/// - Important: 复用真实复制能力，不新增 fake retry / like / fork。
/// - Important: 成功回复**不**显示「重新生成」；重试只由错误视图按
///   真实 `canRetryTurn` 判定提供。
struct ChatGPTAssistantMessageView: View {
    let capability: any MessageRendererCapability
    @ObservedObject var stateViewModel: MessageRendererStateViewModel
    let message: Message
    let verbosity: ResponseVerbosity

    @Environment(\.messageTurnPresentation) private var turnContext
    @Environment(\.messageTurnIsHovered) private var isTurnHovered
    @LumiTheme private var theme

    /// 复制反馈状态。
    @State private var copyState = ChatGPTCopyFeedbackState()

    /// 动效偏好：Reduced Motion 或全局禁用动画时关闭操作栏淡入淡出。
    @LumiMotionPreferenceReader private var motionPreference

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let reasoning, ChatGPTReasoningStyle.shouldRender(text: reasoning, isStreaming: isRunning) {
                ChatGPTReasoningView(
                    text: reasoning,
                    isStreaming: isRunning,
                    durationMilliseconds: message.streamingDurationMs.map { Int($0) }
                )
                .padding(.bottom, ChatGPTAssistantTextStyle.workItemSpacing)
            }

            if hasVisibleContent {
                // Important: 标识符必须挂在**外层容器**上，不能挂在
                //   `MarkdownBlockRenderer` 上 —— 后者会渲染多个 block，
                //   修饰符被每个 block 继承，于是 AX 树里出现 N 个同名元素。
                VStack(alignment: .leading, spacing: 0) {
                    MarkdownBlockRenderer(
                        markdown: message.content,
                        theme: ChatMarkdownTheme.makeChatGPT(from: theme)
                    )
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .font(.system(size: ChatGPTAssistantTextStyle.fontSize))
                    .lineSpacing(ChatGPTAssistantTextStyle.lineSpacing)
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(ChatGPTRendererAccessibilityIdentifiers.assistantBody)
            }

            if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                Group {
                    if ChatGPTToolWorkHistoryStyle.shouldGroup(tools: toolCalls) {
                        ChatGPTToolWorkHistoryView(
                            capability: capability,
                            stateViewModel: stateViewModel,
                            message: message,
                            verbosity: verbosity,
                            toolCalls: toolCalls
                        )
                    } else {
                        // 单工具或非分组家族：保持独立工具行。
                        ToolCallRowsView(
                            capability: capability,
                            stateViewModel: stateViewModel,
                            message: message,
                            verbosity: verbosity,
                            allowsCustomToolRenderers: true,
                            originalVerbosity: verbosity
                        )
                    }
                }
                .padding(.top, hasVisibleContent ? ChatGPTAssistantTextStyle.workItemSpacing : 0)
            }

            actionBar
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 正文

    /// reasoning 正文。
    private var reasoning: String? {
        guard let content = message.reasoningContent,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return content
    }

    /// 本轮是否仍在运行中。
    private var isRunning: Bool {
        turnContext?.isRunning ?? false
    }

    /// 内容是否含可见字符。
    private var hasVisibleContent: Bool {
        message.content.contains { !$0.isWhitespace && !$0.isNewline }
    }

    // MARK: - 轮尾操作栏

    /// 轮尾操作栏。
    ///
    /// - Important: **常驻占位**，只在不显示时把透明度降为 0。
    ///   条件插入会让操作栏一出现就多出 32pt，下一轮内容被顶下去 ——
    ///   这正是「hover 一下底下就跳」的根因。
    ///
    ///   占位与否只看「轮尾 + 已完成 + 有内容」（与 hover 无关），
    ///   hover 只切换透明度。行高因此恒定。
    @ViewBuilder
    private var actionBar: some View {
        if ChatGPTAssistantTextStyle.shouldReserveActionBarSlot(context: turnContext) {
            HStack(spacing: 8) {
                if let copyText = turnContext?.assistantCopyText,
                   ChatGPTAssistantTextStyle.shouldShowCopyButton(copyText: copyText) {
                    copyButton(text: copyText)
                }
            }
            .padding(.top, 8)
            // Important: 透明时**不能**用 `hidden()` / `removeFromTree` ——
            //   那会把按钮从 AX 树里摘掉，键盘用户与 UI 测试都拿不到。
            //   正确做法是保留在树上、只改透明度。
            .frame(
                minHeight: ChatGPTAssistantTextStyle.actionBarSlotHeight - 8,
                alignment: .leading
            )
            .opacity(isActionBarVisible ? 1 : 0)
            // Important: Reduced Motion 下**不挂** animation —— 挂 nil 动画
            //   仍会参与 SwiftUI 的差异计算。改为按偏好直接给出动画值。
            .animation(
                ChatGPTRendererMotion.allowsFadeAnimation(preference: motionPreference)
                    ? .easeOut(duration: ChatGPTAssistantTextStyle.actionBarFadeDuration)
                    : nil,
                value: isActionBarVisible
            )
            // Important: 操作栏**容器**不能挂 `accessibilityIdentifier`。
            //   SwiftUI 会把标识符向下传播给子元素，于是 `turn-copy`
            //   被覆盖成 `turn-action-bar`，UI 测试再也定位不到按钮。
        }
    }

    /// 操作栏当前是否可见（占位已在 `actionBar` 里处理）。
    private var isActionBarVisible: Bool {
        ChatGPTAssistantTextStyle.shouldShowActionBar(context: turnContext, isHovered: isTurnHovered)
    }

    private func copyButton(text: String) -> some View {
        Button {
            LumiPasteboard.copyString(text)
            copyState.markCopied()
        } label: {
            Image(systemName: copyState.isCopied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary)
                .frame(
                    width: ChatGPTAssistantTextStyle.actionButtonSize,
                    height: ChatGPTAssistantTextStyle.actionButtonSize
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(ChatGPTRendererAccessibilityIdentifiers.turnCopyButton)
        .accessibilityLabel(pluginLocalization.string("Copy"))
        .help(pluginLocalization.string("Copy"))
    }
}

/// 复制按钮的反馈状态机。
///
/// - Note: 用**注入时间**而不是 `sleep`，测试因此不需要真的等 1.2 秒。
struct ChatGPTCopyFeedbackState: Equatable {
    /// 是否处于「已复制」反馈态。
    private(set) var isCopied = false
    /// 反馈开始的时间戳。
    private var copiedAt: TimeInterval?

    /// 标记为已复制。
    mutating func markCopied(at time: TimeInterval = 0) {
        isCopied = true
        copiedAt = time
    }

    /// 推进时间；到达反馈时长后恢复。
    mutating func tick(elapsed: TimeInterval) {
        guard isCopied, let copiedAt else { return }
        guard elapsed - copiedAt >= ChatGPTAssistantTextStyle.copyFeedbackDuration else { return }
        isCopied = false
        self.copiedAt = nil
    }
}

/// 独立的无障碍标记元素。
///
/// - Important: 标识符**不能**挂在折叠块容器上：SwiftUI 会把它向下传播给
///   子元素，展开按钮的标识符就被覆盖。「这一块存在」改由**独立的标记元素**表达。
struct ChatGPTAccessibilityMarker: View {
    let identifier: String

    var body: some View {
        Text(" ")
            .font(.system(size: 1))
            .frame(width: 1, height: 1)
            .accessibilityIdentifier(identifier)
            .allowsHitTesting(false)
    }
}
