import Foundation
import SuperLogKit
import os

/// 脚本执行结果
public struct JSScriptResult: Sendable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String
    public let duration: TimeInterval

    public var isSuccess: Bool { exitCode == 0 }
}

/// JS 运行时执行桥接
///
/// 根据项目锁文件自动选择包管理器（npm/pnpm/yarn/bun），
/// 统一执行 package.json 中的脚本。
public actor RuntimeBridge: SuperLog {
    public nonisolated static let emoji = "🚀"
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "js.runtime")
    nonisolated(unsafe) static var verbose: Bool = true

    public static let shared = RuntimeBridge()

    /// 执行 package.json 中的脚本
    ///
    /// - Parameters:
    ///   - script: 脚本名称（如 "dev", "build"）
    ///   - projectPath: 项目根目录
    ///   - arguments: 额外的透传参数
    /// - Returns: 执行结果
    public func run(script: String, projectPath: String, arguments: [String] = []) async -> JSScriptResult {
        let packageManager = JSEnvResolver.detectPackageManager(projectPath: projectPath)
        guard let pmPath = JSEnvResolver.packageManagerPath(packageManager) else {
            if Self.verbose {
                            Self.logger.error("\(Self.t)未找到 \(packageManager.rawValue) 可执行文件")
            }
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

        if Self.verbose {
                    Self.logger.info("\(Self.t)执行: \(pmPath) \(args.joined(separator: " "))")
        }

        let startTime = Date()
        let result = await executeProcess(executable: pmPath, arguments: args, currentDirectory: projectPath)
        let duration = Date().timeIntervalSince(startTime)

        if Self.verbose {
                    Self.logger.info("\(Self.t)完成: exitCode=\(result.exitCode), duration=\(String(format: "%.2f", duration))s")
        }

        return JSScriptResult(
            exitCode: result.exitCode,
            stdout: result.stdout,
            stderr: result.stderr,
            duration: duration
        )
    }

    /// 执行任意 Node.js 脚本
    public func runNode(script: String, projectPath: String) async -> JSScriptResult {
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

            let outputBuffer = ProcessOutputBuffer()
            let errorBuffer = ProcessOutputBuffer()
            outPipe.fileHandleForReading.readabilityHandler = { handle in
                outputBuffer.append(handle.availableData)
            }
            errPipe.fileHandleForReading.readabilityHandler = { handle in
                errorBuffer.append(handle.availableData)
            }

            process.terminationHandler = { _ in
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                outputBuffer.append(outPipe.fileHandleForReading.readDataToEndOfFile())
                errorBuffer.append(errPipe.fileHandleForReading.readDataToEndOfFile())

                let stdout = String(data: outputBuffer.data(), encoding: .utf8) ?? ""
                let stderr = String(data: errorBuffer.data(), encoding: .utf8) ?? ""
                continuation.resume(returning: (process.terminationStatus, stdout, stderr))
            }

            do {
                try process.run()
            } catch {
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                continuation.resume(returning: (-1, "", error.localizedDescription))
            }
        }
    }
}
