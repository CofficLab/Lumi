import Foundation
import OSLog

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
final class FileLogCoordinator: @unchecked Sendable {
    static let shared = FileLogCoordinator()

    // MARK: - Constants

    private let subsystem = "com.coffic.lumi"
    private let maxFileSize: Int = 5 * 1024 * 1024  // 5 MB
    private let maxRetentionDays: Int = 7
    private let pollInterval: TimeInterval = 2.0

    // MARK: - State

    private let queue = DispatchQueue(label: "com.coffic.lumi.file-log", qos: .utility)
    private var currentFileHandle: FileHandle?
    private var currentFilePath: URL?
    private var isRunning = false
    private var isFileLoggingDisabled = false
    private var lastPolledDate = Date.distantPast
    private var pollTimer: DispatchSourceTimer?

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
            pollOnce() // flush 剩余
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

        let filename = logDateFormatter.string(from: Date()) + ".log"
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
            self?.pollOnce()
        }
        timer.resume()
        pollTimer = timer
    }

    private func pollOnce() {
        guard isRunning, !isFileLoggingDisabled else { return }

        let store: OSLogStore
        do {
            store = try OSLogStore(scope: .currentProcessIdentifier)
        } catch {
            return
        }

        // 从上次轮询时间点之后获取新条目
        let position = store.position(date: lastPolledDate)
        lastPolledDate = Date()

        guard let entries = try? store.getEntries(
            at: position,
            matching: NSPredicate(format: "subsystem == %@", subsystem)
        ) else { return }

        var hasNewEntries = false
        for entry in entries {
            writeEntry(entry)
            hasNewEntries = true
        }

        if hasNewEntries {
            flushCurrentFile()
            if !isFileLoggingDisabled {
                checkFileSize()
            }
        }
    }

    // MARK: - Write

    private func writeEntry(_ entry: OSLogEntry) {
        let line: String
        if let logEntry = entry as? OSLogEntryLog {
            let level = logEntry.level.stringValue
            let time = entryTimeFormatter.string(from: entry.date)
            line = "[\(time)] [\(level)] [\(logEntry.category)] \(entry.composedMessage)\n"
        } else {
            let time = entryTimeFormatter.string(from: entry.date)
            line = "[\(time)] \(entry.composedMessage)\n"
        }
        writeData(Data(line.utf8))
    }

    private func writeData(_ data: Data) {
        guard let handle = currentFileHandle, !isFileLoggingDisabled else { return }
        do {
            try handle.write(contentsOf: data)
        } catch {
            handleFileWriteFailure(error)
        }
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

    // MARK: - Formatters

    private lazy var logDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return f
    }()

    private lazy var entryTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
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
