import Foundation
import KernelCore
import ProviderProject
import ProviderRailView
import Testing

@testable import PluginProjectFileTree

@MainActor
@Test("文件树仅在存在当前项目时显示 Explorer")
func explorerTabFollowsCurrentProject() async throws {
    let kernel = KernelCoreContainer()
    let project = DefaultProjectProvider()
    let railView = DefaultRailViewProviding()
    try kernel.registerProvider((any ProjectProviding).self, project)
    try kernel.registerProvider((any RailViewProviding).self, railView)

    let plugin = ProjectFileTreePlugin()
    try plugin.onBoot(kernel: kernel)

    #expect(railView.tabs.isEmpty)

    try await project.openProject(at: "/tmp/lumi-file-tree-test-project")
    #expect(railView.tabs.map(\.id) == [ProjectFileTreePlugin.railTabID])

    await project.closeProject()
    #expect(railView.tabs.isEmpty)

    try plugin.onShutdown(kernel: kernel)
}

@Test("Git 状态扫描可处理超过 pipe 缓冲区的大量输出")
func gitStatusProviderDrainsLargeOutput() throws {
    let fileManager = FileManager.default
    let root = fileManager.temporaryDirectory
        .appendingPathComponent("lumi-git-status-large-output-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: root) }

    try runGitForTest(["init", "-q"], in: root)

    let fileCount = 4_000
    for index in 0..<fileCount {
        let file = root.appendingPathComponent("untracked-file-\(index).txt")
        try Data("untracked\n".utf8).write(to: file)
    }

    let snapshot = GitStatusProvider().captureSnapshot(projectRootPath: root.path)

    #expect(snapshot != nil)
    #expect(snapshot?.entriesByRelativePath.count == fileCount)
}

@Test("中文命名文件的修改必须显示 modified 标记，不得因引号转义而丢失状态")
func gitStatusMarksChineseNamedFile() throws {
    let fileManager = FileManager.default
    let root = fileManager.temporaryDirectory
        .appendingPathComponent("lumi-git-status-cjk-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: root) }

    try runGitForTest(["init", "-q"], in: root)
    try runGitForTest(["config", "user.email", "test@example.com"], in: root)
    try runGitForTest(["config", "user.name", "Test"], in: root)

    let file = root.appendingPathComponent("测试.txt")
    try Data("original\n".utf8).write(to: file)
    try runGitForTest(["add", "测试.txt"], in: root)
    try runGitForTest(["commit", "-q", "-m", "init"], in: root)

    // 修改已跟踪的中文命名文件：默认 core.quotepath=true 下非 -z 输出会被八进制转义。
    try Data("modified\n".utf8).write(to: file)

    let snapshot = GitStatusProvider().captureSnapshot(projectRootPath: root.path)

    #expect(snapshot != nil)
    #expect(snapshot?.statusForPath("测试.txt") == .modified)
}

@Test("含反斜杠与引号的合法文件名映射回原始相对路径")
func gitStatusPreservesSpecialCharacterFileName() throws {
    let fileManager = FileManager.default
    let root = fileManager.temporaryDirectory
        .appendingPathComponent("lumi-git-status-special-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: root) }

    try runGitForTest(["init", "-q"], in: root)

    // 反斜杠与双引号都是 macOS 合法文件名字符；untracked 即可触发状态查询。
    let specialName = "a\\b\"c.txt"
    let file = root.appendingPathComponent(specialName)
    try Data("special\n".utf8).write(to: file)

    let snapshot = GitStatusProvider().captureSnapshot(projectRootPath: root.path)

    #expect(snapshot != nil)
    #expect(snapshot?.statusForPath(specialName) == .untracked)
}

private func runGitForTest(_ arguments: [String], in directory: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["git"] + arguments
    process.currentDirectoryURL = directory
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError
    try process.run()
    process.waitUntilExit()
    #expect(process.terminationStatus == 0)
}
