import Foundation
import LumiLoggingKit
import os
import ProviderAgentLoop
import ProviderLifecycleHooks
import ProviderMessage

/// 后台任务完成通知的文案与消息构造。
///
/// 通知必须**留在 LLM 历史里**：Lumi 没有「只给模型看」的标志位，只有反向的
/// timeline-event 机制。因此通知写成 `role == .user` 的消息，让模型在下一轮
/// 读到「命令跑完了，结果在这里」。
///
/// metadata 让渲染器可以画紧凑卡片，而不必从正文里重新解析结构。
enum BackgroundTaskNotification {
    /// 渲染器识别用的 metadata key。
    static let metadataKey = "lumi.backgroundNotification"
    /// 卡片渲染器 ID。
    static let rendererID = "core-background-task-notification"
    /// 通知任务 ID 的 metadata key。
    static let taskIDKey = "lumi.backgroundTaskID"
    /// 通知任务状态的 metadata key。
    static let statusKey = "lumi.backgroundTaskStatus"
    /// 通知退出码的 metadata key。
    static let exitCodeKey = "lumi.backgroundTaskExitCode"
    /// 通知输出文件路径的 metadata key。
    static let outputPathKey = "lumi.backgroundTaskOutputPath"

    /// 构造完成通知消息。
    ///
    /// - Parameters:
    ///   - conversationID: 目标会话。
    ///   - taskID: 后台任务 ID。
    ///   - status: 任务结束状态。
    ///   - exitCode: 进程退出码。
    ///   - outputPath: 输出文件路径（模型用 `read_file` 读取）。
    ///   - tailExcerpt: 输出文件末尾的摘录。
    ///   - isSubagentTask: 后台子代理任务。结论本体就在摘录里，文案改成
    ///     转述而非催模型去读文件。
    static func message(
        conversationID: UUID,
        taskID: String,
        status: BackgroundTaskStatus,
        exitCode: Int32?,
        outputPath: String,
        tailExcerpt: String,
        isSubagentTask: Bool
    ) -> Message {
        let statusText = statusText(for: status)
        var content = """
        Background task \(taskID) \(statusText).
        Output file: \(outputPath)
        """
        if let exitCode {
            content += "\nExit code: \(exitCode)"
        }
        if isSubagentTask {
            if !tailExcerpt.isEmpty {
                content += "\n\nSubagent conclusion:\n\(tailExcerpt)"
            }
            content += """


            Relay the conclusion above to the user; it has not been shown to them. \
            Do not read or poll the output file, and do not re-dispatch the same task.
            """
        } else {
            if !tailExcerpt.isEmpty {
                content += "\n\nLast output:\n\(tailExcerpt)"
            }
            content += "\n\nUse read_file on the output file path to see the full output."
        }

        return Message(
            conversationID: conversationID,
            role: .user,
            content: content,
            metadata: [
                metadataKey: "1",
                taskIDKey: taskID,
                statusKey: status.rawValue,
                exitCodeKey: exitCode.map(String.init) ?? "",
                outputPathKey: outputPath,
            ]
        )
    }

    static func statusText(for status: BackgroundTaskStatus) -> String {
        switch status {
        case .running: return "is still running"
        case .completed: return "completed successfully"
        case .failed: return "failed"
        case .stopped: return "was stopped"
        case .interrupted: return "was interrupted"
        }
    }
}

