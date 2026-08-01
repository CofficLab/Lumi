import Foundation
import ShellKit
import SuperLogKit
import os

/// 远程仓库（Git remote）解析服务
///
/// 视图无关：给定项目路径，返回该 Git 仓库 `origin` 远程的可访问 URL（已
/// 规范化：SSH → HTTPS、剥离 `.git` 后缀）。非 Git 仓库 / 无 origin 远程 /
///
/// ## 线程安全
///
/// `runGit` 内部调用 `ShellExecutor`（基于子进程），本身并发安全。本服务无
/// 共享可变状态，按值返回结果。
public final class RemoteRepositoryService: @unchecked Sendable, SuperLog {
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.open-remote.remote"
    )
    public nonisolated static let verbose: Bool = false
    public nonisolated static let emoji = "🌐"

    public static let shared = RemoteRepositoryService()

    private init() {}

    // MARK: - Public API

    /// 解析给定项目路径的远程仓库 URL。
    ///
    /// - Parameter projectPath: 项目根目录的绝对路径
    /// - Returns: 规范化后的远程 URL；若项目不是 Git 仓库、无 `origin` 远程、
    ///            或 URL 格式化失败，则返回 `nil`。
    public func resolveRemoteURL(for projectPath: String) async -> URL? {
        let projectURL = URL(fileURLWithPath: projectPath)
        let gitDir = projectURL.appendingPathComponent(".git", isDirectory: true)

        if Self.verbose {
            Self.logger.info("\(Self.t)resolveRemoteURL 探测 git 仓库, gitDir=\(gitDir.path, privacy: .public)")
        }

        guard FileManager.default.fileExists(atPath: gitDir.path) else {
            if Self.verbose {
                Self.logger.info("\(Self.t)resolveRemoteURL 不是 git 仓库, 返回 nil")
            }
            return nil
        }

        guard let remoteURLString = await runGit(args: ["remote", "get-url", "origin"], in: projectURL) else {
            if Self.verbose {
                Self.logger.info("\(Self.t)resolveRemoteURL git remote get-url 失败或为空, 返回 nil")
            }
            return nil
        }

        let formattedURL = Self.normalizeRemoteURL(remoteURLString)

        guard let result = URL(string: formattedURL) else {
            if Self.verbose {
                Self.logger.error("\(Self.t)resolveRemoteURL 格式化后的 URL 无效\(self.r("无法构造 URL: \(formattedURL)"))")
            }
            return nil
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)resolveRemoteURL 解析成功, url=\(result.absoluteString, privacy: .public)")
        }
        return result
    }

    // MARK: - URL 规范化（纯函数）

    /// 规范化 Git remote URL：
    /// - 去除首尾空白
    /// - SSH 格式 `git@host:user/repo.git` → `https://host/user/repo`
    /// - 剥离末尾 `.git`
    static func normalizeRemoteURL(_ raw: String) -> String {
        var url = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // git@github.com:username/repo.git -> https://github.com/username/repo.git
        if url.hasPrefix("git@") {
            url = url.replacingOccurrences(of: ":", with: "/", range: url.range(of: ":"))
            url = url.replacingOccurrences(of: "git@", with: "https://")
        }

        if url.hasSuffix(".git") {
            url = String(url.dropLast(4))
        }

        return url
    }

    // MARK: - Shell 包装

    private func runGit(args: [String], in directory: URL) async -> String? {
        let cmd = "git \(args.joined(separator: " "))"
        if Self.verbose {
            Self.logger.info("\(Self.t)runGit 执行, cwd=\(directory.path, privacy: .public), cmd=\(cmd, privacy: .public)")
        }

        let result = try? await ShellExecutor.execute(
            executable: "/usr/bin/git",
            arguments: args,
            options: ShellOptions(
                workingDirectory: directory.path,
                environment: [
                    "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
                ],
                throwsOnError: false
            )
        )

        guard let result else {
            if Self.verbose {
                Self.logger.error("\(Self.t)runGit 执行异常\(self.r("ShellExecutor 返回 nil"))")
            }
            return nil
        }

        if Self.verbose {
            if result.exitCode != 0 {
                Self.logger.error("\(Self.t)runGit 失败, exit=\(result.exitCode, privacy: .public), stderr=\(result.stderr, privacy: .public)")
            }
            Self.logger.info("\(Self.t)runGit 完成, exit=\(result.exitCode, privacy: .public)")
            Self.logger.info("\(Self.t)runGit stdout, value=\(result.stdout, privacy: .public)")
        }

        return result.exitCode == 0 ? result.stdout : nil
    }
}