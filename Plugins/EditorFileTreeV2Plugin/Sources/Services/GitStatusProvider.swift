import Foundation
import SuperLogKit
import LibGit2Swift
import os

// MARK: - Models

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

/// 文件树 Git 状态提供器
///
/// 负责在后台线程执行 Git status 查询，构建轻量 snapshot 供 UI 层只读使用。
/// 不持有任何 MainActor 状态，所有查询结果通过返回值传递给调用方。
public final class GitStatusProvider: @unchecked Sendable, SuperLog {

    public nonisolated static let emoji = "🌳"
    public nonisolated static let verbose: Bool = true
    public nonisolated static let logger = EditorFileTreeV2Plugin.logger

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
        // 1. 检测是否为 Git 仓库
        guard LibGit2.isGitRepository(at: projectRootPath) else {
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
            stagedDiffFiles = try LibGit2.getDiffFileList(at: projectRootPath, staged: true)
            unstagedDiffFiles = try LibGit2.getDiffFileList(at: projectRootPath, staged: false)
        } catch {
            Self.logger.warning("\(Self.t)Git status 查询失败：\(error.localizedDescription)")
            return nil // 查询失败，返回 nil 让调用方保留旧 snapshot
        }

        // 4. 获取 untracked 文件列表（getDiffFileList 已包含 untracked）
        // getDiffFileList 返回的 changeType 包含 "M"/"A"/"D"/"R"/"?"/"C" 等

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

    // MARK: - Private

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