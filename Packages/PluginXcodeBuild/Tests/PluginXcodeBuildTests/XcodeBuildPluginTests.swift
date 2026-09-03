import Testing
import Foundation
import KernelCore
import ProviderSkill

@testable import PluginXcodeBuild

@Suite("XcodeBuildSkillPlugin")
@MainActor
struct XcodeBuildPluginTests {

    @Test("contributor 提供 xcode-build 技能与内嵌正文")
    func contributorProvidesSkill() {
        let contributor = XcodeBuildSkillContributor()
        #expect(contributor.allSkills.count == 1)
        let skill = contributor.allSkills[0]
        #expect(skill.name == "xcode-build")
        #expect(skill.content?.contains("xcodebuild") == true)
        #expect(skill.triggers.contains("xcode") == true)
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