import Foundation
@testable import KernelLumi

/// 测试用 `EditorProviding` 实现,记录注册/替换的插件 id 列表。
@MainActor
final class MockEditorProviding: EditorProviding {
    var currentFilePath: String?
    var currentThemeId: String = "default"
    var allEditorThemes: [EditorThemeInfo] = []
    /// `replaceEditorPlugins` 按序记录的插件 id(用于断言排序/筛选)。
    private(set) var replacedPluginIDs: [String] = []
    private(set) var registeredPluginIDs: [String] = []

    func openFile(at path: String) async throws {
        currentFilePath = path
    }

    func closeFile(at path: String) async {
        if currentFilePath == path {
            currentFilePath = nil
        }
    }

    func setCurrentTheme(_ themeId: String) throws {
        currentThemeId = themeId
    }

    func registerEditorTheme(_ theme: EditorThemeInfo) {
        allEditorThemes.append(theme)
    }

    func unregisterEditorTheme(themeId: String) {
        allEditorThemes.removeAll { $0.id == themeId }
    }

    func registerEditorPlugin(_ plugin: any EditorPlugin) {
        registeredPluginIDs.append(plugin.id)
    }

    func replaceEditorPlugins(_ plugins: [any EditorPlugin]) {
        replacedPluginIDs = plugins.map(\.id)
    }
}

/// 测试用编辑器运行时插件。
@MainActor
final class MockEditorRuntimePlugin: EditorPlugin {
    let id: String
    let name: String
    let order: Int

    init(id: String, name: String, order: Int) {
        self.id = id
        self.name = name
        self.order = order
    }

    func registerExtensions(into registrar: any EditorExtensionRegistrar) {}
}
