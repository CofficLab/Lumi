import Foundation
import MagicKit
import OSLog

/// GitHub CLI 检测服务
///
/// 检测用户是否安装了 GitHub CLI (gh) 命令行工具
final class GitHubCLIDetectService: @unchecked Sendable, SuperLog {
    nonisolated static let emoji = "🔍"
    nonisolated static let verbose = true

    static let shared = GitHubCLIDetectService()

    private init() {}

    // MARK: - 公开方法

    /// 检测是否安装了 gh 命令行工具
    /// - Returns: 如果已安装返回 true
    func isInstalled() -> Bool {
        let installed = checkGHInstallation()
        if Self.verbose {
            os_log("\(self.t)🔍 gh 安装状态：\(installed ? "已安装" : "未安装")")
        }
        return installed
    }

    /// 获取 gh 版本信息
    /// - Returns: 版本号，如果未安装则返回 nil
    func getVersion() -> String? {
        guard isInstalled() else { return nil }
        return getGHVersion()
    }

    /// 获取 gh 安装路径
    /// - Returns: 安装路径，如果未安装则返回 nil
    func getInstallationPath() -> String? {
        guard isInstalled() else { return nil }
        return findGHPath()
    }

    /// 获取检测详情
    /// - Returns: 包含安装状态、版本、路径的详情信息
    func getDetectionDetails() -> GitHubCLIDetectionResult {
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
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["gh"]
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                return true
            }
        } catch {
            if Self.verbose {
                os_log("\(self.t)❌ 检查 gh 安装失败：\(error.localizedDescription)")
            }
        }

        return false
    }

    /// 获取 gh 路径
    private func findGHPath() -> String? {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["gh"]
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            if Self.verbose {
                os_log("\(self.t)❌ 获取 gh 路径失败：\(error.localizedDescription)")
            }
        }

        return nil
    }

    /// 获取 gh 版本
    private func getGHVersion() -> String? {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", "gh --version"]
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)

                // 解析版本号，gh --version 输出格式：
                // gh version 2.40.1 (2023-12-01)
                // https://github.com/cli/cli/releases/tag/v2.40.1
                if let firstLine = output?.split(separator: "\n").first {
                    return String(firstLine)
                }
                return output
            }
        } catch {
            if Self.verbose {
                os_log("\(self.t)❌ 获取 gh 版本失败：\(error.localizedDescription)")
            }
        }

        return nil
    }
}

/// GitHub CLI 检测结果
struct GitHubCLIDetectionResult: Sendable {
    /// 是否已安装
    let installed: Bool
    /// 版本号
    let version: String?
    /// 安装路径
    let path: String?

    /// 获取用户友好的描述
    var description: String {
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
