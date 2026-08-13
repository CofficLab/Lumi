import Combine
import Foundation
import Testing
@testable import KernelLumi

/// `PluginManager` 的贡献收集测试(以编辑器运行时插件为样本)。
///
/// 模块对应:`Sources/KernelLumi/Managers/PluginManager.swift`。
/// 验证插件按 order 排序、disabled 插件贡献被剔除等装配规则。
@Suite("PluginManager Contributions")
@MainActor
struct PluginManagerContributionTests {
    @Test("按 order 排序注册 typed editor 插件")
    func registersTypedEditorPluginsOrdered() async throws {
        let kernel = KernelTestKit.makeKernel()
        let editor = MockEditorProviding()
        try kernel.registerEditor(editor)

        let manager = PluginManager()
        let swiftLanguage = MockEditorRuntimePlugin(id: "swift", name: "Swift", order: 20)
        let goLanguage = MockEditorRuntimePlugin(id: "go", name: "Go", order: 10)
        try await manager.initializePlugins([
            MockLumiPlugin(id: "swift-plugin", order: 20, editorRuntimePlugins: [swiftLanguage]),
            MockLumiPlugin(id: "go-plugin", order: 10, editorRuntimePlugins: [goLanguage]),
        ], kernel: kernel)

        manager.registerEditorPlugins(in: kernel)

        #expect(editor.replacedPluginIDs == ["go", "swift"])
    }

    @Test("rebuild 时剔除 disabled 插件的贡献")
    func withdrawsDisabledOnRebuild() async throws {
        let kernel = KernelTestKit.makeKernel()
        let editor = MockEditorProviding()
        try kernel.registerEditor(editor)

        let manager = PluginManager()
        try await manager.initializePlugins([
            MockLumiPlugin(
                id: "enabled-language",
                order: 10,
                policy: .alwaysOn,
                editorRuntimePlugins: [MockEditorRuntimePlugin(id: "swift", name: "Swift", order: 10)]
            ),
            MockLumiPlugin(
                id: "disabled-language",
                order: 20,
                policy: .disabled,
                editorRuntimePlugins: [MockEditorRuntimePlugin(id: "go", name: "Go", order: 20)]
            ),
        ], kernel: kernel)

        manager.rebuildAllContributions(in: kernel)

        #expect(editor.replacedPluginIDs == ["swift"])
    }

    @Test("收集声明式命令菜单并在重建时撤回")
    func registersAndWithdrawsCommandMenuContributions() async throws {
        let kernel = KernelTestKit.makeKernel()
        let command = MockCommandProviding()
        try kernel.registerCommandService(command)

        let imperativeGroup = CommandMenuGroup(
            id: "imperative",
            name: "Imperative",
            items: []
        )
        command.registerCommandGroup(imperativeGroup)

        let contributedGroup = CommandMenuGroup(
            id: "plugin.commands",
            name: "Plugin",
            items: [],
            placement: .topLevelMenu
        )
        let manager = PluginManager()
        try await manager.initializePlugins([
            MockLumiPlugin(
                id: "command-plugin",
                order: 10,
                commandGroups: [contributedGroup]
            ),
        ], kernel: kernel)

        manager.registerPluginCommandContributions(in: kernel)

        #expect(command.allCommandGroups.map(\.id) == ["imperative", "plugin.commands"])

        try await manager.initializePlugins([
            MockLumiPlugin(
                id: "command-plugin",
                order: 10,
                policy: .disabled,
                commandGroups: [contributedGroup]
            ),
        ], kernel: kernel)
        manager.registerPluginCommandContributions(in: kernel)

        #expect(command.allCommandGroups.map(\.id) == ["imperative"])
    }
}

@MainActor
private final class MockCommandProviding: CommandProviding {
    @Published private(set) var allCommandGroups: [CommandMenuGroup] = []

    func commandGroup(named name: String) -> CommandMenuGroup? {
        allCommandGroups.first { $0.id == name }
    }

    func registerCommandGroup(_ group: CommandMenuGroup) {
        if let index = allCommandGroups.firstIndex(where: { $0.id == group.id }) {
            allCommandGroups[index] = group
        } else {
            allCommandGroups.append(group)
        }
    }

    func registerCommand(menu: String, item: CommandItem) {
        let existingItems = commandGroup(named: menu)?.items ?? []
        registerCommandGroup(
            CommandMenuGroup(id: menu, name: menu, items: existingItems + [item])
        )
    }

    func unregisterCommandGroup(id: String) {
        allCommandGroups.removeAll { $0.id == id }
    }
}
