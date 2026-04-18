import Foundation

/// Git 分支操作服务
enum GitBranchService {
    // MARK: - 分支查询

    /// 获取指定路径的当前 Git 分支名
    /// - Parameter path: 项目根目录路径
    /// - Returns: 分支名，如果不是 Git 仓库则返回 nil
    static func currentBranch(at path: String) -> String? {
        let result = runGitSync(path, args: ["rev-parse", "--abbrev-ref", "HEAD"])
        guard result.success, let output = result.output, !output.isEmpty else {
            return nil
        }
        return output
    }

    /// 获取所有本地分支列表
    /// - Parameter path: 项目根目录路径
    /// - Returns: 本地分支数组
    static func listLocalBranches(at path: String) -> [GitBranch] {
        let result = runGitSync(path, args: ["branch", "--format=%(refname:short)\t%(subject)\t%(committerdate:iso8601)"])
        guard result.success, let output = result.output else { return [] }

        return output.split(separator: "\n").compactMap { line -> GitBranch? in
            let parts = line.split(separator: "\t", maxSplits: 2)
            guard parts.count >= 1 else { return nil }

            var rawName = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let isCurrent = rawName.hasPrefix("* ")
            if isCurrent {
                rawName = String(rawName.dropFirst(2))
            }

            let subject = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : nil

            let date: Date?
            if parts.count > 2 {
                let rawDate = String(parts[2]).trimmingCharacters(in: .whitespaces)
                date = Self.parseGitDate(rawDate)
            } else {
                date = nil
            }

            return GitBranch(
                name: rawName,
                isCurrent: isCurrent,
                isRemote: false,
                lastCommitSubject: subject,
                lastCommitDate: date
            )
        }
    }

    /// 获取所有远程分支列表
    /// - Parameter path: 项目根目录路径
    /// - Returns: 远程分支数组
    static func listRemoteBranches(at path: String) -> [GitBranch] {
        let result = runGitSync(path, args: ["branch", "-r", "--format=%(refname:short)\t%(subject)\t%(committerdate:iso8601)"])
        guard result.success, let output = result.output else { return [] }

        return output.split(separator: "\n").compactMap { line -> GitBranch? in
            let parts = line.split(separator: "\t", maxSplits: 2)
            guard parts.count >= 1 else { return nil }

            let rawName = String(parts[0]).trimmingCharacters(in: .whitespaces)
            // 跳过 HEAD 指向
            guard !rawName.contains("HEAD ->") else { return nil }

            let subject = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : nil

            let date: Date?
            if parts.count > 2 {
                let rawDate = String(parts[2]).trimmingCharacters(in: .whitespaces)
                date = Self.parseGitDate(rawDate)
            } else {
                date = nil
            }

            return GitBranch(
                name: rawName,
                isCurrent: false,
                isRemote: true,
                lastCommitSubject: subject,
                lastCommitDate: date
            )
        }
    }

    // MARK: - 分支操作

    /// 切换到指定分支
    /// - Parameters:
    ///   - branch: 分支名称
    ///   - path: 项目根目录路径
    ///   - force: 是否强制切换（放弃未提交的更改）
    /// - Throws: GitError
    static func checkout(branch: String, at path: String, force: Bool = false) throws {
        var args = ["checkout"]
        if force { args.append("-f") }
        args.append(branch)

        let result = runGitSync(path, args: args)
        if result.success { return }

        // 如果是脏工作区导致的失败，抛出更友好的错误
        if let output = result.output, output.contains("stash") || output.contains("commit") {
            throw GitError.dirtyWorkingTree
        }

        throw GitError.checkoutFailed(result.error ?? result.output ?? "Unknown error")
    }

    /// 从远程分支创建本地跟踪分支
    /// - Parameters:
    ///   - remoteBranch: 远程分支名（如 origin/feature）
    ///   - path: 项目根目录路径
    /// - Throws: GitError
    static func checkoutRemoteBranch(_ remoteBranch: String, at path: String) throws {
        let result = runGitSync(path, args: ["checkout", "--track", remoteBranch])
        guard result.success else {
            throw GitError.checkoutFailed(result.error ?? result.output ?? "Unknown error")
        }
    }

    /// 创建新分支
    /// - Parameters:
    ///   - name: 新分支名称
    ///   - from: 起始分支（默认为当前分支）
    ///   - path: 项目根目录路径
    /// - Throws: GitError
    static func createBranch(_ name: String, from: String? = nil, at path: String) throws {
        var args = ["branch"]
        if let from {
            args.append(name)
            args.append(from)
        } else {
            args.append(name)
        }

        let result = runGitSync(path, args: args)
        guard result.success else {
            throw GitError.createBranchFailed(result.error ?? result.output ?? "Unknown error")
        }
    }

    /// 拉取远程更新
    /// - Parameter path: 项目根目录路径
    /// - Throws: GitError
    static func fetch(at path: String) throws {
        let result = runGitSync(path, args: ["fetch", "--all"])
        guard result.success else {
            throw GitError.fetchFailed(result.error ?? result.output ?? "Unknown error")
        }
    }

    // MARK: - 工作区状态

    /// 检查工作区是否有未提交的更改
    /// - Parameter path: 项目根目录路径
    /// - Returns: 是否有未提交的更改
    static func isWorkingTreeDirty(at path: String) -> Bool {
        let result = runGitSync(path, args: ["status", "--porcelain"])
        guard result.success, let output = result.output else { return false }
        return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Git 信息获取

    /// 获取 Git 仓库详细信息
    /// - Parameter path: 项目根目录路径
    /// - Returns: Git 信息
    static func getGitInfo(at path: String) -> GitInfo? {
        guard let branch = currentBranch(at: path) else {
            return nil
        }

        let remote = getRemote(at: path)
        let (lastCommit, author) = getLastCommit(at: path)
        let isDirty = isWorkingTreeDirty(at: path)

        return GitInfo(
            branch: branch,
            remote: remote,
            lastCommit: lastCommit,
            author: author,
            isDirty: isDirty
        )
    }

    // MARK: - 私有方法

    private struct GitResult {
        let success: Bool
        let output: String?
        let error: String?
    }

    private static func runGitSync(_ path: String, args: [String]) -> GitResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "-C", path] + args

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
            process.waitUntilExit()

            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()

            let outStr = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let errStr = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)

            return GitResult(
                success: process.terminationStatus == 0,
                output: outStr,
                error: errStr
            )
        } catch {
            return GitResult(success: false, output: nil, error: error.localizedDescription)
        }
    }

    /// 解析 Git ISO 8601 日期格式
    private static func parseGitDate(_ raw: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate]
        return formatter.date(from: raw)
    }

    private static func getRemote(at path: String) -> String {
        let result = runGitSync(path, args: ["remote", "-v"])
        guard result.success, let output = result.output else { return "无" }
        return output.components(separatedBy: "\n")
            .first?
            .components(separatedBy: CharacterSet.whitespaces)
            .first ?? "无"
    }

    private static func getLastCommit(at path: String) -> (message: String, author: String) {
        let msgResult = runGitSync(path, args: ["log", "-1", "--pretty=%s"])
        let authorResult = runGitSync(path, args: ["log", "-1", "--pretty=%an"])

        let message = msgResult.output?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let author = authorResult.output?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return (message: message.isEmpty ? "无" : message, author: author.isEmpty ? "无" : author)
    }
}
