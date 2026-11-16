import Foundation
import Testing
import ProviderProject
import ProviderSkill

@testable import PluginSkill

/// 回归 #791：移除最后一个项目后，技能设置页仍把已删除项目的技能算进顶部计数。
///
/// 选中项目被清空时必须立刻清空 `projectSkills`（而不是只在非 nil 时 reload），
/// 并且在扫描途中项目被移除时，旧项目的结果不得写回。
@Suite("SkillSettingsProjectRemoval（#791）")
@MainActor
struct SkillSettingsProjectRemovalTests {

    private struct EmptyBuiltin: BuiltinSkillProviding {
        func builtinSkills() -> [SkillMetadata] { [] }
    }

    /// 按项目路径返回不同技能，模拟两个项目各自的 `.lumi/skills`。
    private final class PathScanner: SkillScanning, @unchecked Sendable {
        private let lock = NSLock()
        private let skillsByPath: [String: [SkillMetadata]]
        init(_ skillsByPath: [String: [SkillMetadata]]) { self.skillsByPath = skillsByPath }
        func scanSkills(projectPath: String) -> [SkillMetadata] {
            lock.lock(); defer { lock.unlock() }
            return skillsByPath[projectPath] ?? []
        }
    }

    /// 可闩锁的扫描器：扫描在 SkillService actor 上执行，阻塞它即可构造「旧请求晚到」。
    private final class GatedScanner: SkillScanning, @unchecked Sendable {
        private let lock = NSLock()
        private let gate = DispatchSemaphore(value: 0)
        private let skills: [SkillMetadata]
        private var entered = false
        private var finished = false
        init(_ skills: [SkillMetadata]) { self.skills = skills }
        var didEnter: Bool { lock.lock(); defer { lock.unlock() }; return entered }
        var didFinished: Bool { lock.lock(); defer { lock.unlock() }; return finished }
        func openGate() { gate.signal() }
        func scanSkills(projectPath: String) -> [SkillMetadata] {
            lock.lock(); entered = true; lock.unlock()
            gate.wait()
            lock.lock(); finished = true; lock.unlock()
            return skills
        }
    }

    private func skill(_ name: String) -> SkillMetadata {
        SkillMetadata(name: name, title: name, description: "")
    }

    private func makeService(_ scanner: SkillScanning) -> SkillService {
        SkillService(scanner: scanner, builtinProvider: EmptyBuiltin())
    }

    private func waitUntil(iterations: Int = 200, condition: @MainActor () -> Bool) async {
        for _ in 0..<iterations {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    private func waitForScanner(iterations: Int = 200, condition: () -> Bool) async {
        for _ in 0..<iterations {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    @Test("移除最后一个项目：立刻清空项目技能，顶部计数归零")
    func removingLastProjectClearsSkillsImmediately() async {
        let viewModel = SkillSettingsViewModel(
            service: makeService(PathScanner(["/tmp/p": [skill("alpha"), skill("beta")]]))
        )
        viewModel.updateProjects([ProjectInfo(name: "P", path: "/tmp/p")])
        await waitUntil { viewModel.projectSkills.count == 2 }
        #expect(viewModel.availableSkillCount == 2)

        viewModel.updateProjects([])

        // 同步断言：清空不能依赖下一次异步 reload。
        #expect(viewModel.selectedProjectPath == nil)
        #expect(viewModel.projectSkills.isEmpty)
        #expect(viewModel.availableSkillCount == 0)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("移除最后一个项目：顶部只剩仍然存在的通用底座技能")
    func removingLastProjectKeepsOnlyBaseSkills() async {
        let viewModel = SkillSettingsViewModel(
            service: makeService(PathScanner(["/tmp/p": [skill("alpha")]]))
        )
        viewModel.updateBaseSkills([skill("base-one"), skill("base-two")])
        viewModel.updateProjects([ProjectInfo(name: "P", path: "/tmp/p")])
        await waitUntil { viewModel.projectSkills.count == 1 }
        #expect(viewModel.availableSkillCount == 3)

        viewModel.updateProjects([])

        #expect(viewModel.projectSkills.isEmpty)
        #expect(viewModel.availableSkillCount == 2)
    }

    @Test("移除选中项目但仍有其他项目：改选剩余项目并加载它的技能")
    func removingSelectedProjectFallsBackToRemainingProject() async {
        let viewModel = SkillSettingsViewModel(service: makeService(PathScanner([
            "/tmp/a": [skill("a-skill")],
            "/tmp/b": [skill("b-skill")],
        ])))
        viewModel.updateProjects([
            ProjectInfo(name: "A", path: "/tmp/a"),
            ProjectInfo(name: "B", path: "/tmp/b"),
        ])
        viewModel.selectProject(path: "/tmp/b")
        await waitUntil { viewModel.projectSkills.map(\.name) == ["b-skill"] }

        viewModel.updateProjects([ProjectInfo(name: "A", path: "/tmp/a")])
        // 改选剩余项目时保留旧列表直到新扫描完成，不做同步清空。
        #expect(viewModel.projectSkills.map(\.name) == ["b-skill"])
        await waitUntil { viewModel.projectSkills.map(\.name) == ["a-skill"] }

        #expect(viewModel.selectedProjectPath == "/tmp/a")
        #expect(viewModel.projectSkills.map(\.name) == ["a-skill"])
        #expect(viewModel.availableSkillCount == 1)
    }

    @Test("扫描途中移除最后一个项目：旧项目的结果不得写回")
    func inFlightScanDoesNotRestoreRemovedProjectSkills() async {
        let scanner = GatedScanner([skill("alpha")])
        let viewModel = SkillSettingsViewModel(service: makeService(scanner))
        viewModel.updateProjects([ProjectInfo(name: "P", path: "/tmp/p")])
        await waitForScanner { scanner.didEnter }
        #expect(scanner.didEnter)

        viewModel.updateProjects([])
        #expect(viewModel.projectSkills.isEmpty)

        scanner.openGate()
        await waitForScanner { scanner.didFinished }
        // 让晚到的 reload 有机会写回，再断言它被身份校验丢弃。
        try? await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.selectedProjectPath == nil)
        #expect(viewModel.projectSkills.isEmpty, "已移除项目的扫描结果不得重新出现在列表里")
        #expect(viewModel.availableSkillCount == 0)
        #expect(!viewModel.isLoading)
    }
}