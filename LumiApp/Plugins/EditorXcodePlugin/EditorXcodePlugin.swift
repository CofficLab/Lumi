import Foundation
import SwiftUI
import XcodeKit
import MagicKit
import os

/// Xcode 插件日志辅助（插件内共享）
enum XcodePluginLog {
    static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.xcode")
    nonisolated(unsafe) static var verbose: Bool = false
}

/// Xcode 项目编辑器插件：提供 Xcode 项目标识、构建上下文和 sourcekit-lsp 集成
actor EditorXcodePlugin: SuperPlugin, SuperLog {
    nonisolated static let emoji = "🔧"

    static let shared = EditorXcodePlugin()
    static let id = "EditorXcode"
    static let displayName = String(localized: "Xcode Project Editor", table: "EditorXcodePlugin")
    static let description = String(localized: "Provides Xcode project identity, build context, and sourcekit-lsp integration for Swift projects.", table: "EditorXcodePlugin")
    static let iconName = "xmark.app"
    static let order = 4  // 在 LSP Service 之前加载，确保 build context 就绪
    static let enable = true
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
        if XcodePluginLog.verbose {
            if XcodePluginLog.verbose {
                            XcodePluginLog.logger.info("\(self.t)开始注册编辑器扩展")
            }
        }
        
        // 向 Bridge 注册 buildContextProvider，让 LSPService 能读取 build context
        XcodeProjectContextBridge.shared.registerBuildContextProvider(buildContextProvider)
        if XcodePluginLog.verbose {
            if XcodePluginLog.verbose {
                            XcodePluginLog.logger.info("\(self.t)已注册 buildContextProvider 到 Bridge")
            }
        }
        
        registry.registerCompletionContributor(XcodePlistCompletionContributor())
        if XcodePluginLog.verbose {
            if XcodePluginLog.verbose {
                            XcodePluginLog.logger.info("\(self.t)已注册 XcodePlistCompletionContributor")
            }
        }
        
        registry.registerHoverContributor(XcodePlistHoverContributor())
        if XcodePluginLog.verbose {
            if XcodePluginLog.verbose {
                            XcodePluginLog.logger.info("\(self.t)已注册 XcodePlistHoverContributor")
            }
        }
        
        registry.registerHoverContributor(XcodePackageManifestHoverContributor())
        if XcodePluginLog.verbose {
            if XcodePluginLog.verbose {
                            XcodePluginLog.logger.info("\(self.t)已注册 XcodePackageManifestHoverContributor")
            }
        }
        
        registry.registerQuickOpenContributor(XcodeProjectQuickOpenContributor())
        if XcodePluginLog.verbose {
            if XcodePluginLog.verbose {
                            XcodePluginLog.logger.info("\(self.t)已注册 XcodeProjectQuickOpenContributor")
            }
        }
        
        registry.registerProjectContextCapability(projectContextCapability)
        if XcodePluginLog.verbose {
            if XcodePluginLog.verbose {
                            XcodePluginLog.logger.info("\(self.t)已注册 projectContextCapability")
            }
        }
        
        registry.registerSemanticCapability(semanticCapability)
        if XcodePluginLog.verbose {
            if XcodePluginLog.verbose {
                            XcodePluginLog.logger.info("\(self.t)已注册 semanticCapability")
            }
        }
        
        registry.registerLanguageIntegrationCapability(languageIntegrationCapability)
        if XcodePluginLog.verbose {
            if XcodePluginLog.verbose {
                            XcodePluginLog.logger.info("\(self.t)已注册 languageIntegrationCapability")
            }
        }
        
        if XcodePluginLog.verbose {
            if XcodePluginLog.verbose {
                            XcodePluginLog.logger.info("\(self.t)编辑器扩展注册完成")
            }
        }
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
