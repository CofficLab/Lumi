import Foundation
import SwiftUI

/// 工具执行进度事件（结构化，不含 UI 文案）
enum ToolProgressEvent: Sendable {
    case running(
        toolName: String,
        current: Int,
        total: Int,
        elapsedSeconds: Int,
        shellStats: ToolProgressShellStats?,
        displayName: String?
    )
    case completed(toolName: String, current: Int, total: Int, elapsedSeconds: Int?, displayName: String?)
    case cancelled(toolName: String, current: Int, total: Int, displayName: String?)
    case cancelledAll
    case failed(
        toolName: String,
        current: Int,
        total: Int,
        errorSummary: String,
        displayName: String?
    )
}

/// Shell 执行增量统计（可选，仅用于 run_command）
struct ToolProgressShellStats: Sendable {
    let totalLines: Int
    let totalBytes: Int
    let latestOutputPreview: String
}

///
/// ## 初始化规则
///
/// 由 `WindowContainer` 持有，通过 `.environmentObject()` 注入。n内部被 `SendController` 用于更新会话发送状态。
/// 按会话维护一条「当前发送/流式/工具」状态
///
/// ## 初始化规则
///
/// 由 `WindowContainer` 持有并通过 `.environmentObject()` 注入。
/// 内部被 `SendController` 用于更新会话发送状态。
@MainActor
final class WindowConversationStatusVM: ObservableObject {
    @Published private(set) var statusMessageByConversationId: [UUID: ChatMessage] = [:]

    private var stableStatusRowIdByConversationId: [UUID: UUID] = [:]
    /// 当前流式响应内累积的思考文本（按会话），用于状态行展示。
    private var thinkingTextBufferByConversationId: [UUID: String] = [:]
    /// 当前流式响应内累积的正文（按会话），用于状态行展示尾部预览。
    private var streamingTextBufferByConversationId: [UUID: String] = [:]

    /// 当前会话的状态消息（若有）。
    func statusMessage(for conversationId: UUID) -> ChatMessage? {
        statusMessageByConversationId[conversationId]
    }

    func setStatus(conversationId: UUID, content: String) {
        let rowId = stableStatusRowIdByConversationId[conversationId] ?? {
            let id = UUID()
            stableStatusRowIdByConversationId[conversationId] = id
            return id
        }()
        statusMessageByConversationId[conversationId] = ChatMessage(
            id: rowId,
            role: .status,
            conversationId: conversationId,
            content: content,
            timestamp: Date(),
            isTransientStatus: true
        )
    }

    func clearStatus(conversationId: UUID) {
        statusMessageByConversationId[conversationId] = nil
        stableStatusRowIdByConversationId[conversationId] = nil
        thinkingTextBufferByConversationId[conversationId] = nil
        streamingTextBufferByConversationId[conversationId] = nil
    }

    func clearAll() {
        statusMessageByConversationId.removeAll()
        stableStatusRowIdByConversationId.removeAll()
        thinkingTextBufferByConversationId.removeAll()
        streamingTextBufferByConversationId.removeAll()
    }

    private static let statusTailBufferMax = 20
    private static let shellStatusPreviewMax = 50

    /// 换行压成空格后只保留尾部最多 `statusTailBufferMax` 字，供状态行缓冲（写入侧截断）。
    private static func normalizedStatusTailBuffer(from raw: String) -> String {
        let normalized = raw.split(whereSeparator: \.isNewline).joined(separator: " ")
        if normalized.count <= statusTailBufferMax {
            return normalized
        }
        return String(normalized.suffix(statusTailBufferMax))
    }

    /// 状态行：标题 + 缓冲全文作尾部预览；无尾部时为 `title...`。
    private static func statusLineWithTailPreview(accumulated: String, title: String) -> String {
        if accumulated.isEmpty {
            return "\(title)..."
        }
        return "\(title)：\(accumulated)"
    }

