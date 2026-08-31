import Darwin
import Foundation
import KitSuperLog
import os

// MARK: - Models

/// Git 单条 diff 文件信息（替代旧版 LibGit2Swift 的 `GitDiffFile`）。
private struct GitDiffFile {
    /// 相对仓库根目录的文件路径。
    var file: String
    /// 变更类型：M/A/D/R/?/C。
    var changeType: String
}

/// 文件树中单个文件的 Git 状态类型
///
/// 优先级（高→低）：conflicted > deleted > renamed > added/untracked > modified > staged
public enum GitStatus: String, CaseIterable, Sendable {
    case modified = "M"
    case added = "A"
    case deleted = "D"
    case renamed = "R"
    case untracked = "?"
    case staged = "S"   // 仅 staged 但无其他变更时的辅助标记
    case conflicted = "C"

    /// 状态优先级数值（越高越优先）
    public var priority: Int {
        switch self {
        case .conflicted: return 6
        case .deleted:    return 5
        case .renamed:    return 4
        case .added:      return 3
        case .untracked:  return 3
        case .modified:   return 2
        case .staged:     return 1
        }
    }

    /// 在文件树行尾显示的字母
    public var displayLetter: String { rawValue }

    /// tooltip 描述
    public var tooltip: String {
        switch self {
        case .modified:   return "Modified"
        case .added:      return "Added"
        case .deleted:    return "Deleted"
        case .renamed:    return "Renamed"
        case .untracked:  return "Untracked"
        case .staged:     return "Staged"
        case .conflicted: return "Conflict"
        }
    }

    /// 取两个状态中优先级更高的那个
    public static func highest(_ a: GitStatus, _ b: GitStatus) -> GitStatus {
        a.priority >= b.priority ? a : b
    }
}

/// 单个文件的 Git 状态条目
public struct GitStatusEntry: Sendable, Equatable {
    /// 相对于仓库根目录的 POSIX 路径
    public let relativePath: String
    /// 文件状态
    public let status: GitStatus
    /// 是否已暂存
    public let isStaged: Bool

    public init(relativePath: String, status: GitStatus, isStaged: Bool = false) {
        self.relativePath = relativePath
        self.status = status
        self.isStaged = isStaged
    }
}

/// Git 状态快照，供文件树视图只读查询
public struct GitStatusSnapshot: Sendable, Equatable {
    /// 文件路径 → 状态条目（相对路径为 key）
    public let entriesByRelativePath: [String: GitStatusEntry]

    /// 目录路径 → 聚合的最高优先级状态（用于文件夹行显示）
    public let directoryAggregateByRelativePath: [String: GitStatus]

    /// 仓库根目录绝对路径
    public let repoRootPath: String

    /// 快照捕获时间
    public let capturedAt: Date

    /// 空 snapshot（非 Git 仓库或查询失败时使用）
    public static let empty = GitStatusSnapshot(
        entriesByRelativePath: [:],
        directoryAggregateByRelativePath: [:],
        repoRootPath: "",
        capturedAt: .distantPast
    )

    /// 是否为空（非 Git 仓库）
    public var isEmpty: Bool {
        entriesByRelativePath.isEmpty && repoRootPath.isEmpty
    }

    /// 查询指定相对路径的文件状态
    public func statusForPath(_ relativePath: String) -> GitStatus? {
        entriesByRelativePath[relativePath]?.status
    }

    /// 查询指定目录的聚合状态
    public func aggregateStatusForDirectory(_ relativePath: String) -> GitStatus? {
        directoryAggregateByRelativePath[relativePath]
    }
}

// MARK: - Provider

/// Collects process output without allowing a child process to block on a full pipe.
///
/// The collector continues draining after the retained-output limit is reached so the
/// child process can still exit normally. The limit protects the file-tree refresh from
/// retaining an unbounded amount of Git output for an unusually large repository.
private final class ProcessOutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private let maximumBytes: Int
    private var data = Data()
    private var truncated = false

    init(maximumBytes: Int) {
        self.maximumBytes = maximumBytes
    }

    func append(_ newData: Data) {
        guard !newData.isEmpty else { return }

        lock.lock()
        defer { lock.unlock() }

        guard data.count < maximumBytes else {
            truncated = true
            return
        }

        let remaining = maximumBytes - data.count
        if newData.count <= remaining {
            data.append(newData)
        } else {
            data.append(newData.prefix(remaining))
            truncated = true
        }
    }

    var isTruncated: Bool {
        lock.lock()
        defer { lock.unlock() }
        return truncated
    }

    func string() -> String {
        lock.lock()
        let result = String(data: data, encoding: .utf8) ?? ""
        lock.unlock()
        return result
    }
}

