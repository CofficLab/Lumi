import Foundation
import os
import MagicKit

/// 脚本执行结果
struct JSScriptResult: Sendable {
    let exitCode: Int32
    let stdout: String
    let stderr: String
    let duration: TimeInterval

    var isSuccess: Bool { exitCode == 0 }
}

/// JS 运行时执行桥接
///
/// 根据项目锁文件自动选择包管理器（npm/pnpm/yarn/bun），
/// 统一执行 package.json 中的脚本。
actor RuntimeBridge: SuperLog {
    nonisolated static let emoji = "🚀"
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "js.runtime")

    static let shared = RuntimeBridge()

    /// 执行 package.json 中的脚本
    ///
    /// - Parameters:
    ///   - script: 脚本名称（如 "dev", "build"）
    ///   - projectPath: 项目根目录
    ///   - arguments: 额外的透传参数
    /// - Returns: 执行结果
    func run(script: String, projectPath: String, arguments: [String] = []) async -> JSScriptResult {
        let packageManager = JSEnvResolver.detectPackageManager(projectPath: projectPath)
        guard let pmPath = JSEnvResolver.packageManagerPath(packageManager) else {
            logger.error("\(Self.t)未找到 \(packageManager.rawValue) 可执行文件")
            return JSScriptResult(exitCode: -1, stdout: "", stderr: "Package manager '\(packageManager.rawValue)' not found", duration: 0)
        }

        var args: [String]
        switch packageManager {
        case .bun:
            args = ["run", script]
        default:
            args = ["run", script]
        }
        args.append(contentsOf: arguments)

        logger.info("\(Self.t)执行: \(pmPath) \(args.joined(separator: " "))")

        let startTime = Date()
        let result = await executeProcess(executable: pmPath, arguments: args, currentDirectory: projectPath)
        let duration = Date().timeIntervalSince(startTime)

        logger.info("\(Self.t)完成: exitCode=\(result.exitCode), duration=\(String(format: "%.2f", duration))s")

        return JSScriptResult(
            exitCode: result.exitCode,
            stdout: result.stdout,
            stderr: result.stderr,
            duration: duration
        )
    }

    /// 执行任意 Node.js 脚本
    func runNode(script: String, projectPath: String) async -> JSScriptResult {
        guard let nodePath = JSEnvResolver.nodePath else {
            return JSScriptResult(exitCode: -1, stdout: "", stderr: "Node.js not found", duration: 0)
        }

        let startTime = Date()
        let result = await executeProcess(executable: nodePath, arguments: [script], currentDirectory: projectPath)
        let duration = Date().timeIntervalSince(startTime)

        return JSScriptResult(
            exitCode: result.exitCode,
            stdout: result.stdout,
            stderr: result.stderr,
            duration: duration
        )
    }

    // MARK: - Private

    private func executeProcess(executable: String, arguments: [String], currentDirectory: String) async -> (exitCode: Int32, stdout: String, stderr: String) {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(filePath: executable)
            process.arguments = arguments
            process.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe

            process.terminationHandler = { _ in
                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let stdout = String(data: outData, encoding: .utf8) ?? ""
                let stderr = String(data: errData, encoding: .utf8) ?? ""
                continuation.resume(returning: (process.terminationStatus, stdout, stderr))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(returning: (-1, "", error.localizedDescription))
            }
        }
    }
}
