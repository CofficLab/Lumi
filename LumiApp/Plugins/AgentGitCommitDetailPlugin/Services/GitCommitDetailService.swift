import AppKit
import SwiftUI

/// Git Commit Detail 服务
///
/// 承担 GitCommitDetailView 中的无状态逻辑，包括：
/// - 日期格式化
/// - 文件图标/颜色映射
/// - 复制 Hash 到剪贴板
/// - 加载 Commit 详情、工作区变更、文件 Diff 的数据获取
enum GitCommitDetailService {
    // MARK: - Date Formatting

    /// 将日期字符串（多种 ISO 格式）统一格式化为 "yyyy-MM-dd HH:mm:ss"
    static func formattedDate(_ dateString: String) -> String {
        let formatters = DateParseHelper.formatHandlers

        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                let displayFormatter = DateFormatter()
                displayFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                displayFormatter.locale = Locale(identifier: "en_US_POSIX")
                return displayFormatter.string(from: date)
            }
        }

        return dateString
    }

    // MARK: - File Icon

    /// 根据文件扩展名返回 SF Symbol 图标名称
    static func fileIcon(for file: String) -> String {
        let ext = (file as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "js", "ts", "jsx", "tsx": return "doc.text.fill"
        case "json": return "braces"
        case "md", "markdown": return "doc.text"
        case "yml", "yaml": return "doc.text"
        case "plist": return "gearshape"
        case "png", "jpg", "jpeg", "gif", "svg", "ico": return "photo"
        case "xcodeproj", "xcworkspace": return "hammer"
        case "html", "css": return "globe"
        case "py": return "doc.text.fill"
        case "rb": return "doc.text.fill"
        case "go": return "doc.text.fill"
        case "rs": return "doc.text.fill"
        default: return "doc.text"
        }
    }

    /// 根据文件扩展名返回图标颜色
    static func fileIconColor(for file: String) -> Color {
        let ext = (file as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return .orange
        case "js", "ts": return .yellow
        case "json": return .green
        case "md": return .blue
        default: return .secondary
        }
    }

    // MARK: - Clipboard

    /// 将 commit hash 复制到系统剪贴板
    static func copyHash(_ hash: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(hash, forType: .string)
        #endif
    }

    // MARK: - Load Commit Detail

    /// 加载指定 commit 的详情和变更文件列表
    ///
    /// - Parameters:
    ///   - path: 项目路径
    ///   - hash: Commit Hash
    /// - Returns: (commit 详情, 变更文件列表)
    static func loadCommitDetail(path: String, hash: String) async throws -> (GitCommitDetail, [GitChangedFile]) {
        async let detailTask = GitService.shared.getCommitDetail(path: path, hash: hash)
        async let filesTask = Task.detached(priority: .userInitiated) {
            try GitService.shared.getCommitChangedFiles(path: path, hash: hash)
        }

        let detail = try await detailTask
        let files = (try? await filesTask.value) ?? []
        return (detail, files)
    }

    // MARK: - Load Working State

    /// 加载未提交变更的文件列表
    ///
    /// - Parameter path: 项目路径
    /// - Returns: 变更文件列表
    static func loadUncommittedFiles(path: String) async throws -> [GitChangedFile] {
        try await GitService.shared.getUncommittedChanges(path: path)
    }

    // MARK: - Project Overview Info

    /// 项目 Git 概览信息
    struct ProjectGitInfo {
        let branch: String
        let remote: String
        let totalCommits: Int
        let contributors: [String]
        let lastCommitMessage: String
        let lastCommitAuthor: String
        let lastCommitDate: String
    }

    /// 加载项目 Git 概览信息（工作区干净时显示）
    static func loadProjectGitInfo(path: String) async -> ProjectGitInfo? {
        // 并发执行多个 git 命令
        async let branchTask = runGit(path, args: ["rev-parse", "--abbrev-ref", "HEAD"])
        async let remoteTask = runGit(path, args: ["remote", "-v"])
        async let totalCommitsTask = runGit(path, args: ["rev-list", "--count", "HEAD"])
        async let shortlogTask = runGit(path, args: ["shortlog", "-sn", "HEAD"])
        async let lastMsgTask = runGit(path, args: ["log", "-1", "--pretty=%s"])
        async let lastAuthorTask = runGit(path, args: ["log", "-1", "--pretty=%an"])
        async let lastDateTask = runGit(path, args: ["log", "-1", "--pretty=%ai"])

        let branch = await branchTask.trimmingCharacters(in: .whitespacesAndNewlines)
        let remoteRaw = await remoteTask
        let totalCommitsStr = await totalCommitsTask.trimmingCharacters(in: .whitespacesAndNewlines)
        let shortlog = await shortlogTask
        let lastMsg = await lastMsgTask.trimmingCharacters(in: .whitespacesAndNewlines)
        let lastAuthor = await lastAuthorTask.trimmingCharacters(in: .whitespacesAndNewlines)
        let lastDate = await lastDateTask.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !branch.isEmpty else { return nil }

        // 解析 remote：取第一行的第一个 URL 部分
        let remote: String
        if let firstLine = remoteRaw.components(separatedBy: "\n").first {
            // 格式: "origin\tgit@github.com:user/repo.git (fetch)"
            let parts = firstLine.components(separatedBy: "\t")
            if parts.count > 1 {
                let urlString = parts[1].components(separatedBy: " ").first ?? parts[1]
                // 提取简洁的路径部分 (user/repo)
                if urlString.hasSuffix(".git") {
                    remote = String(urlString.dropLast(4))
                        .components(separatedBy: ":").last ?? urlString
                } else {
                    remote = urlString
                }
            } else {
                remote = firstLine
            }
        } else {
            remote = "—"
        }

        // 解析贡献者
        let contributors = shortlog.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { line -> String in
                // 格式: "  123\tAuthor Name"
                let parts = line.components(separatedBy: "\t")
                return parts.count > 1 ? parts[1] : line
            }

        let totalCommits = Int(totalCommitsStr) ?? 0

        return ProjectGitInfo(
            branch: branch,
            remote: remote,
            totalCommits: totalCommits,
            contributors: contributors,
            lastCommitMessage: lastMsg.isEmpty ? "—" : lastMsg,
            lastCommitAuthor: lastAuthor.isEmpty ? "—" : lastAuthor,
            lastCommitDate: lastDate.isEmpty ? "—" : formattedDate(lastDate)
        )
    }

    // MARK: - Git Command Helper

    /// 执行 git 命令并返回输出
    private static func runGit(_ path: String, args: [String]) async -> String {
        await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["git", "-C", path] + args

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                return String(data: data, encoding: .utf8) ?? ""
            } catch {
                return ""
            }
        }.value
    }

    // MARK: - Load File Diff

    /// 加载指定文件的 diff 内容
    ///
    /// - Parameters:
    ///   - file: 文件路径
    ///   - projectPath: 项目路径
    ///   - commitHash: 若为 nil 则加载未提交变更的 diff，否则加载指定 commit 的 diff
    /// - Returns: (旧文本, 新文本)
    static func loadFileDiff(file: String, projectPath: String, commitHash: String?) async throws -> (String, String) {
        if let hash = commitHash {
            let (before, after) = try await GitService.shared.getCommitFileContentChange(
                path: projectPath,
                hash: hash,
                file: file
            )
            return (before ?? "", after ?? "")
        } else {
            let (before, after) = try await GitService.shared.getUncommittedFileContentChange(
                path: projectPath,
                file: file
            )
            return (before ?? "", after ?? "")
        }
    }
}
