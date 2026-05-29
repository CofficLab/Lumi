import Foundation
import LumiCoreKit
import SuperLogKit
import SwiftUI
import XcodeKit
import AgentToolKit
import os

/// Xcode 插件日志辅助（插件内共享）
public enum XcodePluginLog {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.xcode")
    nonisolated(unsafe) static var verbose: Bool = false
}

/// Xcode 项目编辑器插件：提供 Xcode 项目标识、构建上下文和 sourcekit-lsp 集成
public actor EditorXcodePlugin: SuperPlugin, SuperLog {
    public nonisolated static let emoji = "🔧"

    public static let shared = EditorXcodePlugin()
    public static let id = "EditorXcode"
    public static let displayName = String(localized: "Xcode Project Editor", table: "EditorXcodePlugin")
    public static let description = String(localized: "Provides Xcode project identity, build context, and sourcekit-lsp integration for Swift projects.", table: "EditorXcodePlugin")
    public static let iconName = "xmark.app"
    public static let order = 4  // 在 LSP Service 之前加载，确保 build context 就绪
    public static var category: PluginCategory { .editor }

    public nonisolated var providesEditorExtensions: Bool { true }

    /// Build Context Provider 实例
    @MainActor lazy var buildContextProvider = XcodeBuildContextProvider(
        store: XcodeBuildServerStore(storageRootURL: AppConfig.getDBFolderURL())
    )
    @MainActor private lazy var projectContextCapability = XcodeProjectContextCapabilityAdapter()
    @MainActor private lazy var semanticCapability = XcodeSemanticCapabilityAdapter()
    @MainActor private lazy var languageIntegrationCapability = XcodeLanguageIntegrationCapabilityAdapter()

    @MainActor public func registerEditorExtensions(into registry: EditorExtensionRegistry) {
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

    /// 不再在工具栏/状态栏提供 UI

    /// 注册此插件暴露给 Agent 的工具。
    @MainActor public func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [AddSwiftPackageTool(), ListSwiftPackagesTool(), GenerateXcodeProjectTool()]
    }

    /// 添加根视图包裹器
    @MainActor public func addRootView<Content: View>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        return AnyView(EditorXcodePluginRootView(content: content()))
    }
}
