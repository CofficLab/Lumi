import Foundation
import Testing
import KernelCore
import ProviderChatSection
import ProviderLifecycleHooks
import ProviderProject
import ProviderSkill

@testable import PluginSkill

@Suite("SkillPlugin")
@MainActor
struct SkillPluginTests {
    /// Mock scanner：返回固定技能列表。
    private struct MockScanner: SkillScanning {
        let skills: [SkillMetadata]
        func scanSkills(projectPath: String) -> [SkillMetadata] { skills }
    }

    @Test("PromptBuilder 构造技能列表 prompt")
    func promptBuilder() {
        let skills = [
            SkillMetadata(name: "swiftui-expert", title: "SwiftUI Expert", description: "SwiftUI 最佳实践", triggers: ["swiftui"]),
            SkillMetadata(name: "debugger", title: "Debugger", description: "系统化调试", version: "2.0.0"),
        ]
        let prompt = SkillPromptBuilder.buildPrompt(skills: skills)
        #expect(prompt.contains("Available Skills"))
        #expect(prompt.contains("swiftui-expert"))
        #expect(prompt.contains("debugger"))
    }

    @Test("SkillMergePolicy 合并内置与项目技能，同名项目优先")
    func mergePolicy() {
        let builtin = [
            SkillMetadata(name: "swiftui-standards", title: "SwiftUI Standards", description: "内置规范"),
            SkillMetadata(name: "planner", title: "Planner", description: "内置规划"),
        ]
        let project = [
            SkillMetadata(name: "swiftui-standards", title: "项目定制 SwiftUI", description: "项目覆盖版本"),
            SkillMetadata(name: "architect", title: "Architect", description: "项目架构"),
        ]
        let merged = SkillMergePolicy.merge(builtin: builtin, project: project)
        // 去重：同名只保留项目版本
        #expect(merged.count == 3)
        let names = Set(merged.map(\.name))
        #expect(names == ["swiftui-standards", "planner", "architect"])
        // 项目覆盖内置
        #expect(merged.first { $0.name == "swiftui-standards" }?.title == "项目定制 SwiftUI")
        // 排序稳定
        #expect(merged.map(\.name) == ["architect", "planner", "swiftui-standards"])
    }

    @Test("SkillService 合并底座与项目技能")
    func serviceMergesBuiltin() async {
        struct FakeScanner: SkillScanning {
            func scanSkills(projectPath: String) -> [SkillMetadata] {
                [SkillMetadata(name: "architect", title: "Architect", description: "项目架构")]
            }
        }
        let service = SkillService(scanner: FakeScanner(), builtinProvider: EmptyBuiltin())
        let base = [
            SkillMetadata(name: "swiftui-standards", title: "SwiftUI Standards", description: "内置规范"),
        ]
        let skills = await service.listSkills(projectPath: "/tmp/proj", baseSkills: base)
        #expect(skills.count == 2)
        #expect(skills.contains { $0.name == "swiftui-standards" })
        #expect(skills.contains { $0.name == "architect" })
    }

    @Test("SkillService 空项目路径时仅返回底座")
    func serviceEmptyProjectPath() async {
        struct FakeScanner: SkillScanning {
            func scanSkills(projectPath: String) -> [SkillMetadata] {
                [SkillMetadata(name: "architect", title: "Architect", description: "项目架构")]
            }
        }
        let service = SkillService(scanner: FakeScanner(), builtinProvider: EmptyBuiltin())
        let base = [
            SkillMetadata(name: "swiftui-standards", title: "SwiftUI Standards", description: "内置规范"),
        ]
        let skills = await service.listSkills(projectPath: "", baseSkills: base)
        #expect(skills.count == 1)
        #expect(skills.first?.name == "swiftui-standards")
    }

    @Test("SkillService 扫描并缓存")
    func serviceScansAndCaches() async {
        let skills = [SkillMetadata(name: "a", title: "A", description: "desc")]
        let service = SkillService(scanner: MockScanner(skills: skills), builtinProvider: EmptyBuiltin())
        let first = await service.listSkills(projectPath: "/tmp/proj")
        #expect(first.count == 1)
        #expect(first.first?.name == "a")
        // 缓存命中（TTL 内不重新扫描）
        let second = await service.listSkills(projectPath: "/tmp/proj")
        #expect(second.count == 1)
        await service.invalidateCache(projectPath: "/tmp/proj")
    }

