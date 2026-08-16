import Combine
import Foundation
import Testing
@testable import KernelLumi

/// `PluginManager` 的贡献收集测试(以编辑器贡献包为样本)。
///
/// 模块对应:`Sources/KernelLumi/Managers/PluginManager.swift`。
/// 验证启用插件的 Bundle 被盖戳安装、disabled 插件贡献被剔除等装配规则。
@Suite("PluginManager Contributions")
@MainActor
struct PluginManagerContributionTests {
    @Test("启用的插件贡献包按插件维度盖戳安装")
    func installsStampedContributionBundles() async throws {
        let kernel = KernelTestKit.makeKernel()
        let hosting = MockEditorExtensionHosting()
        try kernel.registerEditorV2(MockEditorProvidingV2(extensions: hosting))

        let manager = PluginManager()
        try await manager.initializePlugins([
            MockLumiPlugin(id: "swift-plugin", order: 20, editorBundle: makeBundle(pluginID: "swift-plugin", languageID: "swift")),
            MockLumiPlugin(id: "go-plugin", order: 10, editorBundle: makeBundle(pluginID: "go-plugin", languageID: "go")),
        ], kernel: kernel)

        manager.registerEditorContributionBundles(in: kernel)
        await waitFor(hosting) { $0.installedPluginIDs.count >= 2 }

        // 按插件维度安装，且 pluginID 被盖戳覆盖（不信任插件自报归属）。
        #expect(Set(hosting.installedPluginIDs) == ["swift-plugin", "go-plugin"])
        #expect(hosting.receivedLanguageIDs.sorted() == ["go", "swift"])
    }

    @Test("rebuild 时撤回 disabled 插件的贡献包")
    func withdrawsDisabledBundleOnRebuild() async throws {
        let kernel = KernelTestKit.makeKernel()
        let hosting = MockEditorExtensionHosting()
        try kernel.registerEditorV2(MockEditorProvidingV2(extensions: hosting))

        let manager = PluginManager()
        try await manager.initializePlugins([
            MockLumiPlugin(
                id: "enabled-language",
                order: 10,
                policy: .alwaysOn,
                editorBundle: makeBundle(pluginID: "enabled-language", languageID: "swift")
            ),
            MockLumiPlugin(
                id: "disabled-language",
                order: 20,
                policy: .disabled,
                editorBundle: makeBundle(pluginID: "disabled-language", languageID: "go")
            ),
        ], kernel: kernel)

        manager.rebuildAllContributions(in: kernel)
        await waitFor(hosting) { $0.installedPluginIDs.count >= 1 }

        #expect(hosting.installedPluginIDs == ["enabled-language"])
        #expect(!hosting.withdrawnPluginIDs.contains("enabled-language"))
    }

    /// 等待异步装配完成（有界等待，避免测试挂死）。
    private func waitFor(
        _ hosting: MockEditorExtensionHosting,
        until condition: @MainActor @escaping (MockEditorExtensionHosting) -> Bool
    ) async {
        for _ in 0..<1000 where !condition(hosting) {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
    }

    private func makeBundle(pluginID: String, languageID: String) -> EditorContributionBundle {
        EditorContributionBundle(
            pluginID: pluginID,
            languages: [
                EditorLanguageContribution(
                    language: EditorLanguageDescriptor(
                        languageId: languageID,
                        displayName: languageID,
                        fileExtensions: []
                    )
                )
            ]
        )
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
