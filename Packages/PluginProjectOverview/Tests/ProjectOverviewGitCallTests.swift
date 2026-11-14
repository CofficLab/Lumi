import Foundation
import Testing
@testable import ProjectOverviewPlugin

/// `project_overview` 的 git 调用不得阻塞协作线程（见 issue #1288）。
///
/// 原先 `GitSection.runGit` 用 `DispatchSemaphore.wait()` 把 async 的
/// `Shell.execute` 桥回同步代码：
/// - 阻塞协作线程，而协作线程池定宽且与 `MainActor` 共用 → 饿死 UI 任务；
/// - 没有超时 → 大仓库上的 `git status` 可以无限期挂住；
/// - 内层 `Task {}` 不继承取消 → 工具取消无法中断等待。
@Suite("ProjectOverview 的 git 调用")
struct ProjectOverviewGitCallTests {

    @Test("非 Git 目录快速返回")
    func nonGitDirectoryReturnsPromptly() async {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("po-git-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let start = Date()
        let result = await GitSection.render(at: tempDir)
        let elapsed = Date().timeIntervalSince(start)

        #expect(result == "Not a Git repository.")
        // 没有超时时的信号量等待可能无限期挂住；有超时则必然很快返回。
        #expect(elapsed < 15)
    }

    @Test("git 调用不占用协作线程")
    func gitCallDoesNotBlockCooperatives() async {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("po-git-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // 阻塞协作线程池的实现会让下面这些任务迟迟得不到调度：
        // 信号量等待会占住线程，且没有超时、没有取消检查。
        let counter = CooperativeProbe()

        // 先占满协作线程池（宽度约等于核心数），再触发 git 调用。
        let blockers = (0..<16).map { _ in
            Task.detached(priority: .userInitiated) {
                await counter.enter()
                // 保持一段时间，模拟其它长任务占住协作线程。
                try? await Task.sleep(for: .milliseconds(600))
            }
        }

        try? await Task.sleep(for: .milliseconds(50))
        let start = Date()
        let result = await GitSection.render(at: tempDir)
        let elapsed = Date().timeIntervalSince(start)

        for blocker in blockers { blocker.cancel() }

        #expect(result == "Not a Git repository.")
        // 协作线程被占满时，git 调用仍应在有界时间内返回。
        #expect(elapsed < 15)
    }
}

/// 记录进入协作线程的任务数。
private actor CooperativeProbe {
    private(set) var entered = 0

    func enter() {
        entered += 1
    }
}
