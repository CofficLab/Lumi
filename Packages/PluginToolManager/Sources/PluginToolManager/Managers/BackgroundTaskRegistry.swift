import Foundation
import KitShell

/// 后台任务的状态。
public enum BackgroundTaskStatus: String, Codable, Sendable {
    /// 进程仍在运行。
    case running
    /// 进程正常退出（退出码 0）。
    case completed
    /// 进程非零退出或因错误结束。
    case failed
    /// 被显式停止。
    case stopped
    /// 应用重启后发现进程已不存在（v1 不重挂孤儿进程）。
    case interrupted
}

/// 一个后台任务的可观察快照。
public struct BackgroundTaskRecord: Codable, Sendable, Identifiable, Equatable {
    /// 任务 ID，同时是输出文件名（`<taskID>.log`）。
    public let id: String
    /// 发起该任务的会话——完成通知要送回这里。
    public let conversationID: UUID
    /// 触发任务的命令。
    public let command: String
    /// 输出文件路径，模型用 `read_file` 读取。
    public let outputPath: String
    /// 进程 PID。
    public let processIdentifier: Int32
    /// 任务开始时间。
    public let startedAt: Date
    /// 当前状态。
    public var status: BackgroundTaskStatus
    /// 退出码（结束后才有值）。
    public var exitCode: Int32?
    /// 结束时间。
    public var finishedAt: Date?

    public init(
        id: String,
        conversationID: UUID,
        command: String,
        outputPath: String,
        processIdentifier: Int32,
        startedAt: Date,
        status: BackgroundTaskStatus = .running,
        exitCode: Int32? = nil,
        finishedAt: Date? = nil
    ) {
        self.id = id
        self.conversationID = conversationID
        self.command = command
        self.outputPath = outputPath
        self.processIdentifier = processIdentifier
        self.startedAt = startedAt
        self.status = status
        self.exitCode = exitCode
        self.finishedAt = finishedAt
    }
}

/// 后台任务的生命周期事件。
public enum BackgroundTaskEvent: Sendable {
    /// 任务已登记并开始运行。
    case started(BackgroundTaskRecord)
    /// 任务结束（每个任务**恰好一次**）。
    case finished(BackgroundTaskRecord)
}

/// 后台任务的输出落盘位置与写入器。
///
/// 在交接发生**之前**就建好文件并开始写入：这样交接瞬间模型读到的文件里
/// 已经包含前台预算期间产生的输出，而不是从交接点才开始。
final class BackgroundTaskOutputSink: @unchecked Sendable {
    /// 交接前的输出暂存上限（保留尾部）。
    private static let pendingLimit = 64 * 1024

    private let lock = NSLock()
    private var writer: BackgroundTaskOutputWriter?
    private var pending = ""

    func append(_ text: String) {
        guard !text.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        if let writer {
            writer.append(text)
        } else {
            pending += text
            if pending.count > Self.pendingLimit {
                pending = String(pending.suffix(Self.pendingLimit))
            }
        }
    }

    /// 交接时接入真实写入器，并把暂存的输出按顺序冲刷进去。
    ///
    /// 冲刷与后续写入都在同一把锁内完成，保证文件里的字节顺序与实际输出
    /// 顺序一致——顺序错乱会让模型读到拼接错乱的日志。
    func install(_ writer: BackgroundTaskOutputWriter) {
        lock.lock()
        defer { lock.unlock() }
        self.writer = writer
        if !pending.isEmpty {
            writer.append(pending)
            pending = ""
        }
    }

    /// 当前写入器（交接前为 nil）。
    var installedWriter: BackgroundTaskOutputWriter? {
        lock.lock()
        defer { lock.unlock() }
        return writer
    }
}