/// 后台任务完成通知的投递协调器。
///
/// ## 为什么要两条路径
///
/// - **空闲**：插入 `role == .user` 的消息，`MessageObserver` 看到用户消息就
///   自动起一个回合，模型因此被唤醒。
/// - **忙**：回合正在跑时插入消息不会起新回合（`MessageObserver` 会因
///   `isRunning` 直接返回），通知就丢了。因此忙时**入队**，等当前回合结束后
///   由 `turnFinished` 钩子排空。
///
/// ## 恰好一次
///
/// 每个任务的通知只投递一次。登记表保证「进程退出」只产生一个完成事件，
/// 协调器再用 `deliveredTaskIDs` 兜底：即使同一个任务被重复通知（显式停止
/// 与自然退出并发），也只投递一次。
@MainActor
final class BackgroundTaskNotificationCoordinator: SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.tool-manager",
        category: "BackgroundTaskNotification"
    )
    nonisolated static let emoji = "🛎️"
    nonisolated static let verbose = false

    /// 通知里附带的输出摘录长度上限。
    private static let tailExcerptLimit = 2_000

    /// 后台子代理任务的摘录上限：结论硬上限 8_000 字符加用量摘要，
    /// 一次读完才不必再让模型去翻输出文件。
    private static let subagentTailExcerptLimit = 12_000

    /// 登记表里后台子代理任务的命令前缀。
    private static let subagentCommandPrefix = "\(SubagentToolPolicy.delegationToolName):"

    private static func isSubagentTask(_ record: BackgroundTaskRecord) -> Bool {
        record.command.hasPrefix(subagentCommandPrefix)
    }

    private weak var agentLoop: (any AgentLoopProviding)?
    private let messages: any MessageManaging
    private var registry: BackgroundTaskRegistry?

    /// 已投递通知的任务 ID——保证「恰好一次」。
    private var deliveredTaskIDs: Set<String> = []

    /// 等待投递的通知（按到达顺序）。
    private var pendingNotifications: [BackgroundTaskRecord] = []

    /// 已排入队列、但因抑制而暂存的通知。
    private var suppressedNotifications: [BackgroundTaskRecord] = []

    init(
        agentLoop: any AgentLoopProviding,
        messages: any MessageManaging,
        registry: BackgroundTaskRegistry?
    ) {
        self.agentLoop = agentLoop
        self.messages = messages
        self.registry = registry
    }

    /// 绑定登记表。登记表的完成事件由它转发进来。
    func attach(registry: BackgroundTaskRegistry) {
        self.registry = registry
    }

    // MARK: - 完成事件

    /// 收到后台任务完成事件。
    func handle(_ record: BackgroundTaskRecord) {
        guard !deliveredTaskIDs.contains(record.id) else {
            // 同一任务的第二次完成事件（显式停止与自然退出并发）：不重复投递。
            return
        }
        deliveredTaskIDs.insert(record.id)

        guard let agentLoop else {
            Self.logger.error("\(Self.t)无法投递后台任务通知：AgentLoop 已释放")
            return
        }

        // 自动回复被抑制（ACP 托管回合）时不能插入消息：MessageObserver 会
        // 直接丢弃，通知就永远丢了。改为暂存，等抑制解除后再投递。
        guard !agentLoop.isAutoReplySuppressed(for: record.conversationID) else {
            suppressedNotifications.append(record)
            if Self.verbose {
                Self.logger.info(
                    "\(Self.t)后台任务通知被抑制，暂存 task=\(record.id, privacy: .public)"
                )
            }
            return
        }

        // 会话正忙时插入消息不会起新回合（MessageObserver 会因 isRunning
        // 直接返回），通知就丢了。改为入队，等 turnFinished 排空。
        guard !agentLoop.isRunning(for: record.conversationID) else {
            pendingNotifications.append(record)
            if Self.verbose {
                Self.logger.info(
                    "\(Self.t)会话正忙，后台任务通知入队 task=\(record.id, privacy: .public)"
                )
            }
            return
        }

        Task { @MainActor [weak self] in
            await self?.deliverWithTail(record, agentLoop: agentLoop)
        }
    }

    /// 把通知投递给模型，并附带输出文件末尾的摘录。
    ///
    /// 摘录要从登记表里读（actor 隔离），因此必须是异步的。
    private func deliverWithTail(_ record: BackgroundTaskRecord, agentLoop: any AgentLoopProviding) async {
        let isSubagentTask = Self.isSubagentTask(record)
        let tailLimit = isSubagentTask ? Self.subagentTailExcerptLimit : Self.tailExcerptLimit
        let tail = await registry?.outputTail(for: record.id, limit: tailLimit) ?? ""
        let message = BackgroundTaskNotification.message(
            conversationID: record.conversationID,
            taskID: record.id,
            status: record.status,
            exitCode: record.exitCode,
            outputPath: record.outputPath,
            tailExcerpt: tail,
            isSubagentTask: isSubagentTask
        )
        messages.insertMessage(message, to: record.conversationID)

        if Self.verbose {
            Self.logger.info(
                "\(Self.t)已投递后台任务通知 task=\(record.id, privacy: .public)"
            )
        }
    }

    // MARK: - 忙时排队

    /// 回合结束：排空排队的通知。
    ///
    /// 必须在回合**结束之后**才起新回合：`turnFinished` 触发时上一个
    /// `runTurn` 还在退栈，直接起会被判定为并发回合而失败。因此这里只把
    /// 通知排进队列，真正的插入由随后的排空任务在回合空闲后完成。
    func handleTurnFinished(conversationID: UUID) {
        guard let agentLoop else { return }

        // 先处理因抑制而暂存的：抑制可能已经解除。
        flushSuppressed(conversationID: conversationID, agentLoop: agentLoop)

        let ready = pendingNotifications.filter { $0.conversationID == conversationID }
        guard !ready.isEmpty else { return }
        pendingNotifications.removeAll { $0.conversationID == conversationID }

        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self else { return }
            for record in ready {
                guard !agentLoop.isAutoReplySuppressed(for: record.conversationID) else {
                    self.suppressedNotifications.append(record)
                    continue
                }
                await self.deliverWithTail(record, agentLoop: agentLoop)
            }
        }
    }

    /// 把因抑制而暂存的通知重新投递（抑制解除后）。
    private func flushSuppressed(conversationID: UUID, agentLoop: any AgentLoopProviding) {
        let ready = suppressedNotifications.filter { $0.conversationID == conversationID }
        guard !ready.isEmpty else { return }
        suppressedNotifications.removeAll { $0.conversationID == conversationID }

        guard !agentLoop.isAutoReplySuppressed(for: conversationID) else {
            // 抑制还没解除，放回去。
            suppressedNotifications.append(contentsOf: ready)
            return
        }
        Task { @MainActor [weak self] in
            for record in ready {
                await self?.deliverWithTail(record, agentLoop: agentLoop)
            }
        }
    }

    /// 队列里还没投递的通知数（测试用）。
    var pendingNotificationCount: Int {
        pendingNotifications.count + suppressedNotifications.count
    }
}
