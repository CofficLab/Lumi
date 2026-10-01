import Foundation
import KitAgentTool
import KitShell
import Testing
@testable import PluginToolManager

@Test func desktopSandboxAllowsTerminalCommandsAndNestedChildren() async throws {
    let tool = ShellTool(workspaceRootProvider: { "/tmp" })
    let output = try await tool.execute(arguments: ["command": ToolArgument("/bin/sh -c '/usr/bin/printf terminal-ok'")])
    #expect(output == "terminal-ok")
}

@Test func desktopSandboxRejectsAppleEventsFromNestedInterpreter() async throws {
    let tool = ShellTool(workspaceRootProvider: { "/tmp" })
    // Read-only event to an already-running service. No clicks, launches or dialogs.
    let output = try await tool.execute(arguments: ["command": ToolArgument("/bin/sh -c '/usr/bin/osascript -e '\''tell application \"System Events\" to get name'\'''")])
    #expect(output.contains("Exit code:"))
    #expect(!output.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("System Events"))
}

@Test func compiledHelperInheritsDesktopServiceDenials() async throws {
    let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/desktop_probe.c")
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LumiDesktopProbe-\(UUID())")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let binary = directory.appendingPathComponent("probe").path
    let tool = ShellTool(workspaceRootProvider: { "/tmp" })
    func quote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }
    let output = try await tool.execute(arguments: ["command": ToolArgument(
        "/usr/bin/xcrun clang \(quote(source.path)) -o \(quote(binary)) && /bin/sh -c \(quote(binary))"
    )])
    #expect(!output.contains("Exit code:"))
    #expect(output.contains("com.apple.windowserver.active:"))
    #expect(!output.split(separator: "\n").contains { $0.hasSuffix(":0") })
}

// MARK: - Unsandboxed opt-out

@Test func unsandboxedArgumentsSkipTheWrapper() {
    // The whole point of the opt-out: the command must not be handed to
    // sandbox-exec, because a sandboxed process cannot apply a second sandbox.
    let wrapped = try? ShellDesktopSandbox.arguments(command: "swift build")
    #expect(wrapped?.contains("/usr/bin/sandbox-exec") != true)
    #expect(wrapped?.first == "-p")

    let bare = ShellDesktopSandbox.unsandboxedArguments(command: "swift build")
    #expect(bare == ["-lc", "swift build"])
    #expect(!bare.contains("/usr/bin/sandbox-exec"))
}

@Test func unsandboxedDefaultsToOff() {
    let tool = ShellTool(workspaceRootProvider: { "/tmp" })
    #expect(tool.requiresExplicitApproval(arguments: ["command": ToolArgument("echo hi")]) == false)
    #expect(tool.requiresExplicitApproval(arguments: [
        "command": ToolArgument("echo hi"),
        "unsandboxed": ToolArgument(false),
    ]) == false)
}

@Test func unsandboxedAlwaysRequiresExplicitApproval() {
    // Risk level alone is not enough: `.autonomous` conversations approve every
    // risk level, which would let this run unattended.
    let tool = ShellTool(workspaceRootProvider: { "/tmp" })
    #expect(tool.requiresExplicitApproval(arguments: [
        "command": ToolArgument("echo hi"),
        "unsandboxed": ToolArgument(true),
    ]) == true)
}

@Test func unsandboxedRaisesRiskLevelToHigh() {
    let tool = ShellTool(workspaceRootProvider: { "/tmp" })
    // A benign command would otherwise be `.low` and auto-approved.
    #expect(tool.permissionRiskLevel(arguments: ["command": ToolArgument("echo hi")]) == .low)
    #expect(tool.permissionRiskLevel(arguments: [
        "command": ToolArgument("echo hi"),
        "unsandboxed": ToolArgument(true),
    ]) == .high)
}

@Test func unsandboxedIsAdvertisedInSchemaAndDescription() {
    let tool = ShellTool(workspaceRootProvider: { "/tmp" })
    let properties = (tool.inputSchema(for: .english)["properties"] as? [String: Any]) ?? [:]
    #expect(properties["unsandboxed"] != nil)

    let sandboxed = tool.displayDescription(for: ["command": ToolArgument("swift build")])
    let unsandboxed = tool.displayDescription(for: [
        "command": ToolArgument("swift build"),
        "unsandboxed": ToolArgument(true),
    ])
    #expect(sandboxed != unsandboxed)
    #expect(unsandboxed.contains("沙箱"))
}

// MARK: - Output budget

@Test func outputBudgetFallsBackToDefault() {
    // Absent, zero and negative all mean "use the default"
    let arguments: [[String: ToolArgument]] = [
        ["command": ToolArgument("echo hi")],
        ["command": ToolArgument("echo hi"), "max_output_bytes": ToolArgument(0)],
        ["command": ToolArgument("echo hi"), "max_output_bytes": ToolArgument(-1)],
    ]
    for arg in arguments {
        #expect(ShellTool.resolvedOutputBudget(for: arg) == 64 * 1024)
    }
}

@Test func outputBudgetHonoursAnExplicitValue() {
    #expect(ShellTool.resolvedOutputBudget(for: [
        "command": ToolArgument("xcodebuild test"),
        "max_output_bytes": ToolArgument(4 * 1024 * 1024),
    ]) == 4 * 1024 * 1024)
}

@Test func outputBudgetIsClampedToTheCeiling() {
    // The result is handed to an LLM, so one command must not be able to
    // request an unbounded budget.
    #expect(ShellTool.resolvedOutputBudget(for: [
        "command": ToolArgument("yes"),
        "max_output_bytes": ToolArgument(Int.max),
    ]) == ShellTool.maxOutputBytesCeiling)
}

@Test func maxOutputBytesIsAdvertisedInSchema() {
    let tool = ShellTool(workspaceRootProvider: { "/tmp" })
    let properties = (tool.inputSchema(for: .english)["properties"] as? [String: Any]) ?? [:]
    #expect(properties["max_output_bytes"] != nil)
}

@Test func truncatedOutputIsReportedToTheModel() {
    // A silently truncated payload is the dangerous case: the model would draw
    // conclusions from a partial build log without knowing it was cut.
    let truncated = ShellResult(
        exitCode: 0,
        stdout: "Compiling Foo\n<build log continues>",
        stderr: "",
        stdoutTruncated: true
    )
    let text = ShellTool.resultText(for: truncated)
    #expect(text.contains("truncated"))
    #expect(text.contains("stdout"))
    #expect(text.contains("max_output_bytes"))
}

@Test func truncatedStderrIsReportedSeparately() {
    let truncated = ShellResult(
        exitCode: 1,
        stdout: "partial",
        stderr: "error: something failed",
        stderrTruncated: true
    )
    let text = ShellTool.resultText(for: truncated)
    #expect(text.contains("truncated"))
    #expect(text.contains("stderr"))
    // The exit code and surviving output must still come through.
    #expect(text.contains("Exit code: 1"))
    #expect(text.contains("error: something failed"))
}

@Test func untruncatedOutputHasNoNotice() {
    let clean = ShellResult(exitCode: 0, stdout: "ok", stderr: "")
    #expect(ShellTool.resultText(for: clean) == "ok")

    let bothTruncated = ShellResult(
        exitCode: 0,
        stdout: "",
        stderr: "",
        stdoutTruncated: true,
        stderrTruncated: true
    )
    let text = ShellTool.resultText(for: bothTruncated)
    #expect(text.contains("stdout"))
    #expect(text.contains("stderr"))
}
