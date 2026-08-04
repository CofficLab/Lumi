import Foundation
import LumiKernel

/// V1「可折叠工具步骤组」折叠态摘要的纯逻辑(便于单元测试)。
///
/// 文案样式(用户选定:数量 + 总耗时):
/// - 进行中:`执行中 · 已完成 k/N`(+ 已完成部分的耗时)
/// - 全部完成:`执行了 N 个步骤 · <总耗时>`
/// - 有失败:`执行了 N 个步骤(X 失败) · <总耗时>`
enum ToolStepGroupSummary {
    static func summaryText(for summary: LumiTurnActivitySummary) -> String {
        var parts = ["执行了 \(summary.totalCount) 个步骤"]
        if summary.failedCount > 0 {
            parts[0] += "(\(summary.failedCount) 失败)"
        }
        if let duration = summary.totalDuration {
            parts.append(MessageViewHelpers.formatDuration(duration))
        }
        return parts.joined(separator: " · ")
    }

    /// 组内任一调用仍在执行 → loading;否则任一失败 → failed;否则 completed。
    static func aggregateState(for toolCalls: [LumiToolCall]) -> ToolCallResultVisualState {
        if toolCalls.contains(where: { $0.result == nil }) {
            return .loading
        }
        if toolCalls.contains(where: { $0.result?.isError == true }) {
            return .failed
        }
        return .completed
    }

    /// 折叠态摘要文案。
    static func summaryText(for toolCalls: [LumiToolCall]) -> String {
        let total = toolCalls.count
        let finished = toolCalls.filter { $0.result != nil }.count
        let state = aggregateState(for: toolCalls)

        if state == .loading {
            let progress = "执行中 · 已完成 \(finished)/\(total)"
            if let duration = totalDuration(for: toolCalls) {
                return "\(progress) · \(MessageViewHelpers.formatDuration(duration))"
            }
            return progress
        }

        var parts = ["执行了 \(total) 个步骤"]
        let failed = toolCalls.filter { $0.result?.isError == true }.count
        if failed > 0 {
            parts[0] = "执行了 \(total) 个步骤(\(failed) 失败)"
        }
        if let duration = totalDuration(for: toolCalls) {
            parts.append(MessageViewHelpers.formatDuration(duration))
        }
        return parts.joined(separator: " · ")
    }

    /// 已完成工具的耗时之和(进行中仅统计已完成的部分);无任何耗时数据时为 nil。
    static func totalDuration(for toolCalls: [LumiToolCall]) -> TimeInterval? {
        let durations = toolCalls.compactMap { $0.result?.duration }
        guard !durations.isEmpty else { return nil }
        return durations.reduce(0, +)
    }
}
