import Foundation
import Testing
@testable import KernelLumi

/// `PromptSuggestionProviding` / `PromptSuggestionManager` 及其插件收集链路测试。
///
/// 模块对应:
/// - `Sources/KernelLumi/Providers/PromptSuggestionProviding.swift`
/// - `Sources/KernelLumi/Managers/PromptSuggestionManager.swift`
/// - `Sources/KernelLumi/Managers/PluginManager.swift`（`registerPromptSuggestions`）
@Suite("Prompt Suggestions")
@MainActor
struct PromptSuggestionProvidingTests {

    // MARK: - PromptSuggestionManager

    @Test("register 按 order 排序，同 order 保持插入顺序")
    func registersOrderedByOrder() {
        let manager = PromptSuggestionManager()

        var low = LumiPromptSuggestion(id: "low", title: "低序")
        low.order = 10
        var high = LumiPromptSuggestion(id: "high", title: "高序")
        high.order = 300
        // 同 order（默认 200）的两条，应保持插入顺序 midA → midB
        let midA = LumiPromptSuggestion(id: "midA", title: "中A")
        let midB = LumiPromptSuggestion(id: "midB", title: "中B")

        // 故意乱序注册
        manager.registerPromptSuggestion(high)
        manager.registerPromptSuggestion(midA)
        manager.registerPromptSuggestion(low)
        manager.registerPromptSuggestion(midB)

        #expect(manager.allPromptSuggestions.map(\.id) == ["low", "midA", "midB", "high"])
    }

    @Test("相同 id 覆盖更新，不产生重复")
    func overwritesDuplicateID() {
        let manager = PromptSuggestionManager()

        manager.registerPromptSuggestion(LumiPromptSuggestion(id: "x", title: "旧", prompt: "old"))
        manager.registerPromptSuggestion(LumiPromptSuggestion(id: "x", title: "新", prompt: "new"))

        #expect(manager.allPromptSuggestions.count == 1)
        #expect(manager.allPromptSuggestions.first?.title == "新")
        #expect(manager.allPromptSuggestions.first?.prompt == "new")
    }

    @Test("unregister 移除指定项，缺失 id 为 no-op")
    func unregistersByID() {
        let manager = PromptSuggestionManager()
        manager.registerPromptSuggestion(LumiPromptSuggestion(id: "a", title: "A"))
        manager.registerPromptSuggestion(LumiPromptSuggestion(id: "b", title: "B"))

        manager.unregisterPromptSuggestion(id: "a")
        #expect(manager.allPromptSuggestions.map(\.id) == ["b"])

        // 不存在的 id 不报错、不影响其余项
        manager.unregisterPromptSuggestion(id: "missing")
        #expect(manager.allPromptSuggestions.map(\.id) == ["b"])
    }

    @Test("clearAllContributions 清空")
    func clearsAll() {
        let manager = PromptSuggestionManager()
        manager.registerPromptSuggestion(LumiPromptSuggestion(id: "a", title: "A"))
        manager.registerPromptSuggestion(LumiPromptSuggestion(id: "b", title: "B"))

        manager.clearAllContributions()

        #expect(manager.allPromptSuggestions.isEmpty)
    }

    @Test("prompt 缺省回退为 title，order 为默认占位值")
    func promptDefaultsToTitle() {
        let item = LumiPromptSuggestion(id: "x", title: "帮我设计一个图标")

        #expect(item.prompt == "帮我设计一个图标")
        #expect(item.order == 200)  // 默认值，内核收集时会用插件 order 覆盖
    }

    @Test("requiresProject 缺省为 false，声明后经聚合保留")
    func requiresProjectDefaultsAndSurvivesAggregation() async throws {
        // 缺省不要求项目
        let plain = LumiPromptSuggestion(id: "x", title: "普通提示")
        #expect(plain.requiresProject == false)

        let kernel = KernelTestKit.makeKernel()
        try kernel.registerPromptSuggestionService(PromptSuggestionManager())

        let manager = PluginManager()
        try await manager.initializePlugins([
            MockLumiPlugin(
                id: "overview",
                order: 100,
                promptSuggestions: [
                    LumiPromptSuggestion(
                        id: "overview.overview",
                        title: "生成项目概览",
                        requiresProject: true
                    ),
                    LumiPromptSuggestion(id: "overview.plain", title: "普通提示"),
                ]
            ),
        ], kernel: kernel)

        manager.registerPromptSuggestions(in: kernel)

        let collected = kernel.promptSuggestions?.allPromptSuggestions ?? []
        let overview = collected.first { $0.id == "overview.overview" }
        #expect(overview?.requiresProject == true)
        let other = collected.first { $0.id == "overview.plain" }
        #expect(other?.requiresProject == false)
    }

    // MARK: - PluginManager 收集链路

