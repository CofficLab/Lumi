import Foundation
import SuperLogKit
import ShellKit

/// 探测 Node.js / Bun 运行时路径
public struct JSEnvResolver: SuperLog {
    public nonisolated static let emoji = "🔍"

    /// 探测到的 Node.js 路径
    public static var nodePath: String? {
        findCommand("node")
    }

    /// 探测到的 Bun 路径
    public static var bunPath: String? {
        findCommand("bun")
    }

    /// 探测到的 pnpm 路径
    public static var pnpmPath: String? {
        findCommand("pnpm")
    }

    /// 探测到的 yarn 路径
    public static var yarnPath: String? {
        findCommand("yarn")
    }

    /// 探测到的 npm 路径
    public static var npmPath: String? {
        findCommand("npm")
    }

    /// 根据项目目录的锁文件和 package.json 推断包管理器
    public static func detectPackageManager(projectPath: String) -> JSPackageInfo.PackageManager {
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
        if let package = PackageJSONParser.parse(projectPath: projectPath) {
            return package.inferredPackageManager
        }
        return .npm
    }

    /// 获取包管理器的可执行路径
    public static func packageManagerPath(_ manager: JSPackageInfo.PackageManager) -> String? {
        switch manager {
        case .npm: return npmPath
        case .pnpm: return pnpmPath
        case .yarn: return yarnPath
        case .bun: return bunPath
        }
    }

    // MARK: - Private

    public static func findCommand(_ command: String) -> String? {
        Shell.findCommandSync(command)
    }

    private static func runShellCommand(_ path: String, args: [String]) throws -> String? {
        runShellCommandSync(path, args: args)
    }

    private static func runShellCommandSync(_ path: String, args: [String]) -> String? {
        let semaphore = DispatchSemaphore(value: 0)
        let box = LockedStringBox()
        Task {
            let result = try? await Shell.execute(
                executable: path,
                arguments: args,
                options: ShellOptions(throwsOnError: false)
            )
            box.set(result?.exitCode == 0 ? result?.stdout : nil)
            semaphore.signal()
        }
        semaphore.wait()
        return box.get()
    }
}

private final class LockedStringBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: String?

    public func set(_ value: String?) {
        lock.lock()
        self.value = value
        lock.unlock()
    }

    public func get() -> String? {
        lock.lock()
        let result = value
        lock.unlock()
        return result
    }
}
