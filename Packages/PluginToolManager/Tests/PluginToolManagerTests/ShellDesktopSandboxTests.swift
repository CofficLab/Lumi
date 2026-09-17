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
