import Foundation
import os
import MagicKit

/// 编辑器插件管理器（纯安装器）。
///
/// Phase 4: 已精简为纯安装器，不再维护插件开关状态。
/// 插件发现由 `PluginVM` 统一负责，开关由 `PluginSettingsVM` 统一管理。
/// 此管理器只负责接收已过滤的插件列表并安装到 `EditorExtensionRegistry`。
@MainActor
final class EditorPluginManager: ObservableObject, SuperLog {
    nonisolated static let emoji = "🔌"

    private let logger = Logger(subsystem: "com.coffic.lumi", category: "editor.plugin-manager")

    /// 扩展点注册中心（由具体插件写入能力）
    let registry: EditorExtensionRegistry

    /// 已安装的编辑器插件（按 order 排序，完全由外部传入）
    @Published private(set) var installedPlugins: [any SuperPlugin] = []

    init(registry: EditorExtensionRegistry = EditorExtensionRegistry()) {
        self.registry = registry
    }

    /// 安装一组编辑器插件（纯安装器，不维护开关状态）
    ///
    /// 调用方（如 `EditorState`）负责从 `PluginVM` 过滤出已启用的编辑器插件，
    /// 然后调用此方法将它们安装到 `EditorExtensionRegistry`。
    ///
    /// - Parameter plugins: 已过滤的编辑器插件列表（仅包含 `providesEditorExtensions == true` 且已启用的插件）
    func install(plugins: [any SuperPlugin]) {
        // Reset registry before reinstalling
        registry.reset()

        // Sort by order, then by id
        let sorted = plugins.sorted { a, b in
            if type(of: a).order != type(of: b).order {
                return type(of: a).order < type(of: b).order
            }
            return type(of: a).id.localizedCaseInsensitiveCompare(type(of: b).id) == .orderedAscending
        }

        installedPlugins = sorted

        // Register editor extensions for each plugin
        for plugin in sorted {
            plugin.registerEditorExtensions(into: registry)
            logger.info("\(self.t)安装编辑器插件: \(type(of: plugin).id) (\(type(of: plugin).displayName))")
        }

        logger.info("\(self.t)安装完成: \(sorted.count) 个编辑器插件")
    }

    /// 卸载所有已安装的编辑器插件
    func uninstallAll() {
        installedPlugins.removeAll()
        registry.reset()
        logger.info("\(self.t)已卸载所有编辑器插件")
    }
}
