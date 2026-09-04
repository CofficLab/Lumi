import Testing
import Foundation
import KernelCore
import ProviderSkill

@testable import PluginXcodeBuild

@Suite("XcodeBuildSkillPlugin")
@MainActor
struct XcodeBuildPluginTests {

    @Test("contributor 从 Resources 目录加载 xcode-build 技能")
    func contributorLoadsSkillFromResources() {
        let contributor = XcodeBuildSkillContributor()
        #expect(contributor.allSkills.count == 1)
        let skill = contributor.allSkills[0]
        #expect(skill.name == "xcode-build")
        #expect(skill.triggers.contains("xcode") == true)
        // metadata.json 进来的技能 contentPath 指向 SKILL.md
        #expect(skill.contentPath.hasSuffix("SKILL.md"))
    }

    @Test("技能正文可通过 loadContent 从 SKILL.md 读取")
    func skillContentLoadsFromBundle() {
        let contributor = XcodeBuildSkillContributor()
        let skill = contributor.allSkills[0]
        let content = skill.loadContent()
        #expect(content != nil)
        #expect(content?.contains("xcodebuild") == true)
        #expect(content?.contains("# Xcode Build 规范") == true)
    }

    @Test("onBoot 注入 SkillProviding，onShutdown 幂等撤回")
    func pluginLifecycleInjectsAndRevokes() throws {
        let kernel = KernelCoreContainer()
        let provider = DefaultSkillProvider()
        try kernel.registerProvider((any SkillProviding).self, provider)

        let plugin = XcodeBuildPlugin()
        try plugin.onBoot(kernel: kernel)

        // 已注入且可被聚合查询到。
        #expect(provider.isProviderRegistered(providerID: XcodeBuildPlugin.pluginID))
        let skills = provider.allSkills()
        #expect(skills.contains { $0.name == "xcode-build" })

        // 重复 onBoot 幂等（不重复注册）。
        try plugin.onBoot(kernel: kernel)
        #expect(provider.contributors.count == 1)

        // 撤回后不再存在。
        try plugin.onShutdown(kernel: kernel)
        #expect(!provider.isProviderRegistered(providerID: XcodeBuildPlugin.pluginID))
        #expect(provider.allSkills().isEmpty)
    }

    @Test("内核未装配 SkillProviding 时 onBoot 安全降级")
    func onBootWithoutProviderDegradesGracefully() throws {
        let kernel = KernelCoreContainer()
        let plugin = XcodeBuildPlugin()
        // 不应抛错，也不应崩溃。
        try plugin.onBoot(kernel: kernel)
        try plugin.onShutdown(kernel: kernel)
    }
}