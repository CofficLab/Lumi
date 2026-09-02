import KitAgentTool
import Foundation
import KitShell

private struct ShellOutputChunk: Sendable {
    let stream: ToolExecutionOutputStream
    let text: String
}

/// 将 ShellExecutor 的同步输出回调按顺序桥接到异步 ToolExecutionContext。
private final class ShellOutputReporter: @unchecked Sendable {
    private let continuation: AsyncStream<ShellOutputChunk>.Continuation
    private let task: Task<Void, Never>

    init(context: ToolExecutionContext) {
        let (stream, continuation) = AsyncStream<ShellOutputChunk>.makeStream()
        self.continuation = continuation
        self.task = Task.detached {
            for await chunk in stream {
                await context.reportOutput(chunk.stream, chunk.text)
            }
        }
    }

    func report(_ stream: ToolExecutionOutputStream, text: String) {
        guard !text.isEmpty else { return }
        continuation.yield(ShellOutputChunk(stream: stream, text: text))
    }

    func finish() async {
        continuation.finish()
        await task.value
    }
}

/// 执行终端命令。
public struct ShellTool: SuperAgentTool, @unchecked Sendable {
    public let name = "run_command"

    private static let highRiskCommands: Set<String> = [
        "rm", "rmdir", "mv", "sudo", "kill", "killall", "chmod", "chown", "dd", "shutdown", "reboot"
    ]
    private let commandTimeout: TimeInterval
    private let workspaceRootProvider: @MainActor @Sendable () -> String?

    public init(
        commandTimeout: TimeInterval = 120,
        workspaceRootProvider: @escaping @MainActor @Sendable () -> String? = { nil }
    ) {
        self.commandTimeout = commandTimeout
        self.workspaceRootProvider = workspaceRootProvider
    }

    public func description(for language: LanguagePreference) -> String {
        "Execute a shell command in the terminal. Commands may run for a while, can be cancelled, and captured output is size-limited."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "command": ["type": "string", "description": "The shell command to execute; it may run for a while and can be cancelled. Output is size-limited."],
                "timeout": ["type": "integer", "description": "Optional timeout in seconds (default: 120)"],
            ],
            "required": ["command"],
        ]
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        guard let command = arguments.stringValue("command") else { return .high }
        let base = command
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
            .first
            .map(String.init)?
            .lowercased() ?? ""
        return Self.highRiskCommands.contains(base) ? .high : .low
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let command = arguments.stringValue("command") else { return "运行命令" }
        let preview = command.count > 40 ? String(command.prefix(40)) + "…" : command
        return "运行 \(preview)"
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let (command, options) = try await executionRequest(arguments: arguments)
        let result = try await ShellExecutor.execute(
            executable: "/bin/zsh",
            arguments: ["-lc", command],
            options: options
        )
        return Self.resultText(for: result)
    }

    public func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        let (command, options) = try await executionRequest(arguments: arguments)
        let reporter = ShellOutputReporter(context: context)

        do {
            let result = try await ShellExecutor.executeStreaming(
                executable: "/bin/zsh",
                arguments: ["-lc", command],
                options: options,
                onOutput: { chunk in
                    reporter.report(.stdout, text: chunk)
                },
                onError: { chunk in
                    reporter.report(.stderr, text: chunk)
                }
            )
            await reporter.finish()
            return ToolCallResult(content: Self.resultText(for: result))
        } catch {
            await reporter.finish()
            throw error
        }
    }

    private func executionRequest(
        arguments: [String: ToolArgument]
    ) async throws -> (command: String, options: ShellOptions) {
        guard let command = arguments.stringValue("command"),
              !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw NSError(domain: "ShellTool", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing command"])
        }

        let timeout = TimeInterval(arguments.intValue("timeout") ?? Int(commandTimeout))

        let workspaceRoot = await workspaceRootProvider()?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let options = ShellOptions(
            workingDirectory: workspaceRoot?.isEmpty == false
                ? workspaceRoot
                : FileManager.default.homeDirectoryForCurrentUser.path,
            timeout: timeout,
            throwsOnError: false
        )
        return (command, options)
    }

    private static func resultText(for result: ShellResult) -> String {
        if result.exitCode != 0 {
            return "Exit code: \(result.exitCode)\n\(result.stdout)\n\(result.stderr)"
        }

        let combined = (result.stdout + result.stderr).trimmingCharacters(in: .whitespacesAndNewlines)
        return combined.isEmpty ? "Command completed successfully." : combined
    }
}
