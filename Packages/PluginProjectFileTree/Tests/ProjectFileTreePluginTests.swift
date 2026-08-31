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
