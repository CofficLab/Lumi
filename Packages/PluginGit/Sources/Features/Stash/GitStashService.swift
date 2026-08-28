import Foundation
import LibGit2Swift
import os

/// 暂存（Stash）相关操作服务。
///
/// 内部基于 `LibGit2.stash*` 系列 API，封装工程面板中常用的：
/// - 列表 / 数量 / 存在性
/// - push / pop / apply / drop / clear
/// - 转为分支（stash branch）
///
/// 所有方法对异常采用「吞错返回空 / 抛错」二选一，遵循
/// `GitBranchService` 已有的风格：读取容错，命令主动抛错。
public enum GitStashService {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.git.stash")

    // MARK: - 查询

    /// 获取当前仓库的所有暂存条目。
    public static func list(at path: String) -> [GitStashEntry] {
        (try? LibGit2.getStashListEnhanced(at: path)) ?? []
    }

    public static func count(at path: String) -> Int {
        (try? LibGit2.getStashCount(at: path)) ?? 0
    }

    public static func exists(at path: String) -> Bool {
        (try? LibGit2.hasStash(at: path)) ?? false
    }

    // MARK: - 写入

    /// 暂存当前未提交变更，可选附带消息。
    /// - Returns: 暂存索引；没有可暂存内容时返回 `nil`。
    @discardableResult
    public static func push(message: String? = nil, at path: String) throws -> Int? {
        let index = try LibGit2.stash(message: message, at: path, verbose: false)
        // LibGit2 在没有可暂存内容时返回 -1
        guard index >= 0 else { return nil }
        logger.info("Stash pushed: index=\(index), message=\(message ?? "<default>")")
        return index
    }

    public static func pop(index: Int = 0, at path: String) throws {
        try LibGit2.stashPop(index: index, at: path, verbose: false)
        logger.info("Stash popped: index=\(index)")
    }

    public static func apply(index: Int = 0, at path: String) throws {
        try LibGit2.stashApply(index: index, at: path, verbose: false)
        logger.info("Stash applied: index=\(index)")
    }

    public static func drop(index: Int = 0, at path: String) throws {
        try LibGit2.stashDrop(index: index, at: path, verbose: false)
        logger.info("Stash dropped: index=\(index)")
    }

    public static func clear(at path: String) throws {
        try LibGit2.stashClear(at: path, verbose: false)
        logger.info("Stash cleared")
    }

    /// 将某个暂存条目转为一个分支（`git stash branch`）。
    public static func branch(name: String, index: Int, at path: String) throws {
        try LibGit2.stashBranch(name: name, index: index, at: path, verbose: false)
        logger.info("Stash branch created: name=\(name), index=\(index)")
    }
}

/// 业务错误包装。面板层捕获后用于 toast 提示。
public enum GitStashError: LocalizedError {
    case pushFailed(String)
    case popFailed(String)
    case applyFailed(String)
    case dropFailed(String)
    case clearFailed(String)
    case branchFailed(String)
    case invalidBranchName(String)

    public var errorDescription: String? {
        switch self {
        case .pushFailed(let m):      return "Stash push failed: \(m)"
        case .popFailed(let m):       return "Stash pop failed: \(m)"
        case .applyFailed(let m):     return "Stash apply failed: \(m)"
        case .dropFailed(let m):      return "Stash drop failed: \(m)"
        case .clearFailed(let m):     return "Stash clear failed: \(m)"
        case .branchFailed(let m):    return "Stash branch failed: \(m)"
        case .invalidBranchName(let m): return m
        }
    }
}
