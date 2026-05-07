import Foundation
import MagicKit

/// 探测 Node.js / Bun 运行时路径
struct JSEnvResolver: SuperLog {
    nonisolated static let emoji = "🔍"

    /// 探测到的 Node.js 路径
    static var nodePath: String? {
        findCommand("node")
    }

    /// 探测到的 Bun 路径
    static var bunPath: String? {
        findCommand("bun")
    }

    /// 探测到的 pnpm 路径
    static var pnpmPath: String? {
        findCommand("pnpm")
    }

    /// 探测到的 yarn 路径
    static var yarnPath: String? {
        findCommand("yarn")
    }

    /// 探测到的 npm 路径
    static var npmPath: String? {
        findCommand("npm")
    }

    /// 根据项目目录的锁文件推断包管理器
    static func detectPackageManager(projectPath: String) -> JSPackageInfo.PackageManager {
        let fm = FileManager.default
        let dir = URL(fileURLWithPath: projectPath)

        if fm.fileExists(atPath: dir.appendingPathComponent("bun.lockb").path)
            || fm.fileExists(atPath: dir.appendingPathComponent("bun.lock").path) {
            return .bun
        }
        if fm.fileExists(atPath: dir.appendingPathComponent("pnpm-lock.yaml").path) {
            return .pnpm
        }
        if fm.fileExists(atPath: dir.appendingPathComponent("yarn.lock").path) {
            return .yarn
        }
        return .npm
    }

    /// 获取包管理器的可执行路径
    static func packageManagerPath(_ manager: JSPackageInfo.PackageManager) -> String? {
        switch manager {
        case .npm: return npmPath
        case .pnpm: return pnpmPath
        case .yarn: return yarnPath
        case .bun: return bunPath
        }
    }

    // MARK: - Private

    private static func findCommand(_ command: String) -> String? {
        try? runShellCommand("/usr/bin/which", args: [command])?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func runShellCommand(_ path: String, args: [String]) throws -> String? {
        let process = Process()
        process.executableURL = URL(filePath: path)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
}
