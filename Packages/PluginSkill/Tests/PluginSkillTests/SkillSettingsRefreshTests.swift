import Foundation
import Testing
import ProviderProject
import ProviderSkill

@testable import PluginSkill

/// 回归 #642：技能设置页「刷新」未使 SkillService 缓存失效。
///
/// `refresh()` 只重新 `reload()`，而 `listSkills` 在 30s TTL 内直接返回缓存，
/// 外部编辑器/Finder 的增删改在 TTL 内不可见。显式刷新必须先使选中项目的
/// 缓存失效再重扫磁盘（与 SkillChatToolbarViewModel 的失效路径一致）。
@Suite("SkillSettingsRefresh（#642）")
@MainActor
struct SkillSettingsRefreshTests {

    /// 可变扫描器：模拟两次扫描之间外部文件发生变化。
    private final class MutableScanner: SkillScanning, @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [SkillMetadata]
        init(_ skills: [SkillMetadata]) { storage = skills }
        var skills: [SkillMetadata] {
            get { lock.lock(); defer { lock.unlock() }; return storage }
            set { lock.lock(); defer { lock.unlock() }; storage = newValue }
        }
        func scanSkills(projectPath: String) -> [SkillMetadata] { skills }
    }

    private struct EmptyBuiltin: BuiltinSkillProviding {
        func builtinSkills() -> [SkillMetadata] { [] }
    }

    private func skill(_ name: String) -> SkillMetadata {
        SkillMetadata(name: name, title: name, description: "")
    }

    private func makeViewModel(_ scanner: MutableScanner) -> SkillSettingsViewModel {
        let service = SkillService(scanner: scanner, builtinProvider: EmptyBuiltin())
        let viewModel = SkillSettingsViewModel(service: service)
        viewModel.updateProjects([ProjectInfo(name: "P", path: "/tmp/refresh-proj")])
        return viewModel
    }

    private func waitUntil(iterations: Int = 100, condition: @MainActor () -> Bool) async {
        for _ in 0..<iterations {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    @Test("刷新使缓存失效，外部新增的技能立即可见")
    func refreshRescansAfterExternalChange() async {
        let scanner = MutableScanner([skill("alpha")])
        let viewModel = makeViewModel(scanner)
        viewModel.selectProject(path: "/tmp/refresh-proj")
        await waitUntil { viewModel.projectSkills.map(\.name) == ["alpha"] }
        #expect(viewModel.projectSkills.map(\.name) == ["alpha"])

        // 外部新增 beta；TTL 内点击刷新必须重扫磁盘，而不是命中旧缓存。
        scanner.skills = [skill("alpha"), skill("beta")]
        viewModel.refresh()
        await waitUntil { viewModel.projectSkills.contains { $0.name == "beta" } }
        #expect(viewModel.projectSkills.map(\.name) == ["alpha", "beta"])
    }

    @Test("刷新使缓存失效，外部删除的技能立即消失")
    func refreshReflectsExternalDeletion() async {
        let scanner = MutableScanner([skill("alpha"), skill("beta")])
        let viewModel = makeViewModel(scanner)
        viewModel.selectProject(path: "/tmp/refresh-proj")
        await waitUntil { viewModel.projectSkills.map(\.name) == ["alpha", "beta"] }
        #expect(viewModel.projectSkills.count == 2)

        scanner.skills = [skill("alpha")]
        viewModel.refresh()
        await waitUntil { viewModel.projectSkills.count == 1 }
        #expect(viewModel.projectSkills.map(\.name) == ["alpha"])
    }

    @Test("无选中项目时刷新清空技能且不崩溃")
    func refreshWithoutSelectionClearsSkills() async {
        // 不调用 updateProjects（会自动选中首个项目），保持 selectedProjectPath 为 nil。
        let service = SkillService(scanner: MutableScanner([skill("alpha")]), builtinProvider: EmptyBuiltin())
        let viewModel = SkillSettingsViewModel(service: service)
        viewModel.refresh()
        await waitUntil { !viewModel.isLoading }
        #expect(viewModel.selectedProjectPath == nil)
        #expect(viewModel.projectSkills.isEmpty)
    }
}