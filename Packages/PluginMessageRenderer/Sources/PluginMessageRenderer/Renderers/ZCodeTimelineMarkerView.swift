import CoreGraphics
import Foundation
import ProviderMessage
import ProviderMessageRendering
import SwiftUI

/// V4（ZCode）timeline marker 的呈现规格。
///
/// 基准是 ZCode 3.15.1 计划第 2.1 与第 2.6 节：
/// - timeline marker 用于 compact/fork/goal/modelChange 等系统事件，
///   **不是**日期分隔线；
/// - turn-completed 不留下多余空气泡或大间距；
/// - context-compaction 是紧凑 timeline marker，不是助手 Markdown 气泡；
/// - agent-loop-retry 显示真实重试状态；
/// - goal-task-continuation 是真实 goal 信息 marker，不伪造进度；
/// - model-switched 有真实模型字段才显示模型名。
///
/// - Important: 所有内容都来自**真实**的 metadata 字段；
///   字段缺失时宁可不显示，也不伪造。
enum ZCodeTimelineMarkerStyle {

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

    /// 错误 marker **不**冒充工具错误样式。
    static let usesToolErrorStyling = false

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

    // MARK: - 分发

    /// 消息显式指定的 renderer id。
    ///
    /// - Important: `preferredRendererID` 仍然优先于核心 renderer；
    ///   V4 只增加核心 renderer 的 `.zcode` 分支，不改变分发顺序。
    static func preferredRendererID(_ message: Message) -> String? {
        guard let id = message.preferredRendererID, !id.isEmpty else { return nil }
        return id
    }
}

/// V4（ZCode）timeline marker 视图。
///
/// - Important: 这是**系统事件**的紧凑呈现，不是助手 Markdown 气泡；
///   也不画头像、名称或旧 chrome。
struct ZCodeTimelineMarkerView: View {
    let message: Message

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if ZCodeTimelineMarkerStyle.shouldRender(message: message) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 11))
                    .foregroundColor(palette.subtle)
                Text(displayText)
                    .font(.system(size: 12))
                    .foregroundColor(palette.subtle)
                    .lineLimit(2)
                    .textSelection(.enabled)
                Spacer(minLength: 0)
            }
            .padding(.vertical, ZCodeTimelineMarkerStyle.verticalSpacing)
            .accessibilityIdentifier(ZCodeRendererAccessibilityIdentifiers.timelineMarker)
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - 私有

    private var palette: ZCodeMessageAppearance.Palette {
        ZCodeMessageAppearance.palette(for: colorScheme)
    }

    /// 图标：按事件类型选择，全部是系统 SF Symbol。
    private var iconName: String {
        switch message.renderKind {
        case "turn-completed": return "checkmark.circle"
        case "context-compaction": return "arrow.down.right.and.arrow.up.left"
        case "agent-loop-retry": return "arrow.clockwise"
        case "goal-task-continuation": return "flag"
        case "model-switched": return "arrow.left.arrow.right"
        default: return "info.circle"
        }
    }

    /// 显示文本：优先真实元数据，其次正文。
    private var displayText: String {
        if let modelName = ZCodeTimelineMarkerStyle.modelName(for: message) {
            return modelName
        }
        if let retryReason = ZCodeTimelineMarkerStyle.retryReason(for: message) {
            return retryReason
        }
        let titles = ZCodeTimelineMarkerStyle.goalTitles(for: message)
        if !titles.isEmpty {
            return titles.joined(separator: "、")
        }
        if message.content == LumiChatMarkers.turnCompleted {
            return ""
        }
        return message.content
    }
}
