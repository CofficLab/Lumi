import Foundation
import KitAgentTool
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
