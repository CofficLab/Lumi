import Foundation
import ProviderProject
import Testing
@testable import PluginProjects

/// 启动恢复（`.appRestore`）与外部打开（`.externalOpen`）的优先级回归（#131）。
///
/// 冷启动时 onBoot 在「当前项目为空」的同步阶段调度恢复 Task，但 Task 真正执行
/// 前外部打开可能已设置当前项目。恢复必须在写入前重新校验，否则覆盖用户显式意图。
@MainActor
@Suite("Projects app restore yields to external open (#131)")
struct ProjectsAppRestoreTests {

    @Test("外部打开已设置项目时，启动恢复直接让位不覆盖")
    func appRestoreYieldsToExternalOpen() async throws {
        let provider = DefaultProjectProvider()
        try await provider.openProject(at: "/tmp/gitok", reason: .externalOpen)

        // 恢复请求晚到：写入前重新校验 currentProject != nil → 不覆盖。
        try await ProjectsPlugin.restoreCurrentProjectIfNeeded(provider, storedPath: "/tmp/cofficlab")

        #expect(provider.currentProject?.path == "/tmp/gitok", "外部打开的项目必须保留")
    }

    @Test("恢复 Task 排队期间外部打开抢先执行，Task 内部重新校验后让位")
    func appRestoreTaskRechecksAfterExternalOpen() async throws {
        let provider = DefaultProjectProvider()
        // 模拟 onBoot：当前项目为空时调度恢复 Task（尚未执行）。
        let restoreTask = Task { @MainActor in
            try? await ProjectsPlugin.restoreCurrentProjectIfNeeded(provider, storedPath: "/tmp/cofficlab")
        }
        // 外部打开抢先设置当前项目，恢复 Task 仍在排队。
        try await provider.openProject(at: "/tmp/gitok", reason: .externalOpen)
        await restoreTask.value

        #expect(provider.currentProject?.path == "/tmp/gitok", "晚到的恢复 Task 不得覆盖外部打开")
    }

    @Test("仍无当前项目时启动恢复照常打开持久化项目")
    func appRestoreOpensStoredProjectWhenEmpty() async throws {
        let provider = DefaultProjectProvider()

        try await ProjectsPlugin.restoreCurrentProjectIfNeeded(provider, storedPath: "/tmp/cofficlab")

        #expect(provider.currentProject?.path == "/tmp/cofficlab", "无外部打开时恢复应正常生效")
    }
}