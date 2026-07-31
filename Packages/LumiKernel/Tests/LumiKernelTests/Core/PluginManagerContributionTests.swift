import Foundation
import Testing
@testable import LumiKernel

/// `PluginManager` 的贡献收集测试(以编辑器运行时插件为样本)。
///
/// 模块对应:`Sources/LumiKernel/Managers/PluginManager.swift`。
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
}
