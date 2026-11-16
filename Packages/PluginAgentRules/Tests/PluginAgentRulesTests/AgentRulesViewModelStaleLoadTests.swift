import Foundation
import Testing
@testable import PluginAgentRules

/// 回归 #465：Agent Rules 旧项目的晚到加载结果覆盖新选中项目的规则列表。
///
/// `reload()` 先捕获 `selectedProjectPath`，再 `await listRules`。await 期间用户
/// 可能已切到别的项目；旧实现await 结束后无条件写 `rules` / `errorMessage`，于是
/// 项目 A 的晚到响应会把项目 B 的状态盖掉（B 无规则目录时本应是空列表）。
///
/// 修复要求写回前比对身份（`selectedProjectPath == 捕获的 projectPath`），成功与
/// 失败分支都要校验。下面用门闩让 A 的加载停在 await 内、B 先完成，再放行 A，
/// 确定性地构造「旧请求晚到」，而不是依赖真实磁盘读取的时序运气。
@Suite("AgentRulesViewModel 晚到加载")
@MainActor
struct AgentRulesViewModelStaleLoadTests {

    @Test("旧项目的晚到成功结果不覆盖新项目的空规则列表")
    func lateSuccessDoesNotOverwriteNewSelection() async throws {
        let projectA = try makeProjectDirectory(withRulesDirectory: true)
        let projectB = try makeProjectDirectory(withRulesDirectory: false)
        defer {
            try? FileManager.default.removeItem(at: projectA)
            try? FileManager.default.removeItem(at: projectB)
        }
        let pathA = projectA.path()
        let pathB = projectB.path()
        let ruleA = makeMetadata(id: "a", filename: "a.md")

        let gate = LoadGate()
        let viewModel = AgentRulesViewModel(listRules: { path in
            if path == pathA {
                await gate.enter()
                return [ruleA]
            }
            return []
        })

        // A 的加载停在门闩内（已捕获 projectPath == A）。
        viewModel.selectProject(path: pathA)
        await gate.waitUntilEntered()

        // 切到 B：B 无规则目录，reload 同步清空 rules。
        viewModel.selectProject(path: pathB)
        try await waitUntil { !viewModel.isLoading }
        #expect(viewModel.selectedProjectPath == pathB)
        #expect(viewModel.rules.isEmpty)

        // 放行 A 的晚到结果：身份不匹配，必须丢弃，不能盖掉 B 的空列表。
        await gate.release()
        try await settle()

        #expect(viewModel.selectedProjectPath == pathB)
        #expect(viewModel.rules.isEmpty, "旧项目 A 的晚到规则覆盖了新项目 B")
    }

    @Test("旧项目的晚到错误不写入新项目的 errorMessage")
    func lateErrorDoesNotOverwriteNewSelection() async throws {
        let projectA = try makeProjectDirectory(withRulesDirectory: true)
        let projectB = try makeProjectDirectory(withRulesDirectory: false)
        defer {
            try? FileManager.default.removeItem(at: projectA)
            try? FileManager.default.removeItem(at: projectB)
        }
        let pathA = projectA.path()
        let pathB = projectB.path()

        let gate = LoadGate()
        let viewModel = AgentRulesViewModel(listRules: { path in
            if path == pathA {
                await gate.enter()
                throw AgentRulesError.directoryUnreadable(pathA)
            }
            return []
        })

        viewModel.selectProject(path: pathA)
        await gate.waitUntilEntered()

        viewModel.selectProject(path: pathB)
        try await waitUntil { !viewModel.isLoading }

        await gate.release()
        try await settle()

        #expect(viewModel.selectedProjectPath == pathB)
        #expect(viewModel.errorMessage == nil, "旧项目 A 的晚到错误污染了新项目 B")
        #expect(viewModel.rules.isEmpty)
    }

    @Test("选中项目未变化时正常加载仍会写入规则")
    func currentSelectionStillLoadsRules() async throws {
        let projectA = try makeProjectDirectory(withRulesDirectory: true)
        defer { try? FileManager.default.removeItem(at: projectA) }
        let pathA = projectA.path()
        let ruleA = makeMetadata(id: "a", filename: "a.md")

        let viewModel = AgentRulesViewModel(listRules: { _ in [ruleA] })

        viewModel.selectProject(path: pathA)
        try await waitUntil { viewModel.rules.count == 1 }

        #expect(viewModel.selectedProjectPath == pathA)
        #expect(viewModel.rules.count == 1)
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Helpers

    private func makeProjectDirectory(withRulesDirectory: Bool) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentRulesStaleLoad-\(UUID().uuidString)", isDirectory: true)
        if withRulesDirectory {
            try FileManager.default.createDirectory(
                at: root.appending(path: ".lumi/rules", directoryHint: .isDirectory),
                withIntermediateDirectories: true
            )
        } else {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        }
        return root
    }

    private func makeMetadata(id: String, filename: String) -> AgentRuleMetadata {
        AgentRuleMetadata(
            id: id,
            filename: filename,
            title: id,
            description: "",
            fileSize: 0,
            modifiedAt: .distantPast,
            filePath: "/tmp/\(filename)"
        )
    }

    private func waitUntil(
        timeout: Duration = .seconds(2),
        _ condition: @MainActor () -> Bool
    ) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while !condition() {
            if ContinuousClock.now > deadline {
                Issue.record("等待条件超时")
                return
            }
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    private func settle() async throws {
        try await Task.sleep(for: .milliseconds(50))
    }
}

/// 门闩：让旧项目的加载停在 `enter()` 内，测试确认其已进入后再切项目，
/// 最后 `release()` 放行，从而确定性地构造「旧请求晚到」。
private actor LoadGate {
    private var entered = false
    private var released = false
    private var enterWaiters: [CheckedContinuation<Void, Never>] = []
    private var enteredWaiters: [CheckedContinuation<Void, Never>] = []

    func enter() async {
        entered = true
        for waiter in enteredWaiters { waiter.resume() }
        enteredWaiters.removeAll()
        if released { return }
        await withCheckedContinuation { enterWaiters.append($0) }
    }

    func waitUntilEntered() async {
        if entered { return }
        await withCheckedContinuation { enteredWaiters.append($0) }
    }

    func release() {
        released = true
        for waiter in enterWaiters { waiter.resume() }
        enterWaiters.removeAll()
    }
}