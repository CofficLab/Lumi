import Foundation
import OSLog
import SuperLogKit

/// 磁盘日志协调器
///
/// 通过 OSLogStore 订阅 subsystem == "com.coffic.lumi" 的日志条目，
/// 异步写入磁盘文件。支持自动轮转和过期清理。
///
/// ## 设计
///
/// ```text
/// 现有代码（零改动）
///   AppLogger.core.info("\(self.t)...")
///   SomePlugin.logger.error("...")
///         │
///         ▼
/// os.Logger → 系统统一日志（Console.app / log stream 可查）
///         │
///         ▼
/// FileLogCoordinator（OSLogStore 轮询）
///         │
///         ▼
/// ~/Library/Application Support/com.coffic.Lumi/db_debug_v1/FileLog/
///   ├── 2026-05-02_10-36-00.log
///   ├── 2026-05-02_11-02-33.log
///   └── ...
/// ```
///
/// ## 版本和环境隔离
///
/// 日志存储遵循插件数据存储规范，存放在 `DBConfig.getPluginDBFolderURL` 下插件专属子目录：
/// - **版本隔离**：由 `DBConfig` 统一管理（使用主版本号 v1, v2, ...）
/// - **环境隔离**：由 `DBConfig` 统一管理（Debug / Production）
/// - **目录结构**：
///   ```
///   ~/Library/Application Support/com.coffic.Lumi/
///   └── db_debug_v1/                   # 数据库目录
///       ├── Core/
///       ├── FileLog/                   # 日志插件目录
///       │   ├── 2026-05-02_10-36-00.log
///       │   └── ...
///       └── [PluginName]/
///   ```
///
/// ## 自动管理规则
///
/// | 规则 | 值 |
/// |------|-----|
/// | 单文件大小上限 | 5 MB |
/// | 过期清理 | 7 天 |
/// | 轮转触发 | 启动时新建 + 超大小自动轮转 |
/// | 轮询间隔 | 2 秒 |
final class FileLogCoordinator: @unchecked Sendable, SuperLog {
    static let shared = FileLogCoordinator()

    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.file-log")
    nonisolated public static let emoji = "📝"
    nonisolated(unsafe) static var verbose: Bool = false

    // MARK: - Constants

    private let subsystem = "com.coffic.lumi"
    private let maxFileSize: Int = 5 * 1024 * 1024  // 5 MB
    private let maxRetentionDays: Int = 7
    private let pollInterval: TimeInterval = 2.0
    private let writeDelay: TimeInterval = 3.0

    // MARK: - State

    private let queue = DispatchQueue(label: "com.coffic.lumi.file-log", qos: .utility)
    private let pollQueue = DispatchQueue(label: "com.coffic.lumi.file-log.poll", qos: .utility)
    private var currentFileHandle: FileHandle?
    private var currentFilePath: URL?
    private var isRunning = false
    private var isFileLoggingDisabled = false
    private var lastPolledDate = Date.distantPast
    private var pollInFlight = false
    private var pollTimer: DispatchSourceTimer?
    private var pendingRecords: [LogRecord] = []
    private var seenRecordKeys: Set<String> = []

    /// 心跳节流计数：每次 OSLog 轮询 tick 自增，每 N 次打一条日志。
    /// 用于排查 CPU 占用持续 100% 时确认本后台轮询（2 秒一次扫描 OSLogStore）是否在狂跑。
    private var pollTickCount = 0
    private let pollTickLogEvery = 10

    // MARK: - Log Directory

    private var logsDirectory: URL {
        // 遵循插件数据存储规范，存放到插件专属子目录：
        // ~/Library/Application Support/com.coffic.Lumi/db_debug_v1/FileLog/
        FileLogPlugin.configuration.logsDirectory()
    }

    // MARK: - Public Lifecycle

    private init() {}

    /// 启动磁盘日志收集
    ///
    /// 应在 applicationDidFinishLaunching 中调用。
    func start() {
        queue.async { [self] in
            guard !isRunning else { return }
            isRunning = true
            isFileLoggingDisabled = false
            lastPolledDate = Date().addingTimeInterval(-writeDelay)
            pendingRecords = []
            seenRecordKeys = []
            if Self.verbose { Self.logger.info("\(Self.t)启动 OSLog 轮询(间隔 \(self.pollInterval)s)，写入 \(self.logsDirectory.path)") }
            purgeExpiredLogs()
            rotateLogFile()
            schedulePollTimer()
        }
    }

