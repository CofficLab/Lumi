import CoreGraphics
import Foundation
import LumiLocalizationKit
import LumiUI
import ProviderMessage
import SwiftUI

/// V5（ChatGPT）timeline marker 的呈现规格。
///
/// 基准是 V5 方案第 2.6 节：
/// - compact、model switch、retry 等 timeline event 使用**低强调、居中的小 marker**，
///   不渲染成 assistant 正文；
/// - turn-completed 不留下多余气泡或大间距；
/// - 所有内容都来自**真实**的 metadata 字段；字段缺失时宁可不显示，也不伪造。
enum ChatGPTTimelineMarkerStyle {

    // MARK: - 呈现形态

    /// timeline marker **没有**气泡。
    static let hasBubble = false

    /// timeline marker **没有**头像。
    static let hasAvatar = false

    /// timeline marker **没有**发送者名称。
    static let hasSenderName = false

    /// timeline marker **不使用**旧的 V3 message chrome。
    static let usesLegacyMessageChrome = false

    /// timeline marker **不占用**大间距。
    static let hasLargeVerticalSpacing = false

    /// timeline marker 的垂直间距。
    static let verticalSpacing: CGFloat = 0

    /// 标记字号。
    static let textFontSize: CGFloat = 12

    /// 图标尺寸。
    static let iconSize: CGFloat = 11

    // MARK: - 可见性

    /// 是否渲染 marker。
    ///
    /// - Important: 空正文且无元数据的消息不渲染 —— 空壳会留下无意义的行。
    static func shouldRender(message: Message) -> Bool {
        if !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        // 正文为空但携带真实事件元数据时仍要显示。
        return !message.metadata.isEmpty
    }

    // MARK: - model-switched

    /// 切换到的模型名；没有真实字段时为 nil。
    static func modelName(for message: Message) -> String? {
        guard let name = message.metadata[MessageTimelineEvent.modelSwitchedToModelNameKey],
              !name.isEmpty
        else { return nil }
        return name
    }

    // MARK: - goal

    /// 真实的 goal 标题列表。
    ///
    /// - Important: 没有真实字段时返回空数组 —— 绝不伪造进度。
    static func goalTitles(for message: Message) -> [String] {
        guard let value = message.metadata[MessageTimelineEvent.goalTaskContinuationGoalTitlesKey],
              !value.isEmpty
        else { return [] }
        return value
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // MARK: - retry

    /// 真实的重试原因；没有真实字段时为 nil。
    static func retryReason(for message: Message) -> String? {
        guard let reason = message.metadata[MessageTimelineEvent.agentLoopRetryReasonKey],
              !reason.isEmpty
        else { return nil }
        return reason
    }

    // MARK: - 图标

    /// 图标：按事件类型选择，全部是系统 SF Symbol。
    static func iconName(for message: Message) -> String {
        switch message.renderKind {
        case "turn-completed": return "checkmark.circle"
        case MessageTimelineEvent.contextCompactionRenderKind:
            return "arrow.down.right.and.arrow.up.left"
        case MessageTimelineEvent.agentLoopRetryRenderKind: return "arrow.clockwise"
        case MessageTimelineEvent.goalTaskContinuationRenderKind: return "flag"
        case MessageTimelineEvent.modelSwitchedRenderKind: return "arrow.left.arrow.right"
        default: return "info.circle"
        }
    }

    // MARK: - 显示文本

    /// 显示文本：优先真实元数据，其次正文。
    static func displayText(for message: Message) -> String {
        if let modelName = modelName(for: message) {
            return modelName
        }
        if let retryReason = retryReason(for: message) {
            return retryReason
        }
        let titles = goalTitles(for: message)
        if !titles.isEmpty {
            return titles.joined(separator: "、")
        }
        if message.content == LumiChatMarkers.turnCompleted {
            return ""
        }
        return message.content
    }
}

/// V5（ChatGPT）timeline marker 视图。
///
/// - Important: 这是**系统事件**的紧凑呈现，不是助手 Markdown 气泡；
///   也不画头像、名称或旧 chrome。
struct ChatGPTTimelineMarkerView: View {
    let message: Message

    @LumiTheme private var theme

    var body: some View {
        if ChatGPTTimelineMarkerStyle.shouldRender(message: message) {
            HStack(spacing: 6) {
                Image(systemName: ChatGPTTimelineMarkerStyle.iconName(for: message))
                    .font(.system(size: ChatGPTTimelineMarkerStyle.iconSize))
                    .foregroundColor(theme.textSecondary)
                Text(ChatGPTTimelineMarkerStyle.displayText(for: message))
                    .font(.system(size: ChatGPTTimelineMarkerStyle.textFontSize))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
                Spacer(minLength: 0)
            }
            .padding(.vertical, ChatGPTTimelineMarkerStyle.verticalSpacing)
            .accessibilityIdentifier(ChatGPTRendererAccessibilityIdentifiers.timelineMarker)
            .accessibilityElement(children: .combine)
        }
    }
}
