import EditorService
import Foundation
import os
import LumiCoreKit
import ShellKit
import SwiftUI
import XcodeKit

/// Swift 插件日志辅助（插件内共享）
public enum SwiftPluginLog {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.swift")
    nonisolated(unsafe) static var verbose: Bool = true
}

/// Swift / Xcode 项目编辑器扩展：语法高亮、LSP、构建上下文与 Xcode 集成
public enum EditorSwiftEditorPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "swift"

    public static let info = LumiPluginInfo(
        id: "EditorSwift",
        displayName: LumiPluginLocalization.string("Swift Editor", bundle: .module),
        description: LumiPluginLocalization.string("Provides Swift language support, Xcode project identity, build context, and sourcekit-lsp integration.", bundle: .module),
        order: 4
    )

    public static func registerEditorExtensions(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        if SwiftPluginLog.verbose {
            SwiftPluginLog.logger.info("开始注册编辑器扩展")
        }

        registry.registerLanguage(EditorSwiftPluginDescriptor.swift)
        registry.registerGrammarProvider(EditorSwiftGrammarProvider())

        if let sourceKitPath = SwiftLSPConfig.resolveSourceKitLSPPath() {
            LSPConfig.registerServerProvider(for: "swift") {
                LSPConfig.ServerConfig(
                    languageId: "swift",
                    execPath: sourceKitPath
                )
            }
        }

        let buildContextProvider = XcodeBuildContextProvider(
            store: EditorSwiftBuildServerStore.makeStore()
        )
        let projectContextCapability = XcodeProjectContextCapabilityAdapter()
        let semanticCapability = XcodeSemanticCapabilityAdapter()
        let languageIntegrationCapability = XcodeLanguageIntegrationCapabilityAdapter()

        XcodeProjectContextBridge.shared.registerBuildContextProvider(buildContextProvider)
        if let bundledTool = Bundle.module.url(forResource: "xcode-build-server", withExtension: nil, subdirectory: "Tools") {
            XcodeBuildServerLocator.bundledToolPath = bundledTool.path
        }
        EditorSwiftHostEnvironmentConfiguration.apply()
        if SwiftPluginLog.verbose {
            SwiftPluginLog.logger.info("已注册 buildContextProvider 到 Bridge")
        }

        registry.registerCompletionContributor(XcodePlistCompletionContributor())
        registry.registerCompletionContributor(SwiftPrimitiveTypeCompletionContributor())
        registry.registerHoverContributor(XcodePlistHoverContributor())
        registry.registerHoverContributor(XcodePackageManifestHoverContributor())
        registry.registerHoverContributor(EditorSwiftKeywordHoverContributor())
        registry.registerCodeActionContributor(SwiftSelectionCodeActionContributor())
        registry.registerQuickOpenContributor(XcodeProjectQuickOpenContributor())
        registry.registerProjectContextCapability(projectContextCapability)
        registry.registerSemanticCapability(semanticCapability)
        registry.registerLanguageIntegrationCapability(languageIntegrationCapability)
        registry.registerCommandContributor(SwiftRunCommandContributor())

        if SwiftPluginLog.verbose {
            SwiftPluginLog.logger.info("编辑器扩展注册完成")
        }
    }
}