/// 后台任务登记表。
///
/// ## 为什么独立于 ToolJob
///
/// ToolJob 是**回合作用域**的：回合取消后，迟到的 Job 事件必须被丢弃
/// （见 #536）。后台任务的生命周期**跨越回合**——用户取消当前回合时，
/// 后台进程必须继续跑。因此后台任务不走 ToolJob 事件通道，而是由本
/// actor 独立管理，避免重演「迟到事件回流」的坑。
///
/// ## 恰好一次
///
/// 每个任务的状态迁移都在 actor 内完成，`finished` 事件只在状态首次从
/// `.running` 变为终态时发出，因此「进程退出」与「用户停止」并发时也不会
/// 发出两次完成通知。
public actor BackgroundTaskRegistry {
    /// 单个任务的输出磁盘上限（8 MiB）。
    public static let maxOutputBytes = 8 * 1024 * 1024

    private let rootDirectory: URL
    private let tasksDirectory: URL
    private let persistenceURL: URL
    private let fileManager = FileManager.default

    private var records: [String: BackgroundTaskRecord] = [:]
    private var handles: [String: BackgroundShellHandle] = [:]
    private var sinks: [String: BackgroundTaskOutputSink] = [:]
    private var observers: [UUID: @Sendable (BackgroundTaskEvent) -> Void] = [:]

    /// - Parameter rootDirectory: 插件数据目录；输出落在其下的 `background-tasks/`。
    public init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
        self.tasksDirectory = rootDirectory.appendingPathComponent("background-tasks", isDirectory: true)
        self.persistenceURL = rootDirectory.appendingPathComponent("background_tasks.json", isDirectory: false)
        try? fileManager.createDirectory(at: tasksDirectory, withIntermediateDirectories: true)
        records = Self.loadPersistedRecords(from: persistenceURL)
    }

    // MARK: - 观察者

    @discardableResult
    public func addObserver(
        _ callback: @escaping @Sendable (BackgroundTaskEvent) -> Void
    ) -> UUID {
        let id = UUID()
        observers[id] = callback
        return id
    }

    public func removeObserver(_ id: UUID) {
        observers.removeValue(forKey: id)
    }

    // MARK: - 分配

    /// 分配一个后台任务的 ID 与输出路径。
    ///
    /// 在命令**启动之前**调用：模型需要提前知道去哪里读输出，而任务 ID
    /// 必须在输出文件名里保持稳定。
    public func allocateTaskID() -> String {
        UUID().uuidString
    }

    /// 输出文件路径（不创建文件）。
    public func outputPath(for taskID: String) -> String {
        tasksDirectory
            .appendingPathComponent("\(taskID).log", isDirectory: false)
            .path
    }

    /// 交接成功后登记任务并开始监听退出。
    ///
    /// - Parameters:
    ///   - taskID: 之前通过 `allocateTaskID()` 分配的任务 ID。
    ///   - conversationID: 发起任务的会话。
    ///   - command: 触发任务的命令。
    ///   - handle: KitShell 交接出来的存活进程句柄。
    ///   - sink: 输出写入器（交接前已在暂存前台输出）。
    /// - Returns: 登记后的任务快照。
    @discardableResult
    func adopt(
        taskID: String,
        conversationID: UUID,
        command: String,
        handle: BackgroundShellHandle,
        sink: BackgroundTaskOutputSink
    ) -> BackgroundTaskRecord {
        let outputPath = outputPath(for: taskID)
        // 交接此刻才把输出接到真实文件上：前台预算期间的输出在 sink 里暂存，
        // 这里按顺序冲刷，之后的输出直接追加。
        if let writer = try? BackgroundTaskOutputWriter(
            fileURL: URL(fileURLWithPath: outputPath),
            maxBytes: Self.maxOutputBytes
        ) {
            sink.install(writer)
        }

        let record = BackgroundTaskRecord(
            id: taskID,
            conversationID: conversationID,
            command: command,
            outputPath: outputPath,
            processIdentifier: handle.processIdentifier,
            startedAt: handle.startedAt
        )
        records[taskID] = record
        handles[taskID] = handle
        sinks[taskID] = sink
        persist()

        emit(.started(record))

        // 等待进程退出。进程可能在此之前就被显式停止——那时退出码由
        // `stop` 路径写入，本路径只在状态仍是 running 时才发完成事件。
        Task { [weak self] in
            let exitCode = await handle.waitForExit()
            await self?.finish(taskID: taskID, exitCode: exitCode)
        }

        return record
    }

    // MARK: - 查询

    public func task(for taskID: String) -> BackgroundTaskRecord? {
        records[taskID]
    }

    public func tasks(forConversationID conversationID: UUID) -> [BackgroundTaskRecord] {
        records.values
            .filter { $0.conversationID == conversationID }
            .sorted { $0.startedAt < $1.startedAt }
    }

    public func allTasks() -> [BackgroundTaskRecord] {
        records.values.sorted { $0.startedAt < $1.startedAt }
    }

    /// 读取任务输出文件的尾部。
    public func outputTail(for taskID: String, limit: Int) -> String {
        guard let sink = sinks[taskID], let writer = sink.installedWriter else { return "" }
        return writer.tail(limit: limit)
    }

    // MARK: - 控制

    /// 显式停止一个后台任务：SIGTERM → 宽限 → SIGKILL。
    ///
    /// - Returns: 是否真的停掉了一个运行中的任务。
    @discardableResult
    public func stop(taskID: String) -> Bool {
        guard var record = records[taskID], record.status == .running else { return false }
        handles[taskID]?.terminate()
        record.status = .stopped
        record.finishedAt = Date()
        records[taskID] = record
        sinks[taskID]?.installedWriter?.close()
        persist()
        emit(.finished(record))
        return true
    }

    /// 停止某个会话的全部后台任务。
    ///
    /// 删除会话时必须调用：后台进程会继续写文件、继续占用 CPU，
    /// 而它的完成通知已经没有收件人了。
    @discardableResult
    public func stopAll(forConversationID conversationID: UUID) -> Int {
        let taskIDs = records.values
            .filter { $0.conversationID == conversationID && $0.status == .running }
            .map(\.id)
        var stopped = 0
        for taskID in taskIDs where stop(taskID: taskID) {
            stopped += 1
        }
        return stopped
    }

    /// 停止全部后台任务（应用退出时调用，避免留下僵尸进程）。
    @discardableResult
    public func stopAll() -> Int {
        let taskIDs = records.values
            .filter { $0.status == .running }
            .map(\.id)
        var stopped = 0
        for taskID in taskIDs where stop(taskID: taskID) {
            stopped += 1
        }
        return stopped
    }

    // MARK: - 内部

    /// 进程退出后的收尾。
    ///
    /// 只有状态仍是 `.running` 才发完成事件：显式停止已经把状态改成
    /// `.stopped`，此时不能重复通知。
    private func finish(taskID: String, exitCode: Int32) {
        guard var record = records[taskID], record.status == .running else { return }
        record.status = exitCode == 0 ? .completed : .failed
        record.exitCode = exitCode
        record.finishedAt = Date()
        records[taskID] = record
        handles.removeValue(forKey: taskID)
        sinks[taskID]?.installedWriter?.close()
        persist()
        emit(.finished(record))
    }

    private func emit(_ event: BackgroundTaskEvent) {
        for observer in observers.values {
            observer(event)
        }
    }

    // MARK: - 持久化

    private static func loadPersistedRecords(from url: URL) -> [String: BackgroundTaskRecord] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let restored = try? decoder.decode([BackgroundTaskRecord].self, from: data) else {
            return [:]
        }

        var result: [String: BackgroundTaskRecord] = [:]
        for var record in restored {
            if record.status == .running {
                // v1 不重挂孤儿进程：重启后上一轮的进程已经失去管道所有权，
                // 状态标记为「已中断」，让用户知道它没跑完。
                record.status = .interrupted
                record.finishedAt = Date()
            }
            result[record.id] = record
        }
        return result
    }

    private func persist() {
        let snapshot = Array(records.values)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: persistenceURL, options: .atomic)
    }
}
