import Foundation
import LumiCoreKit
import ShellKit
import Testing
@testable import ToolCorePlugin

@Test func shellToolExecutesCommand() async throws {
    let tool = ShellTool()
    let context = LumiToolExecutionContext(
        conversationID: UUID(),
        toolCallID: "call-echo",
        toolName: "run_command"
    )

    let output = try await tool.execute(
        arguments: ["command": .string("echo hello-shell-tool")],
        context: context
    )

    #expect(output.contains("hello-shell-tool"))
}

@Test func shellToolDoesNotBlockMainActorDuringExecution() async throws {
    let tool = ShellTool()
    let context = LumiToolExecutionContext(
        conversationID: UUID(),
        toolCallID: "call-sleep",
        toolName: "run_command"
    )

    let commandTask = Task {
        try await tool.execute(
            arguments: ["command": .string("sleep 0.4")],
            context: context
        )
    }

    let mainActorResponded = await withCheckedContinuation { continuation in
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000)
            continuation.resume(returning: true)
        }
    }

    #expect(mainActorResponded)
    _ = try await commandTask.value
}

@Test func shellToolHonoursWorkingDirectory() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ShellToolTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let marker = "shell-tool-marker-\(UUID().uuidString)"
    let tool = ShellTool()
    let context = LumiToolExecutionContext(
        conversationID: UUID(),
        toolCallID: "call-ls",
        toolName: "run_command",
        currentProjectPath: directory.path
    )

    let output = try await tool.execute(
        arguments: ["command": .string("touch \(marker) && ls")],
        context: context
    )

    #expect(output.contains(marker))
}

@Test func shellToolThrowsWhenCommandMissing() async throws {
    let tool = ShellTool()
    let context = LumiToolExecutionContext(
        conversationID: UUID(),
        toolCallID: "call-empty",
        toolName: "run_command"
    )

    await #expect(throws: (any Error).self) {
        _ = try await tool.execute(arguments: [:], context: context)
    }
}

@Test func shellToolThrowsWhenCommandIsEmpty() async throws {
    let tool = ShellTool()
    let context = LumiToolExecutionContext(
        conversationID: UUID(),
        toolCallID: "call-whitespace",
        toolName: "run_command"
    )

    await #expect(throws: (any Error).self) {
        _ = try await tool.execute(arguments: ["command": .string("   ")], context: context)
    }
}

@Test func shellToolHandlesNonZeroExitCode() async throws {
    let tool = ShellTool()
    let context = LumiToolExecutionContext(
        conversationID: UUID(),
        toolCallID: "call-fail",
        toolName: "run_command"
    )

    let output = try await tool.execute(
        arguments: ["command": .string("exit 42")],
        context: context
    )

    #expect(output.contains("Exit code: 42"))
}

@Test func shellToolCapturesStderr() async throws {
    let tool = ShellTool()
    let context = LumiToolExecutionContext(
        conversationID: UUID(),
        toolCallID: "call-stderr",
        toolName: "run_command"
    )

    let output = try await tool.execute(
        arguments: ["command": .string("echo error-message >&2")],
        context: context
    )

    #expect(output.contains("error-message"))
}

@Test func shellToolTimesOutLongRunningCommand() async throws {
    let tool = ShellTool(commandTimeout: 0.2)
    let context = LumiToolExecutionContext(
        conversationID: UUID(),
        toolCallID: "call-timeout",
        toolName: "run_command"
    )

    await #expect(throws: ShellError.self) {
        _ = try await tool.execute(
            arguments: ["command": .string("sleep 2")],
            context: context
        )
    }
}

@Test func shellToolReturnsSuccessMessageWhenEmptyOutput() async throws {
    let tool = ShellTool()
    let context = LumiToolExecutionContext(
        conversationID: UUID(),
        toolCallID: "call-noop",
        toolName: "run_command"
    )

    let output = try await tool.execute(
        arguments: ["command": .string("true")],
        context: context
    )

    #expect(output.contains("Command completed successfully"))
}

@Test func shellToolRiskLevelForHighRiskCommands() {
    let tool = ShellTool()

    #expect(tool.riskLevel(arguments: ["command": .string("rm -rf /")], context: nil) == .high)
    #expect(tool.riskLevel(arguments: ["command": .string("sudo ls")], context: nil) == .high)
    #expect(tool.riskLevel(arguments: ["command": .string("kill 1234")], context: nil) == .high)
    #expect(tool.riskLevel(arguments: ["command": .string("echo hello")], context: nil) == .low)
    #expect(tool.riskLevel(arguments: [:], context: nil) == .high)
}

@Test func shellToolDisplayDescription() {
    let tool = ShellTool()

    let short = tool.displayDescription(arguments: ["command": .string("echo hello")])
    #expect(short == "运行 echo hello")

    let long = tool.displayDescription(arguments: ["command": .string(String(repeating: "a", count: 50))])
    #expect(long.hasSuffix("…"))

    let fallback = tool.displayDescription(arguments: [:])
    #expect(fallback == "运行命令")
}
