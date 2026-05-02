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
/// ~/Library/Application Support/com.coffic.Lumi/Logs/
///   ├── 2026-05-02_10-36-00.log
///   ├── 2026-05-02_11-02-33.log
///   └── ...
/// ```
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
    private var lastPolledDate = Date.distantPast
    private var pollTimer: Timer?

    // MARK: - Log Directory

    private var logsDirectory: URL {
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            fatalError("无法获取 Application Support 目录")
        }

        let dir = appSupportURL
            .appendingPathComponent("com.coffic.Lumi", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)

        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)

        return dir
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
            pollTimer?.invalidate()
            pollTimer = nil
            pollOnce() // flush 剩余
            closeCurrentFile()
        }
    }

    // MARK: - Log Rotation

    private func rotateLogFile() {
        closeCurrentFile()

        let filename = logDateFormatter.string(from: Date()) + ".log"
        let filePath = logsDirectory.appendingPathComponent(filename)

        FileManager.default.createFile(atPath: filePath.path, contents: nil)
        currentFileHandle = try? FileHandle(forWritingTo: filePath)
        currentFilePath = filePath

        // 写入 header
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let header = """
        === Lumi Log ===
        Version: \(version) (\(build))
        Date: \(Date())
        ===

        """
        currentFileHandle?.write(Data(header.utf8))
    }

    private func closeCurrentFile() {
        guard let handle = currentFileHandle else { return }
        handle.synchronizeFile()
        handle.closeFile()
        currentFileHandle = nil
    }

    // MARK: - Polling

    private func schedulePollTimer() {
        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.queue.async {
                self?.pollOnce()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func pollOnce() {
        guard isRunning else { return }

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
            currentFileHandle?.synchronizeFile()
            checkFileSize()
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
        currentFileHandle?.write(Data(line.utf8))
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