    /// 停止磁盘日志收集并 flush 剩余条目
    ///
    /// 应在 applicationWillTerminate 中调用。
    func stop() {
        queue.async { [self] in
            guard isRunning else { return }
            isRunning = false
            pollTimer?.cancel()
            pollTimer = nil
            writePendingRecords(upTo: .distantFuture)
            flushCurrentFile()
            closeCurrentFile()
        }
    }

    // MARK: - Log Rotation

    private func rotateLogFile() {
        closeCurrentFile()
        guard !isFileLoggingDisabled else { return }

        do {
            try Self.prepareLogsDirectory(logsDirectory)
        } catch {
            handleFileWriteFailure(error)
            return
        }

        let filename = Self.logFilename(
            for: Date(),
            processID: ProcessInfo.processInfo.processIdentifier
        )
        let filePath = logsDirectory.appendingPathComponent(filename)

        guard FileManager.default.createFile(atPath: filePath.path, contents: nil) else {
            handleFileWriteFailure(CocoaError(.fileWriteUnknown))
            return
        }

        do {
            currentFileHandle = try FileHandle(forWritingTo: filePath)
        } catch {
            handleFileWriteFailure(error)
            return
        }
        currentFilePath = filePath

        // 写入 header
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        
        // 获取环境标识
        #if DEBUG
        let environment = "Debug"
        #else
        let environment = "Production"
        #endif
        
        // 获取主版本号
        let majorVersion = version.split(separator: ".").first.flatMap { Int($0) } ?? 1
        
        let header = """
        === Lumi Log ===
        Version: \(version) (\(build))
        Environment: \(environment)
        Database Version: v\(majorVersion)
        Date: \(Date())
        ===

        """
        writeData(Data(header.utf8))
    }