/// 文件树 Git 状态提供器
///
/// 负责在后台线程执行 Git status 查询，构建轻量 snapshot 供 UI 层只读使用。
/// 不持有任何 MainActor 状态，所有查询结果通过返回值传递给调用方。
public final class GitStatusProvider: @unchecked Sendable, SuperLog {

    public nonisolated static let emoji = "🌳"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let logger = ProjectFileTreePlugin.logger

    private static let outputChunkSize = 64 * 1024
    private static let maximumCapturedOutputBytes = 8 * 1024 * 1024
    private static let timeoutExitCode: Int32 = -2
    private static let truncatedOutputExitCode: Int32 = -3
    private let commandTimeout: TimeInterval

    /// - Parameter commandTimeout: Maximum duration for each Git subprocess.
    ///   A finite default is required because this provider is used by background
    ///   refresh tasks and must never wait indefinitely on a broken repository.
    public init(commandTimeout: TimeInterval = 15) {
        self.commandTimeout = max(0.1, commandTimeout)
    }

    // MARK: - Public

    /// 为指定项目路径捕获一次 Git 状态快照
    ///
    /// 在当前线程执行（应在后台调用），返回构建好的 snapshot。
    /// 如果项目不是 Git 仓库，返回 empty snapshot。
    /// 如果查询失败，返回 nil（调用方应保留上一份 snapshot）。
    ///
    /// - Parameter projectRootPath: 项目根目录的绝对路径
    /// - Returns: 快照，或 nil 表示查询失败
    public func captureSnapshot(projectRootPath: String) -> GitStatusSnapshot? {
        // 系统 git 调用通过 GitAccessCoordinator 串行化，避免并发访问仓库状态。
        return GitAccessCoordinator.performSync {
            // 1. 检测是否为 Git 仓库
            guard isGitRepository(at: projectRootPath) else {
                if Self.verbose {
                    Self.logger.info("\(Self.t)非 Git 仓库，返回空 snapshot：\(projectRootPath)")
                }
                return .empty
            }

            // 2. 解析真实 git dir（处理 worktree）
            let repoRootPath = resolveRepoRoot(from: projectRootPath)

            // 3. 获取 staged 和 unstaged 变更文件列表
            let stagedDiffFiles: [GitDiffFile]
            let unstagedDiffFiles: [GitDiffFile]

            do {
                let porcelain = try runGitStatusPorcelain(at: projectRootPath)
                stagedDiffFiles = Self.stagedFiles(from: porcelain)
                unstagedDiffFiles = Self.unstagedFiles(from: porcelain)
            } catch {
                Self.logger.warning("\(Self.t)Git status 查询失败：\(error.localizedDescription)")
                return nil // 查询失败，返回 nil 让调用方保留旧 snapshot
            }

            // 4. 获取 untracked 文件列表（porcelain 的 "??" 行已包含 untracked）
            // porcelain 返回的 changeType 包含 "M"/"A"/"D"/"R"/"?"/"C" 等

            // 5. 构建条目
        var entries: [String: GitStatusEntry] = [:]

        // 先处理 staged 文件
        for file in stagedDiffFiles {
            let normalizedPath = normalizePath(file.file, relativeTo: repoRootPath)
            let status = Self.parseStatus(file.changeType)
            let entry = GitStatusEntry(
                relativePath: normalizedPath,
                status: status,
                isStaged: true
            )
            // staged 文件可能是 added/modified/deleted/renamed
            entries[normalizedPath] = entry
        }

        // 再处理 unstaged 文件
        for file in unstagedDiffFiles {
            let normalizedPath = normalizePath(file.file, relativeTo: repoRootPath)
            let status = Self.parseStatus(file.changeType)

            if let existing = entries[normalizedPath] {
                // 同一个文件既有 staged 又有 unstaged 变更：取优先级更高的状态
                let mergedStatus = GitStatus.highest(existing.status, status)
                entries[normalizedPath] = GitStatusEntry(
                    relativePath: normalizedPath,
                    status: mergedStatus,
                    isStaged: existing.isStaged
                )
            } else {
                entries[normalizedPath] = GitStatusEntry(
                    relativePath: normalizedPath,
                    status: status,
                    isStaged: false
                )
            }
        }

        // 6. 计算目录聚合状态
        let directoryAggregate = Self.computeDirectoryAggregate(entries: Array(entries.values))

        if Self.verbose {
            Self.logger.info("\(Self.t)捕获 Git 状态快照：\(entries.count) 文件，\(directoryAggregate.count) 目录")
        }

        return GitStatusSnapshot(
            entriesByRelativePath: entries,
            directoryAggregateByRelativePath: directoryAggregate,
            repoRootPath: repoRootPath,
            capturedAt: Date()
        )
        }
    }

