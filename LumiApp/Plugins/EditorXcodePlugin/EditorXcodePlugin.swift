import Foundation
import SwiftUI

/// Xcode 项目编辑器插件：提供 Xcode 项目标识、构建上下文和 sourcekit-lsp 集成
actor EditorXcodePlugin: SuperPlugin {
    static let id = "EditorXcode"
    static let displayName = String(localized: "Xcode Project Editor", table: "EditorXcodePlugin")
    static let description = String(localized: "Provides Xcode project identity, build context, and sourcekit-lsp integration for Swift projects.", table: "EditorXcodePlugin")
    static let iconName = "xmark.app"
    static let order = 4  // 在 LSP Service 之前加载，确保 build context 就绪
    static let enable = true
    static var isConfigurable: Bool { false }

    nonisolated var providesEditorExtensions: Bool { true }

    /// Build Context Provider 实例
    ///
    /// 使用 lazy var 而非 let 初始化，因为 Actor 通过 ObjC Runtime 的 alloc/init 创建时，
    /// init() 不在 @MainActor 上运行，会导致 @MainActor 的 ObservableObject 在错误线程初始化，
    /// 后续在主线程访问 @Published 属性时触发 EXC_BAD_ACCESS。
    /// lazy var 确保在首次 @MainActor 上下文访问时才初始化。
    @MainActor lazy var buildContextProvider = XcodeBuildContextProvider()
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
    
    /// 添加根视图包裹器
    ///
    /// 在应用启动时预加载最近 Xcode 项目的 buildServer.json，
    /// 减少首次打开项目时的等待时间。
    @MainActor func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        return AnyView(EditorXcodePluginRootView(content: content()))
    }
}