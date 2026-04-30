import Foundation
import SwiftUI

/// Xcode 项目编辑器插件：提供 Xcode 项目标识、构建上下文和 sourcekit-lsp 集成
actor XcodeProjectEditorPlugin: SuperPlugin {
    static let id = "XcodeProjectEditor"
    static let displayName = String(localized: "Xcode Project Editor", table: "XcodeProjectEditor")
    static let description = String(localized: "Provides Xcode project identity, build context, and sourcekit-lsp integration for Swift projects.", table: "XcodeProjectEditor")
    static let iconName = "xmark.app"
    static let order = 4  // 在 LSP Service 之前加载，确保 build context 就绪
    static let enable = true
    static var isConfigurable: Bool { true }

    nonisolated var providesEditorExtensions: Bool { true }

    /// Build Context Provider 实例
    @MainActor let buildContextProvider = XcodeBuildContextProvider()
    @MainActor private let projectContextCapability = XcodeProjectContextCapabilityAdapter()
    @MainActor private let semanticCapability = XcodeSemanticCapabilityAdapter()
    @MainActor private let languageIntegrationCapability = XcodeLanguageIntegrationCapabilityAdapter()

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        // 向 Bridge 注册 buildContextProvider，让 LSPService 能读取 build context
        XcodeProjectContextBridge.shared.registerBuildContextProvider(buildContextProvider)
        registry.registerCompletionContributor(XcodePlistCompletionContributor())
        registry.registerHoverContributor(XcodePlistHoverContributor())
        registry.registerHoverContributor(XcodePackageManifestHoverContributor())
        registry.registerQuickOpenContributor(XcodeProjectQuickOpenContributor())
    }
    
    /// 在工具栏显示 Xcode 项目状态
    @MainActor func addToolBarLeadingView() -> AnyView? {
        return AnyView(XcodeProjectStatusBar())
    }

    @MainActor func editorProjectContextCapability() -> (any SuperEditorProjectContextCapability)? {
        projectContextCapability
    }

    @MainActor func editorSemanticCapability() -> (any SuperEditorSemanticCapability)? {
        semanticCapability
    }

    @MainActor func editorLanguageIntegrationCapabilities() -> [any SuperEditorLanguageIntegrationCapability] {
        [languageIntegrationCapability]
    }
}