    static func prepareLogsDirectory(_ directory: URL, fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func closeCurrentFile() {
        guard let handle = currentFileHandle else { return }
        currentFileHandle = nil
        currentFilePath = nil
        var closeError: Error?
        do {
            try handle.synchronize()
        } catch {
            closeError = error
        }

        do {
            try handle.close()
        } catch {
            closeError = closeError ?? error
        }

        if let closeError {
            handleFileWriteFailure(closeError)
        }
    }

    // MARK: - Polling

    private func schedulePollTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + pollInterval, repeating: pollInterval, leeway: .seconds(1))
        timer.setEventHandler { [weak self] in
            self?.startPollIfNeeded()
        }
        timer.resume()
        pollTimer = timer
    }

    private func startPollIfNeeded() {
        guard isRunning, !isFileLoggingDisabled, !pollInFlight else { return }

        pollInFlight = true
        let startDate = lastPolledDate
        let pollDate = Date()
        let subsystem = self.subsystem

        pollQueue.async { [weak self] in
            let records = Self.readLogRecords(subsystem: subsystem, since: startDate)

            self?.queue.async { [weak self] in
                guard let self else { return }
                self.pollInFlight = false
                guard self.isRunning, !self.isFileLoggingDisabled else { return }
                guard let records else { return }

                self.lastPolledDate = pollDate.addingTimeInterval(-self.writeDelay)
                for record in records where !self.seenRecordKeys.contains(record.key) {
                    self.seenRecordKeys.insert(record.key)
                    self.pendingRecords.append(record)
                }

                let wroteRecords = self.writePendingRecords(upTo: pollDate.addingTimeInterval(-self.writeDelay))
                if wroteRecords {
                    self.flushCurrentFile()
                    if !self.isFileLoggingDisabled {
                        self.checkFileSize()
                    }
                }

                // 节流心跳：每 N 次轮询打一条，确认后台 OSLog 轮询是否持续运行。
                // 若本轮读到的记录数持续很大，说明 app 自身打的日志过多，
                // 每次扫描+去重+写盘会吃 CPU，是 100% CPU 的可能来源。
                self.pollTickCount += 1
                if Self.verbose, self.pollTickCount % self.pollTickLogEvery == 0 {
                    Self.logger.info("\(Self.t)tick #\(self.pollTickCount) OSLog 轮询完成，本轮读到 \(records.count) 条，待写 \(self.pendingRecords.count) 条")
                }
            }
        }
    }

    private static func readLogLines(subsystem: String, since date: Date) -> [String]? {
        readLogRecords(subsystem: subsystem, since: date).map(orderedLogLines)
    }

    private static func readLogRecords(subsystem: String, since date: Date) -> [LogRecord]? {
        let store: OSLogStore
        do {
            store = try OSLogStore(scope: .currentProcessIdentifier)
        } catch {
            return nil
        }

        let position = store.position(date: date)
        guard let entries = try? store.getEntries(
            at: position,
            matching: NSPredicate(format: "subsystem == %@", subsystem)
        ) else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"

        let records = entries.map { entry in
            LogRecord(
                date: entry.date,
                key: Self.recordKey(for: entry),
                line: Self.formatEntry(entry, formatter: formatter)
            )
        }

        return records
    }

    private static func formatEntry(_ entry: OSLogEntry, formatter: DateFormatter) -> String {
        let time = formatter.string(from: entry.date)
        if let logEntry = entry as? OSLogEntryLog {
            let level = logEntry.level.stringValue
            return "[\(time)] [\(level)] [\(logEntry.category)] \(entry.composedMessage)\n"
        }
        return "[\(time)] \(entry.composedMessage)\n"
    }

    struct LogRecord {
        let date: Date
        let key: String
        let line: String

        init(date: Date, key: String? = nil, line: String) {
            self.date = date
            self.key = key ?? "\(date.timeIntervalSinceReferenceDate)|\(line)"
            self.line = line
        }
    }

    static func orderedLogLines(_ records: [LogRecord]) -> [String] {
        records
            .enumerated()
            .sorted { lhs, rhs in
                if lhs.element.date == rhs.element.date {
                    return lhs.offset < rhs.offset
                }
                return lhs.element.date < rhs.element.date
            }
            .map(\.element.line)
    }

    static func recordsReadyToWrite(_ records: [LogRecord], upTo cutoff: Date) -> (ready: [LogRecord], pending: [LogRecord]) {
        let orderedRecords = records
            .enumerated()
            .sorted { lhs, rhs in
                if lhs.element.date == rhs.element.date {
                    return lhs.offset < rhs.offset
                }
                return lhs.element.date < rhs.element.date
            }

        var ready: [LogRecord] = []
        var pending: [LogRecord] = []
        ready.reserveCapacity(orderedRecords.count)
        pending.reserveCapacity(orderedRecords.count)

        for record in orderedRecords.map(\.element) {
            if record.date <= cutoff {
                ready.append(record)
            } else {
                pending.append(record)
            }
        }

        return (ready, pending)
    }

    static func recordKey(for entry: OSLogEntry) -> String {
        let category = (entry as? OSLogEntryLog)?.category ?? ""
        return "\(entry.date.timeIntervalSinceReferenceDate)|\(category)|\(entry.composedMessage)"
    }

    static func logFilename(for date: Date, processID: Int32) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return "\(formatter.string(from: date))_pid-\(processID).log"
    }

    // MARK: - Write

    private func writeData(_ data: Data) {
        guard let handle = currentFileHandle, !isFileLoggingDisabled else { return }
        do {
            try handle.write(contentsOf: data)
        } catch {
            handleFileWriteFailure(error)
        }
    }

    @discardableResult
    private func writePendingRecords(upTo cutoff: Date) -> Bool {
        let result = Self.recordsReadyToWrite(pendingRecords, upTo: cutoff)
        pendingRecords = result.pending

        for record in result.ready {
            writeData(Data(record.line.utf8))
        }

        return !result.ready.isEmpty
    }

    private func flushCurrentFile() {
        guard let handle = currentFileHandle, !isFileLoggingDisabled else { return }
        do {
            try handle.synchronize()
        } catch {
            handleFileWriteFailure(error)
        }
    }

    private func handleFileWriteFailure(_: Error) {
        guard !isFileLoggingDisabled else { return }
        isFileLoggingDisabled = true
        isRunning = false
        pollTimer?.cancel()
        pollTimer = nil

        let handle = currentFileHandle
        currentFileHandle = nil
        currentFilePath = nil
        try? handle?.close()
    }

    private func checkFileSize() {
        guard let path = currentFilePath,
              let attrs = try? FileManager.default.attributesOfItem(atPath: path.path),
              let size = attrs[.size] as? Int,
              size > maxFileSize else { return }
        rotateLogFile()
    }

    // MARK: - Cleanup

    private func purgeExpiredLogs() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: logsDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        let cutoff = Calendar.current.date(
            byAdding: .day, value: -maxRetentionDays, to: Date()
        )!

        for file in files {
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
                  let creationDate = attrs[.creationDate] as? Date,
                  creationDate < cutoff else { continue }
            try? FileManager.default.removeItem(at: file)
        }
    }

}

// MARK: - OSLogEntryLog.Level String Representation

extension OSLogEntryLog.Level {
    var stringValue: String {
        switch self {
        case .undefined:    return "VERBOSE"
        case .debug:        return "DEBUG"
        case .info:         return "INFO"
        case .notice:       return "NOTICE"
        case .error:        return "ERROR"
        case .fault:        return "FAULT"
        @unknown default:   return "UNKNOWN"
        }
    }
}
