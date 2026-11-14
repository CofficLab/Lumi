import Foundation

/// 一个回合在持久化层面的终态记录。
///
/// ## 为什么需要持久化
///
/// Lumi 里「用户主动停止」与「app 崩溃 / 被强杀」在**消息层面完全无法区分**：
///
/// - `AgentLoopManager.cancelTurn` 不写任何终态消息，只是把 FSM 推到
///   `.cancelled` 并取消工具 Job；
/// - 工具 Job 取消后，`handleToolJobTerminal` 因为 phase 已是终态而直接
///   `default: return`，**不会**补写 tool result 消息；
/// - 崩溃时同样是什么都不写。
///
/// 两种情况留下的消息形状一模一样：最后一条是 `assistant` 且带 `toolCalls`，
/// 或者干脆只有一条 `user` 消息。
///
/// 因此「这个回合有没有正常收尾」不能从消息推断，必须由**进程内**记录，
/// 并在崩溃前落盘。
///
/// ## 语义
///
/// `outcome` 记录回合**被观察到**的终态：
///
/// - `.completed` / `.failed` / `.cancelled`：回合正常走到了终态；
/// - `.interrupted`：进程在回合运行期间消失（崩溃 / 强杀 / 断电），
///   落盘时回合还没结束。
///
/// `.interrupted` 是唯一会触发「继续」提示的状态。
struct ResumableTurnRecord: Codable, Equatable, Sendable {
    /// 回合结束原因。
    enum Outcome: String, Codable, Equatable, Sendable {
        /// 回合正常完成。
        case completed
        /// 回合以失败告终（LLM 报错等）。
        case failed
        /// 用户主动停止。
        case cancelled
        /// 回合挂起（等授权 / 等用户回答）。挂起不是终态，回合仍然活着。
        case suspended
        /// 进程在回合运行期间消失。
        case interrupted
    }

    let conversationID: UUID
    let turnID: UUID
    let outcome: Outcome
    /// 回合开始时间。
    let startedAt: Date
    /// 记录写入时间。
    let recordedAt: Date
    /// 该回合最后一个已知的工具调用 ID。
    ///
    /// 崩溃后需要用它定位「哪个 tool_call 没有结果」，补写占位 tool result。
    var lastToolCallID: String?

    /// 是否值得向用户提示「可以继续」。
    ///
    /// 只有 `.interrupted` 提示：其余三种都是回合自己走到了终点，
    /// 用户主动停止尤其不该被当成「出问题了」。
    var isResumable: Bool { outcome == .interrupted }
}

