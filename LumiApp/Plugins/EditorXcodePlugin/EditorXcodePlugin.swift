import Foundation
import SwiftUI
import XcodeKit
import os

/// Xcode 插件日志辅助（插件内共享）
enum XcodePluginLog {
    static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.xcode")
    nonisolated(unsafe) static var verbose = false
}

/// Xcode 项目编辑器插件：提供 Xcode 项目标识、构建上下文和 sourcekit-lsp 集成
actor EditorXcodePlugin: SuperPlugin {
    static let shared = EditorXcodePlugin()
    static let id = "EditorXcode"
    static let displayName = String(localized: "Xcode Project Editor", table: "EditorXcodePlugin")
    static let description = String(localized: "Provides Xcode project identity, build context, and sourcekit-lsp integration for Swift projects.", table: "EditorXcodePlugin")
    static let iconName = "xmark.app"
    static let order = 4  // 在 LSP Service 之前加载，确保 build context 就绪
    static let enable = false
    static var isConfigurable: Bool { false }

    nonisolated var providesEditorExtensions: Bool { true }

    /// Build Context Provider 实例
    @MainActor lazy var buildContextProvider = XcodeBuildContextProvider(
        store: XcodeBuildServerStore(storageRootURL: AppConfig.getDBFolderURL())
    )
    @MainActor private lazy var projectContextCapability = XcodeProjectContextCapabilityAdapter()
    @MainActor private lazy var semanticCapability = XcodeSemanticCapabilityAdapter()
    @MainActor private lazy var languageIntegrationCapability = XcodeLanguageIntegrationCapabilityAdapter()

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        // 向 Bridge 注册 buildContextProvider，让 LSPService 能读取 build context
        XcodeProjectContextBridge.shared.registerBuildContextProvider(buildContextProvider)
        registry.registerCompletionContributor(XcodePlistCompletionContributor())
        registry.registerHoverContributor(XcodePlistHoverContributor())
        registry.registerHoverContributor(XcodePackageManifestHoverContributor())
        registry.registerQuickOpenContributor(XcodeProjectQuickOpenContributor())
        registry.registerProjectContextCapability(projectContextCapability)
        registry.registerSemanticCapability(semanticCapability)
        registry.registerLanguageIntegrationCapability(languageIntegrationCapability)
    }

    /// 在工具栏显示 Xcode 项目状态
    @MainActor func addToolBarLeadingView(activeIcon: String?) -> AnyView? {
        // 只在编辑器图标激活时显示 Xcode 项目状态栏
        guard activeIcon == EditorPlugin.iconName else { return nil }
        return AnyView(XcodeProjectStatusBar())
    }

    /// 在状态栏右侧显示 Xcode 构建上下文状态
    @MainActor func addStatusBarTrailingView(activeIcon: String?) -> AnyView? {
        AnyView(XcodeStatusBarTrailingView())
    }

    /// 添加根视图包裹器
    @MainActor func addRootView<Content: View>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        return AnyView(EditorXcodePluginRootView(content: content()))
    }
}