    // MARK: - Private

    /// 检测目录是否为 Git 仓库（系统 git 命令）。
    private func isGitRepository(at path: String) -> Bool {
        let (status, output) = runGit(["rev-parse", "--is-inside-work-tree"], in: path)
        guard status == 0 else { return false }
        return output.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
    }

    /// 运行 `git status --porcelain --untracked-files=all` 并返回原始输出。
    ///
    /// - Throws: 命令执行失败（非 Git 仓库 / 路径无效）。
    private func runGitStatusPorcelain(at path: String) throws -> String {
        let (status, output) = runGit(
            ["status", "--porcelain", "--untracked-files=all"],
            in: path
        )
        guard status == 0 else {
            throw GitStatusQueryError.gitCommandFailed(status: status)
        }
        return output
    }

    /// 从 porcelain 输出提取 staged（索引区）变更文件列表。
    private static func stagedFiles(from porcelain: String) -> [GitDiffFile] {
        porcelain.components(separatedBy: "\n").compactMap { line in
            guard line.count >= 2 else { return nil }
            let chars = Array(line)
            let x = chars[0]
            let y = chars[1]
            // 冲突：X 或 Y 为 U，视为 conflicted（优先）
            if x == "U" || y == "U" {
                return GitDiffFile(file: pathComponent(of: line), changeType: "C")
            }
            guard x != " " && x != "?" else { return nil }
            let changeType = String(x)
            return GitDiffFile(file: pathComponent(of: line), changeType: changeType)
        }
    }

    /// 从 porcelain 输出提取 unstaged（工作区）变更文件列表（含 untracked "??"）。
    private static func unstagedFiles(from porcelain: String) -> [GitDiffFile] {
        porcelain.components(separatedBy: "\n").compactMap { line in
            guard line.count >= 2 else { return nil }
            let chars = Array(line)
            let x = chars[0]
            let y = chars[1]
            // untracked：`?? path`
            if x == "?" && y == "?" {
                return GitDiffFile(file: pathComponent(of: line), changeType: "?")
            }
            // 冲突已在 staged 中处理；此处跳过
            if x == "U" || y == "U" { return nil }
            guard y != " " else { return nil }
            return GitDiffFile(file: pathComponent(of: line), changeType: String(y))
        }
    }

    /// 提取 porcelain 行的路径字段（兼容 rename 的 `old -> new`，取最终路径）。
    private static func pathComponent(of line: String) -> String {
        // 跳过前两个状态字符和分隔空格。
        let raw = line.dropFirst(3)
        // rename 格式：`R  old -> new`，取箭头后的新路径。
        if let arrowRange = raw.range(of: " -> ") {
            return String(raw[arrowRange.upperBound...])
        }
        return String(raw)
    }