/// 回合终态的持久化存储。
///
/// ## 存储形状
///
/// 一个会话一行，记录该会话**最近一次**回合的状态。
///
/// 只保留每个会话最新的一条，而不是全部历史：
///
/// - 「继续」提示只关心当前会话最后一个回合；
/// - 崩溃恢复后，旧回合的状态已经没有意义；
/// - 存储量与历史长度无关，不会随对话增长无限膨胀。
///
/// ## 崩溃时序
///
/// 回合开始时写入 `.running`（不存在该状态，用「无记录」表示运行中），
/// 回合结束时写入终态。
///
/// 关键在于：**进程崩溃时，最后一条记录停留在「回合运行中」**。
/// 下次启动时扫描这些会话，把「运行中但没有终态记录」的会话标记为
/// `.interrupted`。
///
/// 因此写入必须是**先写运行中、后写终态**的两步，不能等到回合结束才写。
actor ResumableTurnStore {
    /// 存储文件路径。
    private let fileURL: URL
    /// 每个会话的最新回合记录。
    private var records: [UUID: ResumableTurnRecord] = [:]

    init(fileURL: URL) {
        self.fileURL = fileURL
        var loaded = Self.load(from: fileURL)
        // 新进程不可能有活着的挂起运行时：磁盘上的 `.suspended` 只能意味着
        // 进程在挂起期间消失（退出 / 强杀 / 崩溃）。按中断处理，重启后
        // 「继续」才有入口（#854）。进程内的活挂起不受影响——判定器还会
        // 用 AgentLoop 的实时状态排除它。
        var converted = false
        for (conversationID, record) in loaded where record.outcome == .suspended {
            loaded[conversationID] = ResumableTurnRecord(
                conversationID: record.conversationID,
                turnID: record.turnID,
                outcome: .interrupted,
                startedAt: record.startedAt,
                recordedAt: record.recordedAt,
                lastToolCallID: record.lastToolCallID
            )
            converted = true
        }
        self.records = loaded
        if converted { Self.persist(records: loaded, to: fileURL) }
    }

    // MARK: - 读写

    /// 记录一个回合进入运行中状态。
    ///
    /// 调用时机：回合开始（`turnStarted` 钩子）。
    func markRunning(conversationID: UUID, turnID: UUID, startedAt: Date = Date()) {
        records[conversationID] = ResumableTurnRecord(
            conversationID: conversationID,
            turnID: turnID,
            outcome: .interrupted,
            startedAt: startedAt,
            recordedAt: Date(),
            lastToolCallID: nil
        )
        persist()
    }

    /// 记录一个回合的终态。
    ///
    /// 调用时机：回合结束（`turnFinished` 钩子）。
    ///
    /// - Note: 只有 `.cancelled` 之外的终态才会覆盖记录。`.cancelled` 是用户
    ///   主动停止 —— 用户明确表示「不要继续了」，因此不留下「可继续」提示。
    func markFinished(
        conversationID: UUID,
        turnID: UUID,
        outcome: ResumableTurnRecord.Outcome,
        recordedAt: Date = Date()
    ) {
        // 已经存在同一回合的运行中记录时，保留它的 startedAt。
        let startedAt = records[conversationID]?.turnID == turnID
            ? (records[conversationID]?.startedAt ?? recordedAt)
            : recordedAt
        records[conversationID] = ResumableTurnRecord(
            conversationID: conversationID,
            turnID: turnID,
            outcome: outcome,
            startedAt: startedAt,
            recordedAt: recordedAt,
            lastToolCallID: records[conversationID]?.lastToolCallID
        )
        persist()
    }

    /// 记录某个工具调用已经发起（用于崩溃后定位孤儿 tool_call）。
    func markToolCall(conversationID: UUID, turnID: UUID, toolCallID: String) {
        guard var record = records[conversationID], record.turnID == turnID else { return }
        record.lastToolCallID = toolCallID
        records[conversationID] = record
        persist()
    }

    /// 读取某会话的回合记录。
    func record(for conversationID: UUID) -> ResumableTurnRecord? {
        records[conversationID]
    }

    /// 读取全部记录。
    func allRecords() -> [UUID: ResumableTurnRecord] {
        records
    }

    /// 清除某会话的记录（回合正常走完后不再需要保留）。
    func clear(conversationID: UUID) {
        guard records.removeValue(forKey: conversationID) != nil else { return }
        persist()
    }

    /// 移除全部记录。
    func reset() {
        guard !records.isEmpty else { return }
        records.removeAll()
        persist()
    }

    // MARK: - 持久化

    private func persist() {
        Self.persist(records: records, to: fileURL)
    }

    private nonisolated static func persist(records: [UUID: ResumableTurnRecord], to fileURL: URL) {
        let payload = Array(records.values)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // 原子写入：崩溃时不能留下半截 JSON，否则下次启动读不出任何记录，
        // 「继续」提示会整体失效。
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func load(from url: URL) -> [UUID: ResumableTurnRecord] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([ResumableTurnRecord].self, from: data)
        else {
            return [:]
        }
        var result: [UUID: ResumableTurnRecord] = [:]
        for record in decoded {
            result[record.conversationID] = record
        }
        return result
    }
}
