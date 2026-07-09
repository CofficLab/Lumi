import Foundation
import ShellKit
import SuperLogKit

/// GitHub CLI 检测服务
///
/// 检测用户是否安装了 GitHub CLI (gh) 命令行工具
public final class GitHubCLIDetectService: @unchecked Sendable, SuperLog {
    public nonisolated static let emoji = "🔍"
    public nonisolated static let verbose: Bool = true
    public static let shared = GitHubCLIDetectService()

    typealias CommandRunner = @Sendable (String) -> ShellResult?
    private let commandRunner: CommandRunner

    public convenience init() {
        self.init(commandRunner: Self.runShellCommand)
    }

    init(commandRunner: @escaping CommandRunner) {
        self.commandRunner = commandRunner
    }

    // MARK: - 公开方法

    /// 检测是否安装了 gh 命令行工具
    /// - Returns: 如果已安装返回 true
    public func isInstalled() -> Bool {
        if Self.verbose {
            if GitHubPlugin.verbose {
                GitHubPlugin.logger.info("\(self.t)开始检查 gh 安装...")
            }
        }
        let installed = checkGHInstallation()
        if Self.verbose {
            if GitHubPlugin.verbose {
                GitHubPlugin.logger.info("\(self.t)gh 安装状态：\(installed ? "已安装" : "未安装")")
            }
        }
        return installed
    }

    /// 获取 gh 版本信息
    /// - Returns: 版本号，如果未安装则返回 nil
    public func getVersion() -> String? {
        guard isInstalled() else { return nil }
        return getGHVersion()
    }

    /// 获取 gh 安装路径
    /// - Returns: 安装路径，如果未安装则返回 nil
    public func getInstallationPath() -> String? {
        guard isInstalled() else { return nil }
        return findGHPath()
    }

    /// 获取检测详情
    /// - Returns: 包含安装状态、版本、路径的详情信息
    public func getDetectionDetails() -> GitHubCLIDetectionResult {
        let installed = isInstalled()
        let version = installed ? getVersion() : nil
        let path = installed ? getInstallationPath() : nil

        return GitHubCLIDetectionResult(
            installed: installed,
            version: version,
            path: path
        )
    }

    // MARK: - 私有方法

    /// 检查 gh 是否安装
    private func checkGHInstallation() -> Bool {
        if Self.verbose {
            if GitHubPlugin.verbose {
                GitHubPlugin.logger.info("\(self.t)执行 which gh 命令...")
            }
        }

        let result = runGHCommand("which gh")
        if let result {
            if Self.verbose {
                if GitHubPlugin.verbose {
                    GitHubPlugin.logger.info("\(self.t)which gh 终止状态：\(result.exitCode)")
                }
            }

            if result.exitCode == 0 {
                return true
            }
            let errorOutput = result.stderr.isEmpty ? result.stdout : result.stderr
            if Self.verbose {
                if GitHubPlugin.verbose {
                    GitHubPlugin.logger.error("\(self.t)which gh 错误输出：\(errorOutput.isEmpty ? "无输出" : errorOutput)")
                }
            }
        } else if Self.verbose {
            if GitHubPlugin.verbose {
                GitHubPlugin.logger.error("\(self.t)检查 gh 安装失败")
            }
        }

        return false
    }

    /// 获取 gh 路径
    private func findGHPath() -> String? {
        guard let result = runGHCommand("which gh") else {
            if Self.verbose { GitHubPlugin.logger.error("\(self.t)获取 gh 路径失败") }
            return nil
        }
        return result.exitCode == 0 ? result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) : nil
    }

    /// 获取 gh 版本
    private func getGHVersion() -> String? {
        guard let result = runGHCommand("gh --version") else {
            if Self.verbose { GitHubPlugin.logger.error("\(self.t)获取 gh 版本失败") }
            return nil
        }

        guard result.exitCode == 0 else { return nil }
        let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if let firstLine = output.split(separator: "\n").first {
            return String(firstLine)
        }
        return output
    }

    private func runGHCommand(_ command: String) -> ShellResult? {
        commandRunner(command)
    }

    private static func runShellCommand(_ command: String) -> ShellResult? {
        let semaphore = DispatchSemaphore(value: 0)
        let box = GitHubCLILockedResultBox()
        Task {
            let result = try? await Shell.execute(
                command,
                options: ShellOptions(
                    shellExecutable: "/bin/zsh",
                    environment: [
                        "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
                    ],
                    throwsOnError: false
                )
            )
            box.set(result)
            semaphore.signal()
        }
        semaphore.wait()
        return box.get()
    }
}

private final class GitHubCLILockedResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: ShellResult?

    func set(_ value: ShellResult?) {
        lock.lock()
        self.value = value
        lock.unlock()
    }

    func get() -> ShellResult? {
        lock.lock()
        let result = value
        lock.unlock()
        return result
    }
}

/// GitHub CLI 检测结果
public struct GitHubCLIDetectionResult: Sendable {
    /// 是否已安装
    public let installed: Bool
    /// 版本号
    public let version: String?
    /// 安装路径
    public let path: String?

    public init(installed: Bool, version: String?, path: String?) {
        self.installed = installed
        self.version = version
        self.path = path
    }

    /// 获取用户友好的描述
    public var description: String {
        if installed {
            var desc = "✅ GitHub CLI (gh) 已安装"
            if let version = version {
                desc += "\n版本：\(version)"
            }
            if let path = path {
                desc += "\n路径：\(path)"
            }
            return desc
        } else {
            return """
            ❌ GitHub CLI (gh) 未安装

            安装方法：
            1. 使用 Homebrew: brew install gh
            2. 从官网下载：https://cli.github.com/
            3. 查看文档：https://github.com/cli/cli#installation
            """
        }
    }
}