    /// 执行系统 git 命令，返回 (退出码, 标准输出)。
    private func runGit(_ arguments: [String], in directory: String) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + arguments
        process.currentDirectoryURL = URL(fileURLWithPath: directory)
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            return (-1, "")
        }

        // Drain both pipes while the process is running. Waiting for exit before
        // reading either pipe deadlocks as soon as Git writes more than the pipe
        // buffer can hold.
        let stdoutCollector = ProcessOutputCollector(maximumBytes: Self.maximumCapturedOutputBytes)
        let stderrCollector = ProcessOutputCollector(maximumBytes: Self.maximumCapturedOutputBytes)
        let drainGroup = DispatchGroup()
        Self.drain(stdoutPipe.fileHandleForReading, into: stdoutCollector, group: drainGroup)
        Self.drain(stderrPipe.fileHandleForReading, into: stderrCollector, group: drainGroup)

        let deadline = Date().addingTimeInterval(commandTimeout)
        var timedOut = false
        while process.isRunning {
            if Date() >= deadline {
                timedOut = true
                terminate(process)
                break
            }
            Thread.sleep(forTimeInterval: 0.05)
        }

        // Ensure the process has fully exited before waiting for EOF on either
        // pipe. terminate(_:) force-kills it if SIGTERM is ignored.
        process.waitUntilExit()
        drainGroup.wait()

        if timedOut {
            Self.logger.warning("Git command timed out after \(self.commandTimeout)s: \(arguments.joined(separator: " "))")
            return (Self.timeoutExitCode, "")
        }

        if stdoutCollector.isTruncated || stderrCollector.isTruncated {
            Self.logger.warning("Git command output exceeded \(Self.maximumCapturedOutputBytes) bytes: \(arguments.joined(separator: " "))")
            return (Self.truncatedOutputExitCode, stdoutCollector.string())
        }

        return (process.terminationStatus, stdoutCollector.string())
    }

    /// Drain one pipe on a separate queue while the Git process is running.
    private static func drain(
        _ fileHandle: FileHandle,
        into collector: ProcessOutputCollector,
        group: DispatchGroup
    ) {
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            defer { group.leave() }
            while true {
                let data = fileHandle.readData(ofLength: Self.outputChunkSize)
                if data.isEmpty { break }
                collector.append(data)
            }
        }
    }

    /// Stop a Git subprocess after the timeout, escalating to SIGKILL if needed.
    private func terminate(_ process: Process) {
        guard process.isRunning else { return }

        process.terminate()
        let graceDeadline = Date().addingTimeInterval(1)
        while process.isRunning && Date() < graceDeadline {
            Thread.sleep(forTimeInterval: 0.05)
        }

        if process.isRunning, process.processIdentifier > 0 {
            kill(process.processIdentifier, SIGKILL)
        }
    }

    /// Git status 查询错误。
    private enum GitStatusQueryError: LocalizedError {
        case gitCommandFailed(status: Int32)

        var errorDescription: String? {
            switch self {
            case .gitCommandFailed(let status):
                return "git status failed with exit code \(status)"
            }
        }
    }

    /// 解析仓库根路径（处理 worktree 场景）
    private func resolveRepoRoot(from projectPath: String) -> String {
        let gitPath = projectPath + "/.git"

        // 如果 .git 是文件（worktree），读取其指向的真实 git dir
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: gitPath, isDirectory: &isDir), !isDir.boolValue {
            if let content = try? String(contentsOfFile: gitPath, encoding: .utf8),
               content.hasPrefix("gitdir: ") {
                let gitdirPath = String(content.dropFirst("gitdir: ".count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                // gitdir 可能是相对路径或绝对路径
                if gitdirPath.hasPrefix("/") {
                    // 绝对路径：gitdir 指向 .git/worktrees/xxx/
                    // 仓库根路径仍是项目路径
                    return projectPath
                } else {
                    return projectPath
                }
            }
        }

        return projectPath
    }

    /// 将 Git 返回的路径规范化为相对路径
    ///
    /// Git 返回的路径已经是相对于仓库根目录的 POSIX 路径，
    /// 这里做统一处理确保格式一致（无前导 "/"，POSIX 分隔符）。
    private func normalizePath(_ path: String, relativeTo repoRoot: String) -> String {
        var normalized = path
        // 确保使用正斜杠
        normalized = normalized.replacingOccurrences(of: "\\", with: "/")
        // 移除可能的前导 "/"
        if normalized.hasPrefix("/") {
            normalized = String(normalized.dropFirst())
        }
        // 移除尾部空格
        normalized = normalized.trimmingCharacters(in: .whitespaces)
        return normalized
    }

    /// 将 Git changeType 字符串映射为 GitStatus
    ///
    /// 未知 changeType 一律按 modified 处理（与 git 行为一致：有 diff 即视为修改）。
    /// 标记为 `static` 以便在不依赖 LibGit2 的情况下单元测试纯映射逻辑。
    static func parseStatus(_ changeType: String) -> GitStatus {
        switch changeType {
        case "M":  return .modified
        case "A":  return .added
        case "D":  return .deleted
        case "R":  return .renamed
        case "?":  return .untracked
        case "C":  return .conflicted
        default:   return .modified
        }
    }

    /// 计算目录级别的聚合状态
    ///
    /// 对于每个文件条目，向上遍历其所有父目录，取最高优先级状态。
    /// 例如：src/foo/bar.swift (M) → src/foo/ (M), src/ (M)
    ///
    /// 接受数组入参（而非字典）以方便单元测试构造输入；调用方传 `Array(entries.values)`。
    static func computeDirectoryAggregate(entries: [GitStatusEntry]) -> [String: GitStatus] {
        var aggregate: [String: GitStatus] = [:]

        for entry in entries {
            let path = entry.relativePath
            let components = path.split(separator: "/", omittingEmptySubsequences: true)

            // 从直接父目录开始，逐级向上
            var dirPath = ""
            for i in 0..<(components.count - 1) {
                if i == 0 {
                    dirPath = String(components[i])
                } else {
                    dirPath += "/" + String(components[i])
                }

                if let existing = aggregate[dirPath] {
                    aggregate[dirPath] = GitStatus.highest(existing, entry.status)
                } else {
                    aggregate[dirPath] = entry.status
                }
            }
        }

        return aggregate
    }
}