    /// Shell 最近输出预览的最终裁剪（UI 最后一层兜底）
    private static func normalizedShellPreview(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.count <= shellStatusPreviewMax {
            return trimmed
        }
        return String(trimmed.suffix(shellStatusPreviewMax))
    }

    /// 根据流式分片更新状态文案
    func applyStreamChunk(conversationId: UUID, chunk: StreamChunk) {
        // 结束
        if chunk.isDone {
            thinkingTextBufferByConversationId[conversationId] = nil
            streamingTextBufferByConversationId[conversationId] = nil
            setStatus(conversationId: conversationId, content: "结束")
            return
        }

        // 思考
        if chunk.isThinking() {
            thinkingTextBufferByConversationId[conversationId, default: ""] += chunk.getContent()
            thinkingTextBufferByConversationId[conversationId] = Self.normalizedStatusTailBuffer(
                from: thinkingTextBufferByConversationId[conversationId] ?? ""
            )
            let accumulated = thinkingTextBufferByConversationId[conversationId] ?? ""
            let line = Self.statusLineWithTailPreview(accumulated: accumulated, title: chunk.getTitle())
            setStatus(conversationId: conversationId, content: line)
            return
        }

        // 正文
        if chunk.isReceivingContent() {
            streamingTextBufferByConversationId[conversationId, default: ""] += chunk.getContent()
            streamingTextBufferByConversationId[conversationId] = Self.normalizedStatusTailBuffer(
                from: streamingTextBufferByConversationId[conversationId] ?? ""
            )
            let accumulated = streamingTextBufferByConversationId[conversationId] ?? ""
            let line = Self.statusLineWithTailPreview(accumulated: accumulated, title: chunk.getTitle())
            setStatus(conversationId: conversationId, content: line)
            return
        }

        let typeStr = chunk.getTitle()
        setStatus(conversationId: conversationId, content: "\(typeStr)...")
    }

    /// 根据工具执行事件更新状态文案
    func applyToolProgressEvent(conversationId: UUID, event: ToolProgressEvent) {
        switch event {
        case let .running(toolName, current, total, elapsedSeconds, shellStats, displayName):
            let statsSuffix: String
            if let shellStats {
                let outputPreview = Self.normalizedShellPreview(shellStats.latestOutputPreview)
                let sanitizedPreview = outputPreview.isEmpty ? "" : "，最近输出：\(outputPreview)"
                statsSuffix = "，\(shellStats.totalLines)行，\(shellStats.totalBytes)B\(sanitizedPreview)"
            } else {
                statsSuffix = ""
            }
            // 使用 displayName（LLM 传入的展示文案），否则降级为 toolName
            let showName = displayName ?? toolName
            setStatus(
                conversationId: conversationId,
                content: "\(showName)（\(max(0, elapsedSeconds))s\(statsSuffix)）"
            )
        case let .completed(toolName, current, total, elapsedSeconds, displayName):
            let showName = displayName ?? toolName
            let durationSuffix = elapsedSeconds.map { "（\(max(0, $0))s）" } ?? ""
            setStatus(
                conversationId: conversationId,
                content: "✅ \(showName)\(durationSuffix)"
            )
        case let .cancelled(toolName, _, _, displayName):
            let showName = displayName ?? toolName
            setStatus(conversationId: conversationId, content: "⛔️ \(showName) 已停止")
        case .cancelledAll:
            setStatus(conversationId: conversationId, content: "已停止执行工具")
        case let .failed(toolName, current, total, errorSummary, displayName):
            let showName = displayName ?? toolName
            setStatus(
                conversationId: conversationId,
                content: "❌ \(showName) 失败（\(errorSummary)）"
            )
        }
    }

    /// 判断指定会话是否正在进行消息发送处理
    func isMessageProcessing(for conversationId: UUID) -> Bool {
        return self.statusMessage(for: conversationId) != nil
    }
}
