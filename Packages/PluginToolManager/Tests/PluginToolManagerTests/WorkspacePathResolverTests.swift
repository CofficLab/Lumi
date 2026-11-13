import Foundation
import KitAgentTool
import Testing
@testable import PluginToolManager

// MARK: - Resolver（纯函数，不触碰文件系统）

@Test func relativePathResolvesInsideWorkspaceWithoutTrailingSlash() {
    // #140：workspace 根无尾斜杠且磁盘上不存在时，曾被当作文件 URL，相对路径落到父目录。
    let url = WorkspacePathResolver.resolve(path: "note.txt", workspaceRoot: "/tmp/project")
    #expect(url.path == "/tmp/project/note.txt")
}

@Test func relativePathResolvesInsideWorkspaceWithTrailingSlash() {
    let url = WorkspacePathResolver.resolve(path: "note.txt", workspaceRoot: "/tmp/project/")
    #expect(url.path == "/tmp/project/note.txt")
}

@Test func nestedRelativePathResolvesInsideWorkspace() {
    let url = WorkspacePathResolver.resolve(path: "a/b.txt", workspaceRoot: "/tmp/project")
    #expect(url.path == "/tmp/project/a/b.txt")
}

@Test func absolutePathIsReturnedUnchanged() {
    let url = WorkspacePathResolver.resolve(path: "/etc/hosts", workspaceRoot: "/tmp/project")
    #expect(url.path == "/etc/hosts")
}

@Test func nilWorkspaceRootResolvesRelativeToCurrentDirectory() {
    let url = WorkspacePathResolver.resolve(path: "note.txt", workspaceRoot: nil)
    #expect(url.path == URL(fileURLWithPath: "note.txt").standardizedFileURL.path)
}

@Test func blankWorkspaceRootResolvesRelativeToCurrentDirectory() {
    let url = WorkspacePathResolver.resolve(path: "note.txt", workspaceRoot: "   ")
    #expect(url.path == URL(fileURLWithPath: "note.txt").standardizedFileURL.path)
}

@Test func tildePathIsExpandedToHomeDirectory() {
    let url = WorkspacePathResolver.resolve(path: "~/note.txt", workspaceRoot: "/tmp/project")
    let expected = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        .appendingPathComponent("note.txt").path
    #expect(url.path == expected)
}

@Test func parentTraversalIsStandardizedAgainstWorkspace() {
    let url = WorkspacePathResolver.resolve(path: "../sibling.txt", workspaceRoot: "/tmp/project")
    #expect(url.path == "/tmp/sibling.txt")
}

// MARK: - 调用点（生产链路）
//
// 关键：项目根刻意「不预先创建」。URL(fileURLWithPath:) 会 stat 已存在的目录并
// 推断为目录，从而掩盖 bug；只有根不存在时才暴露「相对路径落到父目录」。write_file
// 自身会创建父目录，read/edit 用父目录同名诱饵验证「不得越界读写项目外文件」。

@MainActor
private func withTempContainer(_ body: (URL) async throws -> Void) async throws {
    let container = FileManager.default.temporaryDirectory
        .appendingPathComponent("lumi-140-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: container) }
    try await body(container)
}

@MainActor
@Test func writeFileToolWritesRelativePathInsideWorkspace() async throws {
    try await withTempContainer { container in
        let project = container.appendingPathComponent("project", isDirectory: true)
        let root = project.path
        let tool = WriteFileTool(workspaceRootProvider: { root })
        _ = try await tool.execute(arguments: [
            "path": ToolArgument("note.txt"),
            "content": ToolArgument("inside"),
        ])
        let inside = project.appendingPathComponent("note.txt")
        let outside = container.appendingPathComponent("note.txt")
        #expect(FileManager.default.fileExists(atPath: inside.path))
        #expect(!FileManager.default.fileExists(atPath: outside.path))
        #expect(try String(contentsOf: inside, encoding: .utf8) == "inside")
    }
}

@MainActor
@Test func readFileToolDoesNotReadParentFileForRelativePath() async throws {
    try await withTempContainer { container in
        let project = container.appendingPathComponent("project", isDirectory: true)
        // 父目录放一个同名诱饵；项目内文件不存在。
        try "outside".write(to: container.appendingPathComponent("note.txt"), atomically: true, encoding: .utf8)
        let root = project.path
        let tool = ReadFileTool(workspaceRootProvider: { root })
        let content = try? await tool.execute(arguments: ["path": ToolArgument("note.txt")])
        // 修复后应指向项目内（不存在）而抛错，绝不能读到父目录诱饵。
        #expect(content?.contains("outside") != true)
    }
}

@MainActor
@Test func editFileToolDoesNotModifyParentFileForRelativePath() async throws {
    try await withTempContainer { container in
        let project = container.appendingPathComponent("project", isDirectory: true)
        let parentDecoy = container.appendingPathComponent("note.txt")
        try "outside".write(to: parentDecoy, atomically: true, encoding: .utf8)
        let root = project.path
        let tool = EditFileTool(workspaceRootProvider: { root })
        _ = try? await tool.execute(arguments: [
            "file_path": ToolArgument("note.txt"),
            "old_string": ToolArgument("outside"),
            "new_string": ToolArgument("changed"),
        ])
        // 修复后编辑目标是项目内文件，父目录诱饵必须原样未动。
        #expect(try String(contentsOf: parentDecoy, encoding: .utf8) == "outside")
    }
}
