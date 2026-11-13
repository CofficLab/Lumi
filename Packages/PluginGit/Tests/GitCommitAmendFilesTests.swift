import Foundation
import LibGit2Swift
import Testing
@testable import GitPlugin

/// 回归 #358：`git_commit(amend: true, files: [...])` 只调用 `amendCommit`，
/// 而 amend 仅读取当前 index，不会暂存工作区改动。指定的文件因此留在工作区、
/// 不进入 amended 提交，工具却报告成功。修复后 amend 必须先按 `files` 暂存
/// （空列表与新建提交一致：暂存全部变更），再 amend。
@Suite("GitCommit amend 暂存指定文件")
struct GitCommitAmendFilesTests {

    private func makeRepo(at repoURL: URL) throws {
        try FileManager.default.createDirectory(at: repoURL, withIntermediateDirectories: true)
        LibGit2.initialize()
        _ = try LibGit2.createRepository(at: repoURL.path)
        try LibGit2.setConfig(key: "user.name", value: "Tester", at: repoURL.path, verbose: false)
        try LibGit2.setConfig(key: "user.email", value: "tester@example.com", at: repoURL.path, verbose: false)
    }

    private func write(_ url: URL, _ content: String) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    private func tempRepo(_ label: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("GitPluginTests/amend358-\(label)-\(UUID().uuidString)")
            .appendingPathComponent("App")
    }

    /// 种子提交：写入文件并真实提交，返回 HEAD 哈希。
    private func seedCommit(_ repoURL: URL, files: [(name: String, content: String)]) throws -> String {
        for file in files {
            try write(repoURL.appendingPathComponent(file.name), file.content)
        }
        try LibGit2.addFiles(files.map { $0.name }, at: repoURL.path, verbose: false)
        return try LibGit2.createCommit(message: "seed", at: repoURL.path, verbose: false)
    }

    @Test("amend 必须把指定文件的未暂存修改纳入 amended 提交")
    func amendStagesSpecifiedFileIntoAmendedCommit() async throws {
        let repoURL = tempRepo("files")
        let parent = repoURL.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: parent) }
        try makeRepo(at: repoURL)

        let headBefore = try seedCommit(repoURL, files: [("a.txt", "v1")])
        // 制造未暂存的工作区修改（不手动 stage）。
        try write(repoURL.appendingPathComponent("a.txt"), "v2")

        let result = try await GitService.shared.commit(
            path: repoURL.path,
            message: "amended",
            files: ["a.txt"],
            amend: true
        )

        let headAfter = try LibGit2.headCommitHash(at: repoURL.path)
        #expect(headAfter != headBefore, "amend 后 HEAD 应变化")
        #expect(result.hash == headAfter, "返回的 hash 应为新 HEAD")

        // 指定的修改必须进入 amended 提交，而不是旧的 v1。
        let committed = try LibGit2.getFileContentChange(atCommit: result.hash, file: "a.txt", at: repoURL.path)
        #expect(committed.after == "v2", "amended 提交应包含 v2")

        // 工作区不应再残留该文件的未提交修改（HEAD 与工作区一致）。
        let uncommitted = try LibGit2.getUncommittedFileContentChange(for: "a.txt", at: repoURL.path)
        #expect(uncommitted.before == uncommitted.after, "v2 已提交，工作区与 HEAD 应一致")
    }

    @Test("amend 空文件列表与新建提交一致：暂存全部变更")
    func amendWithEmptyFilesStagesAllChanges() async throws {
        let repoURL = tempRepo("empty")
        let parent = repoURL.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: parent) }
        try makeRepo(at: repoURL)

        let headBefore = try seedCommit(repoURL, files: [("a.txt", "v1"), ("b.txt", "v1")])
        try write(repoURL.appendingPathComponent("a.txt"), "v2a")
        try write(repoURL.appendingPathComponent("b.txt"), "v2b")

        let result = try await GitService.shared.commit(
            path: repoURL.path,
            message: "amended all",
            files: [],
            amend: true
        )

        let headAfter = try LibGit2.headCommitHash(at: repoURL.path)
        #expect(headAfter != headBefore, "amend 后 HEAD 应变化")

        for (name, expected) in [("a.txt", "v2a"), ("b.txt", "v2b")] {
            let committed = try LibGit2.getFileContentChange(atCommit: result.hash, file: name, at: repoURL.path)
            #expect(committed.after == expected, "\(name) 的全部变更应进入 amended 提交")
            let uncommitted = try LibGit2.getUncommittedFileContentChange(for: name, at: repoURL.path)
            #expect(uncommitted.before == uncommitted.after, "\(name) 不应残留未提交修改")
        }
    }

    @Test("无工作区改动时 amend 仅改提交信息，保留已提交内容")
    func amendMessageOnlyKeepsCommittedContent() async throws {
        let repoURL = tempRepo("message")
        let parent = repoURL.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: parent) }
        try makeRepo(at: repoURL)

        let headBefore = try seedCommit(repoURL, files: [("a.txt", "v1")])

        let result = try await GitService.shared.commit(
            path: repoURL.path,
            message: "new message",
            files: [],
            amend: true
        )

        let headAfter = try LibGit2.headCommitHash(at: repoURL.path)
        #expect(headAfter != headBefore, "amend 后 HEAD 应变化")
        #expect(result.message == "new message", "提交信息应被更新")
        let committed = try LibGit2.getFileContentChange(atCommit: result.hash, file: "a.txt", at: repoURL.path)
        #expect(committed.after == "v1", "无改动时已提交内容应保持不变")
    }
}