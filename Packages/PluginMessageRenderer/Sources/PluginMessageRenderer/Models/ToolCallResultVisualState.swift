import KitAgentTool
import KernelCore
import KitLocalization
import LumiUI
import KitMarkdown
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageSender
import ProviderToolManager
import Foundation
import SwiftUI

enum ToolCallResultVisualState: Equatable {
    case loading
    case failed
    case completed

    init(result: MessageToolResult?, isLoading: Bool) {
        if isLoading {
            self = .loading
        } else if result?.isError == true {
            self = .failed
        } else {
            self = .completed
        }
    }

    var systemImage: String {
        switch self {
        case .loading: "hourglass"
        case .failed: "exclamationmark.triangle.fill"
        case .completed: "doc.text.magnifyingglass"
        }
    }

    var isFailure: Bool {
        self == .failed
    }
}

/// Tool Job 在消息行中的显示状态。
enum ToolJobVisualState: Equatable {
    case queued
    case running
    case waitingForUser
    case completed
    case failed
    case cancelled
    case timedOut

    init(status: ToolJobStatus) {
        switch status {
        case .queued: self = .queued
        case .running: self = .running
        case .waitingForUser: self = .waitingForUser
        case .completed: self = .completed
        case .failed: self = .failed
        case .cancelled: self = .cancelled
        case .timedOut: self = .timedOut
        }
    }

    var title: String {
        switch self {
        case .queued: "排队中"
        case .running: "执行中"
        case .waitingForUser: "等待用户"
        case .completed: "已完成"
        case .failed: "失败"
        case .cancelled: "已停止"
        case .timedOut: "已超时"
        }
    }

    var isFailure: Bool {
        self == .failed || self == .timedOut
    }
}

/// 将 ToolJob 转成可直接交给 SwiftUI 的纯值。
struct ToolJobActivityProjection: Equatable {
    let state: ToolJobVisualState
    let title: String
    let duration: TimeInterval
    let progressText: String?
    let outputTail: String
    let canStop: Bool

    init(job: ToolJob, now: Date = Date()) {
        state = ToolJobVisualState(status: job.status)
        title = job.toolCall.displayDescription ?? job.toolCall.name
        let start = job.startedAt ?? job.createdAt
        let end = job.completedAt ?? now
        duration = max(0, end.timeIntervalSince(start))
        progressText = Self.progressText(for: job.latestProgress)
        outputTail = job.latestOutput
        canStop = !job.status.isTerminal
    }

    private static func progressText(for progress: ToolJobProgress?) -> String? {
        guard let progress else { return nil }
        if let completed = progress.completed, let total = progress.total {
            return "\(progress.message) · \(completed)/\(total)"
        }
        return progress.message.isEmpty ? nil : progress.message
    }
}
