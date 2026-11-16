import Foundation

/// SSH 执行错误。
public enum SSHError: Error, LocalizedError {
    case launchFailed(String)
    case remoteFailed(exitCode: Int32, message: String)

    public var errorDescription: String? {
        switch self {
        case .launchFailed(let reason):
            return "Failed to launch ssh: \(reason)"
        case .remoteFailed(let code, let message):
            return "ssh exited with code \(code): \(message)"
        }
    }
}

/// 通过系统 `ssh` 二进制执行远程命令。
///
/// MVP 选择驱动系统 ssh：零第三方依赖，天然兼容 `~/.ssh/config`、
/// ssh-agent 与现有密钥。超时由 `ConnectTimeout` / `ServerAliveInterval`
/// 保证，不会无限挂起。
public enum SSHClient {
    /// 在目标服务器上执行命令并返回 stdout。非零退出码抛出 `SSHError`。
    public static func run(config: ServerConfig, command: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")

            var arguments = [
                "-o", "BatchMode=yes",
                "-o", "ConnectTimeout=8",
                "-o", "ServerAliveInterval=5",
                "-o", "ServerAliveCountMax=2",
                // TOFU：首次连接记录主机指纹，之后指纹变化仍会拒绝。
                "-o", "StrictHostKeyChecking=accept-new",
                "-p", String(config.port),
            ]
            if let identityFile = config.identityFile, !identityFile.isEmpty {
                arguments += ["-i", identityFile]
            }
            arguments += [config.destination, command]
            process.arguments = arguments

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            let stdoutBox = DataBox()
            let stderrBox = DataBox()
            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                stdoutBox.append(handle.availableData)
            }
            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                stderrBox.append(handle.availableData)
            }

            process.terminationHandler = { proc in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                stdoutBox.append(stdoutPipe.fileHandleForReading.availableData)
                stderrBox.append(stderrPipe.fileHandleForReading.availableData)

                let outText = String(decoding: stdoutBox.data, as: UTF8.self)
                let errText = String(decoding: stderrBox.data, as: UTF8.self)
                if proc.terminationStatus == 0 {
                    continuation.resume(returning: outText)
                } else {
                    let message = errText.isEmpty ? outText : errText
                    continuation.resume(throwing: SSHError.remoteFailed(
                        exitCode: proc.terminationStatus,
                        message: message.trimmingCharacters(in: .whitespacesAndNewlines)
                    ))
                }
            }

            do {
                try process.run()
            } catch {
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                continuation.resume(throwing: SSHError.launchFailed(error.localizedDescription))
            }
        }
    }
}

/// 跨 readabilityHandler / terminationHandler 累积输出数据。
private final class DataBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.lock()
        storage.append(data)
        lock.unlock()
    }
}