    @Test("收集插件贡献的提示词并按插件 order 盖戳排序")
    func collectsPluginSuggestions() async throws {
        let kernel = KernelTestKit.makeKernel()
        try kernel.registerPromptSuggestionService(PromptSuggestionManager())

        let manager = PluginManager()
        try await manager.initializePlugins([
            MockLumiPlugin(
                id: "icon-designer",
                order: 250,
                promptSuggestions: [
                    LumiPromptSuggestion(id: "icon-designer.design", title: "帮我设计一个图标"),
                    LumiPromptSuggestion(id: "icon-designer.resize", title: "调整图标尺寸"),
                ]
            ),
            MockLumiPlugin(
                id: "writer",
                order: 200,
                promptSuggestions: [
                    LumiPromptSuggestion(id: "writer.draft", title: "帮我写一段文案"),
                ]
            ),
        ], kernel: kernel)

        manager.registerPromptSuggestions(in: kernel)

        // writer(order 200) 在前，icon-designer(order 250) 在后；
        // icon-designer 内两条保持插件返回顺序。
        let collected = kernel.promptSuggestions?.allPromptSuggestions ?? []
        #expect(collected.map(\.id) == [
            "writer.draft",
            "icon-designer.design",
            "icon-designer.resize",
        ])
        // 内核盖戳：已启用插件的提示词都带 pluginID 且 requiresEnable 为 false。
        #expect(collected.allSatisfy { $0.pluginID != nil })
        #expect(collected.allSatisfy { !$0.requiresEnable })
        // 未声明动作的提示词经聚合后 action 仍为 nil。
        #expect(collected.allSatisfy { $0.action == nil })
    }

    @Test("聚合保留提示词声明的 action")
    func aggregatesPreserveAction() async throws {
        let kernel = KernelTestKit.makeKernel()
        try kernel.registerPromptSuggestionService(PromptSuggestionManager())

        let manager = PluginManager()
        try await manager.initializePlugins([
            MockLumiPlugin(
                id: "designer",
                order: 100,
                policy: .alwaysOn,
                promptSuggestions: [
                    LumiPromptSuggestion(
                        id: "designer.open",
                        title: "打开设计器",
                        action: .activateViewContainer("designer")
                    ),
                    LumiPromptSuggestion(id: "designer.plain", title: "普通提示"),
                ]
            ),
        ], kernel: kernel)

        manager.registerPromptSuggestions(in: kernel)

        let suggestions = kernel.promptSuggestions?.allPromptSuggestions ?? []
        #expect(suggestions.count == 2)
        let open = suggestions.first { $0.id == "designer.open" }
        #expect(open?.action == .activateViewContainer("designer"))
        let plain = suggestions.first { $0.id == "designer.plain" }
        #expect(plain?.action == nil)
    }

    @Test("禁用但可配置的插件仍贡献提示词，标记 requiresEnable 与 pluginID")
    func disabledConfigurablePluginStillContributes() async throws {
        let kernel = KernelTestKit.makeKernel()
        try kernel.registerPromptSuggestionService(PromptSuggestionManager())

        let manager = PluginManager()
        try await manager.initializePlugins([
            MockLumiPlugin(
                id: "optin-plugin",
                order: 100,
                policy: .optIn,  // 默认禁用，但可启用
                promptSuggestions: [LumiPromptSuggestion(id: "optin-plugin.start", title: "开始")]
            ),
        ], kernel: kernel)

        manager.registerPromptSuggestions(in: kernel)

        let suggestions = kernel.promptSuggestions?.allPromptSuggestions ?? []
        #expect(suggestions.count == 1)
        #expect(suggestions.first?.id == "optin-plugin.start")
        #expect(suggestions.first?.pluginID == "optin-plugin")
        #expect(suggestions.first?.requiresEnable == true)
    }

    @Test("启用插件后其提示词 requiresEnable 变为 false")
    func enablingFlipsRequiresEnable() async throws {
        let kernel = KernelTestKit.makeKernel()
        try kernel.registerPromptSuggestionService(PromptSuggestionManager())

        let manager = PluginManager()
        try await manager.initializePlugins([
            MockLumiPlugin(
                id: "optin-plugin",
                order: 100,
                policy: .optIn,
                promptSuggestions: [LumiPromptSuggestion(id: "optin-plugin.start", title: "开始")]
            ),
        ], kernel: kernel)

        manager.registerPromptSuggestions(in: kernel)
        #expect(kernel.promptSuggestions?.allPromptSuggestions.first?.requiresEnable == true)

        // 启用后重新收集，requiresEnable 应翻转为 false。
        _ = await manager.setPluginEnabled(id: "optin-plugin", enabled: true)
        manager.registerPromptSuggestions(in: kernel)
        #expect(kernel.promptSuggestions?.allPromptSuggestions.first?.requiresEnable == false)
    }

    @Test("rebuild 时剔除 disabled 插件的提示词")
    func rebuildWithdrawsDisabled() async throws {
        let kernel = KernelTestKit.makeKernel()
        try kernel.registerPromptSuggestionService(PromptSuggestionManager())

        let manager = PluginManager()
        try await manager.initializePlugins([
            MockLumiPlugin(
                id: "enabled",
                order: 10,
                policy: .alwaysOn,
                promptSuggestions: [LumiPromptSuggestion(id: "keep", title: "保留")]
            ),
            MockLumiPlugin(
                id: "disabled",
                order: 20,
                policy: .disabled,
                promptSuggestions: [LumiPromptSuggestion(id: "drop", title: "丢弃")]
            ),
        ], kernel: kernel)

        manager.rebuildAllContributions(in: kernel)

        let ids = kernel.promptSuggestions?.allPromptSuggestions.map(\.id) ?? []
        #expect(ids == ["keep"])
    }
}
