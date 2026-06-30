import EditorService
import Foundation
import LumiCoreKit
import os
import ShellKit
import SuperLogKit
import SwiftUI
import XcodeKit

/// Swift 插件日志辅助（插件内共享）
public enum SwiftPluginLog {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.swift")
    nonisolated(unsafe) static var verbose: Bool = false
}

/// Swift / Xcode 项目编辑器扩展：语法高亮、LSP、构建上下文与 Xcode 集成
public actor EditorSwiftEditorPlugin: SuperPlugin, SuperLog {
    public nonisolated static let policy: PluginPolicy = .alwaysOn
    public nonisolated static let emoji = "🐦"

    public static let shared = EditorSwiftEditorPlugin()
    public static let id = "EditorSwift"
    public static let displayName = LumiPluginLocalization.string("Swift Editor", bundle: .module)
    public static let description = LumiPluginLocalization.string("Provides Swift language support, Xcode project identity, build context, and sourcekit-lsp integration.", bundle: .module)
    public static let iconName = "swift"
    public static let order = 4
    public static var category: PluginCategory { .editor }

    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor lazy var buildContextProvider = XcodeBuildContextProvider(
        store: EditorSwiftBuildServerStore.makeStore()
    )
    @MainActor private lazy var projectContextCapability = XcodeProjectContextCapabilityAdapter()
    @MainActor private lazy var semanticCapability = XcodeSemanticCapabilityAdapter()
    @MainActor private lazy var languageIntegrationCapability = XcodeLanguageIntegrationCapabilityAdapter()

    @MainActor public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        if SwiftPluginLog.verbose {
            SwiftPluginLog.logger.info("\(self.t)开始注册编辑器扩展")
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

        XcodeProjectContextBridge.shared.registerBuildContextProvider(buildContextProvider)
        if let bundledTool = Bundle.module.url(forResource: "xcode-build-server", withExtension: nil, subdirectory: "Tools") {
            XcodeBuildServerLocator.bundledToolPath = bundledTool.path
        }
        EditorSwiftHostEnvironmentConfiguration.apply()
        if SwiftPluginLog.verbose {
            SwiftPluginLog.logger.info("\(self.t)已注册 buildContextProvider 到 Bridge")
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
            SwiftPluginLog.logger.info("\(self.t)编辑器扩展注册完成")
        }
    }


    @MainActor public func addRootView<Content: View>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(EditorSwiftPluginRootView(content: content()))
    }
}