    @Test("插件 onBoot 注册工具栏且不抛错")
    func pluginLifecycle() async throws {
        let kernel = KernelCoreContainer()
        let project = DefaultProjectProvider()
        try await project.openProject(at: "/tmp/proj")
        let chat = DefaultChatSectionProviding()
        let skillProvider = DefaultSkillProvider()
        let hooks = DefaultLifecycleHooksProvider()
        try kernel.registerProvider((any ProjectProviding).self, project)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        try kernel.registerProvider((any SkillProviding).self, skillProvider)
        try kernel.registerProvider((any LifecycleHooksProviding).self, hooks)

        let plugin = SkillPlugin()
        try plugin.onBoot(kernel: kernel)
        #expect(kernel.resolveProvider((any ProjectProviding).self) != nil)
        #expect(chat.barItems.map(\.id) == ["com.coffic.lumi.plugin.skill.toolbar"])
        #expect(skillProvider.isProviderRegistered(providerID: SkillPlugin.builtinContributorID))
        #expect(hooks.revision == 1)

        try plugin.onShutdown(kernel: kernel)
        #expect(chat.barItems.isEmpty)
        #expect(!skillProvider.isProviderRegistered(providerID: SkillPlugin.builtinContributorID))
        #expect(hooks.revision == 2)
    }

    @Test("当前项目和技能贡献变化会更新工具栏 ViewModel")
    func toolbarObserverUpdatesViewModel() async throws {
        let project = DefaultProjectProvider()
        let skills = DefaultSkillProvider()
        let baseSkill = SkillMetadata(name: "shared", title: "Shared", description: "")
        skills.addProvider(StaticSkillContributor(providerID: "tests.base", skills: [baseSkill]))

        let service = SkillService(
            scanner: ProjectPathScanner(),
            builtinProvider: EmptyBuiltin()
        )
        let viewModel = SkillChatToolbarViewModel(service: service)
        let observer = SkillChatToolbarObserver(
            projectProvider: project,
            skillProvider: skills,
            viewModel: viewModel
        )

        #expect(viewModel.currentProjectPath == nil)
        #expect(viewModel.skills.map(\.name) == ["shared"])

        try await project.openProject(at: "/tmp/skill-project-one")
        await waitUntil { viewModel.skills.contains { $0.name == "skill-project-one" } }
        #expect(viewModel.currentProjectPath == "/tmp/skill-project-one")
        #expect(viewModel.skills.map(\.name).contains("shared"))

        try await project.openProject(at: "/tmp/skill-project-two")
        #expect(viewModel.currentProjectPath == "/tmp/skill-project-two")
        #expect(viewModel.skills.map(\.name) == ["shared"])
        await waitUntil { viewModel.skills.contains { $0.name == "skill-project-two" } }
        #expect(!viewModel.skills.contains { $0.name == "skill-project-one" })

        let contributedSkill = SkillMetadata(name: "extra", title: "Extra", description: "")
        skills.addProvider(StaticSkillContributor(providerID: "tests.extra", skills: [contributedSkill]))
        await waitUntil {
            viewModel.skills.contains { $0.name == "extra" }
                && viewModel.skills.contains { $0.name == "skill-project-two" }
        }

        await project.closeProject()
        #expect(viewModel.currentProjectPath == nil)
        #expect(Set(viewModel.skills.map(\.name)) == ["extra", "shared"])

        observer.cancel()
        try await project.openProject(at: "/tmp/skill-project-ignored")
        #expect(viewModel.currentProjectPath == nil)
        viewModel.cancel()
    }

    private func waitUntil(
        iterations: Int = 100,
        condition: @MainActor () -> Bool
    ) async {
        for _ in 0..<iterations {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
    }
}

/// 测试用空内置提供者。
private struct EmptyBuiltin: BuiltinSkillProviding {
    func builtinSkills() -> [SkillMetadata] { [] }
}

private struct ProjectPathScanner: SkillScanning {
    func scanSkills(projectPath: String) -> [SkillMetadata] {
        let name = URL(fileURLWithPath: projectPath).lastPathComponent
        return [SkillMetadata(name: name, title: name, description: "")]
    }
}
