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
    public let executionCapability: ToolExecutionCapability = .serialSideEffect

    /// Upper bound for a caller-supplied `max_output_bytes` (16 MiB per stream).
    static let maxOutputBytesCeiling = 16 * 1024 * 1024

    /// Upper bound for the foreground budget (10 minutes).
    ///
    /// The budget is not a kill deadline anymore — it is the point at which the
    /// command is handed off to the background. Capping it keeps the model's
    /// "how long do I wait" expectation bounded while never killing work.
    static let maxForegroundBudgetSeconds = 600

    private let commandTimeout: TimeInterval
    private let workspaceRootProvider: @MainActor @Sendable () -> String?
    private let backgroundTaskRegistryProvider: @MainActor @Sendable () -> BackgroundTaskRegistry?
    /// 当前选中的会话 ID。
    ///
    /// 无上下文的 `execute(arguments:)` 路径没有会话信息，但后台任务的完成
    /// 通知必须送回**发起它的会话**。这里退回到当前选中的会话：猜错的后果是
    /// 通知投递到一个用户正在看的会话，而不是通知消失。
    private let currentConversationIDProvider: @MainActor @Sendable () -> UUID?

    public init(
        commandTimeout: TimeInterval = 120,
        workspaceRootProvider: @escaping @MainActor @Sendable () -> String? = { nil },
        backgroundTaskRegistryProvider: @escaping @MainActor @Sendable () -> BackgroundTaskRegistry? = { nil },
        currentConversationIDProvider: @escaping @MainActor @Sendable () -> UUID? = { nil }
    ) {
        self.commandTimeout = commandTimeout
        self.workspaceRootProvider = workspaceRootProvider
        self.backgroundTaskRegistryProvider = backgroundTaskRegistryProvider
        self.currentConversationIDProvider = currentConversationIDProvider
    }

    public func description(for language: LanguagePreference) -> String {
        "Execute a shell command for files, builds and terminal tasks. Direct desktop control is sandboxed: do not use osascript, CGEvent, GUI launching or screenshots through this tool. For UI tasks use accessibility_observe/accessibility_act first, then managed computer_observe/computer_act if necessary. Commands can be cancelled and output is size-limited. Long commands do not block the turn: when the foreground budget (timeout, default 120s, max 600s) expires the command is NOT killed — it keeps running in the background, its output is written to a file you can read with read_file, and you are notified when it finishes. Set run_in_background=true to move a command to the background immediately. Set unsandboxed=true only when the command must create its own sandbox — for example swift build, xcodebuild or any Swift code using macros; it requires user approval unless the conversation is in autonomous (A3) mode, where it runs without approval."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "command": ["type": "string", "description": "The shell command to execute; it may run for a while and can be cancelled. Output is size-limited."],
                "timeout": ["type": "integer", "description": "Optional foreground budget in seconds (default: 120, max: 600). When the budget expires the command is NOT killed — it keeps running in the background, its output is written to a file you can read with read_file, and you are notified when it finishes."],
                "run_in_background": ["type": "boolean", "description": "Optional. Run the command in the background immediately instead of waiting for it. Output is written to a file you can read with read_file, and you are notified when it finishes. Defaults to false."],
                "unsandboxed": ["type": "boolean", "description": "Optional. Run outside the desktop-isolation sandbox. Required for commands that create their own sandbox (swift build, xcodebuild, Swift macro expansion). Requires user approval unless the conversation is in autonomous (A3) mode, where it runs without approval. Defaults to false."],
                "max_output_bytes": ["type": "integer", "description": "Optional. Maximum bytes kept from each output stream (default: 65536, max: 16777216). The tail is kept and the head dropped. Raise it when the useful output is larger than the default; otherwise redirect to a file and read it back."],
            ],
            "required": ["command"],
        ]
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        guard let command = arguments.stringValue("command") else { return .high }
        if arguments.boolValue("unsandboxed") == true { return .high }
        return ShellCommandRiskAnalyzer.riskLevel(for: command)
    }

    /// An unsandboxed call is declared as needing explicit approval.
    ///
    /// Risk level alone is not enough: `.autonomous` conversations auto-approve
    /// every risk level. The declaration is enforced in Chat/Build modes (and
    /// when the conversation level cannot be resolved); in autonomous (A3) mode
    /// the execution layer treats it as fully authorized and runs it directly.
    public func requiresExplicitApproval(arguments: [String: ToolArgument]) -> Bool {
        arguments.boolValue("unsandboxed") == true
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        guard let command = arguments.stringValue("command") else { return "运行命令" }
        let preview = command.count > 40 ? String(command.prefix(40)) + "…" : command
        if arguments.boolValue("run_in_background") == true {
            return "后台运行 \(preview)"
        }
        return arguments.boolValue("unsandboxed") == true ? "脱离沙箱运行 \(preview)" : "运行 \(preview)"
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        let plan = try await executionRequest(arguments: arguments)
        switch try await run(plan: plan, reporter: nil) {
        case .completed(let text):
            return text
        case .backgrounded(let text):
            return text
        }
    }

    public func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        let plan = try await executionRequest(arguments: arguments, context: context)
        let reporter = ShellOutputReporter(context: context)
        do {
            let text = try await run(plan: plan, reporter: reporter).text
            await reporter.finish()
            return ToolCallResult(content: text)
        } catch {
            await reporter.finish()
            throw error
        }
    }

    // MARK: - 执行

    /// 一次执行的结果。
    private enum RunOutcome {
        case completed(String)
        case backgrounded(String)

        var text: String {
            switch self {
            case .completed(let text), .backgrounded(let text):
                return text
            }
        }
    }

    /// 执行命令，按是否允许后台化分两条路径。
    private func run(
        plan: ExecutionPlan,
        reporter: ShellOutputReporter?
    ) async throws -> RunOutcome {
        // 故意等待的命令（sleep 开头）不自动转后台：它们的语义就是「等一会儿」，
        // 转后台会让模型拿到的不是结果而是一个迟到的通知。
        if !plan.allowsBackgroundHandoff {
            let result = try await ShellExecutor.executeStreaming(
                executable: plan.launch.executable,
                arguments: plan.launch.arguments,
                options: plan.options,
                onOutput: { chunk in
                    reporter?.report(.stdout, text: chunk)
                },
                onError: { chunk in
                    reporter?.report(.stderr, text: chunk)
                }
            )
            return .completed(Self.resultText(for: result))
        }

        let outcome = try await ShellExecutor.executeStreamingWithBackgroundHandoff(
            executable: plan.launch.executable,
            arguments: plan.launch.arguments,
            options: plan.options,
            onOutput: { chunk in
                plan.sink.append(chunk)
                reporter?.report(.stdout, text: chunk)
            },
            onError: { chunk in
                plan.sink.append(chunk)
                reporter?.report(.stderr, text: chunk)
            }
        )

        switch outcome {
        case .completed(let result):
            return .completed(Self.resultText(for: result))
        case .backgrounded(let handle):
            return .backgrounded(
                try await Self.backgroundResultText(handle: handle, plan: plan)
            )
        }
    }

    /// 把后台化的结果整理成回传给模型的文本。
    ///
    /// 文本必须包含：后台 ID、输出路径、`read_file` 提示。三者缺一，模型就
    /// 无法继续跟进这个后台任务。
    private static func backgroundResultText(
        handle: BackgroundShellHandle,
        plan: ExecutionPlan
    ) async throws -> String {
        guard let registry = plan.registry else {
            // 没有登记表就无法托管后台进程：此时必须显式失败，而不是让模型
            // 以为命令还在跑。进程已被交接，只能终止它。
            handle.terminate()
            throw ToolExecutionError.executionFailed(
                toolName: "run_command",
                reason: "Background execution is unavailable: no background task registry is configured."
            )
        }

        let record = await registry.adopt(
            taskID: plan.taskID,
            conversationID: plan.conversationID,
            command: plan.command,
            handle: handle,
            sink: plan.sink
        )

        return """
        Command is running in the background.
        Background task ID: \(record.id)
        Output file: \(record.outputPath)
        The process keeps running; you will be notified when it completes.
        To check interim output, use read_file on the output file path.
        """
    }

    // MARK: - 计划

    /// 命令的启动方式：沙箱包装或裸执行。
    private struct Launch {
        let executable: String
        let arguments: [String]
    }

    /// 一次调用的执行计划。
    private struct ExecutionPlan {
        /// Shell 选项（预算 / 输出上限 / 是否立即交接）。
        let options: ShellOptions
        /// 启动方式。
        let launch: Launch
        /// 是否允许后台交接。
        let allowsBackgroundHandoff: Bool
        /// 后台任务 ID（输出文件名）。
        let taskID: String
        /// 发起命令的会话——完成通知要送回这里。
        let conversationID: UUID
        /// 触发命令的原文。
        let command: String
        /// 输出落盘暂存器。
        let sink: BackgroundTaskOutputSink
        /// 后台任务登记表。
        let registry: BackgroundTaskRegistry?
    }

    private func executionRequest(
        arguments: [String: ToolArgument],
        context: ToolExecutionContext? = nil
    ) async throws -> ExecutionPlan {
        guard let command = arguments.stringValue("command"),
              !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw NSError(domain: "ShellTool", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing command"])
        }

        // `timeout` 现在是**前台预算**而不是杀进程的死线：预算耗尽时命令
        // 继续在后台跑。上限 600s 让模型的等待预期有界，同时绝不杀掉长任务。
        let foregroundBudget: TimeInterval
        if let rawTimeout = arguments["timeout"]?.value {
            // 越界 / NaN / 非有限值无法安全表示时按参数错误失败，而不是 trap。
            guard let seconds = arguments.toolInt("timeout"), seconds > 0 else {
                throw NSError(
                    domain: "ShellTool",
                    code: 400,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Invalid 'timeout': \(rawTimeout). It must be a positive integer number of seconds."
                    ]
                )
            }
            foregroundBudget = TimeInterval(
                min(seconds, Self.maxForegroundBudgetSeconds)
            )
        } else {
            foregroundBudget = TimeInterval(Int(commandTimeout))
        }

        // 显式后台：不等预算，进程一起来就交接。
        let explicitBackground = arguments.boolValue("run_in_background") == true

        // 以 sleep 开头的命令是**故意等待**，不是长任务：把它自动转后台会让
        // 模型拿到一个永远等不到的结果。显式 run_in_background 仍然尊重。
        let deliberateWait = Self.isDeliberateWait(command)
        let allowsBackgroundHandoff = explicitBackground || !deliberateWait

        // macOS 只允许进程树被沙箱化一次，被包装的命令无法再创建沙箱，
        // 因此 swift build / xcodebuild / 宏展开 这类命令必须显式退出包装。
        let launch = arguments.boolValue("unsandboxed") == true
            ? Launch(
                executable: ShellDesktopSandbox.unsandboxedExecutable,
                arguments: ShellDesktopSandbox.unsandboxedArguments(command: command)
            )
            : Launch(
                executable: ShellDesktopSandbox.executable,
                arguments: try ShellDesktopSandbox.arguments(command: command)
            )

        let workspaceRoot: String?
        if let contextualProjectPath = await context?.conversationProjectPath() {
            workspaceRoot = contextualProjectPath
        } else {
            workspaceRoot = await workspaceRootProvider()?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let registry = await backgroundTaskRegistryProvider()
        let taskID = await registry?.allocateTaskID() ?? UUID().uuidString
        // 上下文里的会话 ID 才是权威来源；无上下文时退回当前选中的会话。
        let fallbackConversationID = await currentConversationIDProvider()
        let conversationID = context?.conversationID ?? fallbackConversationID ?? UUID()

        let options = ShellOptions(
            workingDirectory: workspaceRoot?.isEmpty == false
                ? workspaceRoot
                : FileManager.default.homeDirectoryForCurrentUser.path,
            // 显式后台模式不设预算：进程一起来就交接。
            timeout: explicitBackground ? nil : foregroundBudget,
            throwsOnError: false,
            maxOutputBytes: Self.resolvedOutputBudget(for: arguments),
            handsOffImmediately: explicitBackground
        )

        return ExecutionPlan(
            options: options,
            launch: launch,
            allowsBackgroundHandoff: allowsBackgroundHandoff,
            taskID: taskID,
            conversationID: conversationID,
            command: command,
            sink: BackgroundTaskOutputSink(),
            registry: registry
        )
    }

    /// 判断命令是否以「故意等待」开头。
    ///
    /// `sleep 5` 这类命令的目的是等一会儿，把它自动转后台会破坏语义：
    /// 模型拿到的不是结果，而是一个迟到的通知。因此自动后台对它们豁免。
    static func isDeliberateWait(_ command: String) -> Bool {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstToken = trimmed.split(separator: " ", maxSplits: 1).first else {
            return false
        }
        let token = firstToken.lowercased()
        return token == "sleep" || token.hasSuffix("/sleep")
    }

    /// Resolves the per-stream output budget, clamped to a sane ceiling.
    ///
    /// The ceiling exists because the result is handed to an LLM: an unbounded
    /// budget would let one command blow up the context window.
    static func resolvedOutputBudget(for arguments: [String: ToolArgument]) -> Int {
        guard let requested = arguments.toolInt("max_output_bytes"), requested > 0 else {
            return ShellOptions.defaultOptions.maxOutputBytes
        }
        return min(requested, Self.maxOutputBytesCeiling)
    }

    /// 把命令输出整理成回传给模型的结果文本。
    static func resultText(for result: ShellResult) -> String {
        let combined = result.exitCode != 0
            ? "Exit code: \(result.exitCode)\n\(result.stdout)\n\(result.stderr)"
            : (result.stdout + result.stderr)
                .trimmingCharacters(in: .whitespacesAndNewlines)

        // Never hand back a silently truncated payload: an LLM that cannot tell
        // the output was cut may draw a confident wrong conclusion from a
        // partial build log. The notice makes the gap explicit.
        let streams = [
            (result.stdoutTruncated, "stdout"),
            (result.stderrTruncated, "stderr"),
        ].filter(\.0).map(\.1)

        guard !streams.isEmpty else {
            return combined.isEmpty ? "Command completed successfully." : combined
        }

        let notice = "[output truncated: kept the tail of "
            + streams.joined(separator: " and ")
            + ". Raise max_output_bytes, or redirect to a file and read it back.]"
        return combined.isEmpty ? notice : combined + "\n\n" + notice
    }
}
