import Foundation
import MagicKit
import os

/// LSP 上下文命令编辑器插件：添加跳转到定义和重命名等命令
actor LSPContextCommandsEditorPlugin: SuperPlugin, SuperLog {
    nonisolated static let emoji = "🔌"
    nonisolated static let verbose: Bool = false

    static let id = "LSPContextCommandsEditor"
    static let displayName = String(localized: "LSP Context Commands", table: "LSPContextCommandsEditor")
    static let description = String(localized: "Adds LSP context commands like go to definition and rename.", table: "LSPContextCommandsEditor")
    static let iconName = "command"
    static let order = 15
    static let enable = true
    static var isConfigurable: Bool { true }

    nonisolated var providesEditorExtensions: Bool { true }

    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.lsp-context-commands")

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        let contributor = LSPContextCommandContributor()
        registry.registerCommandContributor(contributor)
        if Self.verbose {
            Self.logger.info("\(Self.t)注册 CommandContributor 完成, contributorId=\(contributor.id)")
        }
    }
}
