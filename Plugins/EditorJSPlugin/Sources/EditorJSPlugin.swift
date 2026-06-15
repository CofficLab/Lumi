import Foundation
import EditorService
import LumiCoreKit
import SuperLogKit
import ShellKit
import LumiUI
import SwiftUI
import os

/// JavaScript / TypeScript 编辑器插件
///
/// 提供 JS/TS 项目支持：
/// - package.json 解析与脚本识别
/// - tsconfig 路径映射
/// - Node/Bun 运行时探测
/// - 统一脚本执行桥接
///
/// LSP 能力（补全/跳转/悬停/诊断）复用内核 LSPService，
/// 已内置支持 typescript-language-server。
public actor EditorJSPlugin: SuperPlugin, SuperLog {
    public nonisolated static let policy: PluginPolicy = .disabled
    public static let shared = EditorJSPlugin()
    public nonisolated static let emoji = "🟨"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.js-editor"
    )

    public static let id = "JSEditor"
    public static let displayName = LumiPluginLocalization.string("JS/TS Editor", bundle: .module)
    public static let description = LumiPluginLocalization.string("JavaScript and TypeScript project support: package.json parsing, tsconfig resolution, and script execution.", bundle: .module)
    public static let iconName = "js"
    public static let order = 33
    public static var category: PluginCategory { .editor }

    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor
    public func configureRuntime(context: PluginRuntimeContext) {
        JSEditorBridge.openFileHandler = { url, projectRoot in
            await context.openFile(url, projectRoot, PluginContext())
        }
    }

    @MainActor public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerLanguage(EditorJSPluginDescriptor.javascript)
        registry.registerLanguage(EditorJSPluginDescriptor.typescript)
        registry.registerLanguage(EditorJSPluginDescriptor.jsx)
        registry.registerLanguage(EditorJSPluginDescriptor.tsx)
        registry.registerLanguage(EditorJSPluginDescriptor.jsdoc)
        registry.registerGrammarProvider(EditorJSJavaScriptGrammarProvider())
        registry.registerGrammarProvider(EditorJSXGrammarProvider())
        registry.registerGrammarProvider(EditorJSTypeScriptGrammarProvider())
        registry.registerGrammarProvider(EditorJSTsxGrammarProvider())
        registry.registerGrammarProvider(EditorJSJSDocGrammarProvider())

        let taskManager = JSTaskManager()
        registry.registerLanguageIntegrationCapability(JSLanguageIntegrationCapability())
        
        // 注册 JavaScript/TypeScript LSP 服务器
        if let tsServerPath = Shell.findCommandSync("typescript-language-server") {
            LSPConfig.registerServerConfig(
                for: "javascript",
                config: LSPConfig.ServerConfig(
                    languageId: "javascript",
                    execPath: tsServerPath,
                    arguments: ["--stdio"]
                )
            )
            LSPConfig.registerServerConfig(
                for: "typescript",
                config: LSPConfig.ServerConfig(
                    languageId: "typescript",
                    execPath: tsServerPath,
                    arguments: ["--stdio"]
                )
            )
        }
        
        // TODO: 暂时停用 Editor 右键菜单命令
        // registry.registerCommandContributor(JSCommandContributor(taskManager: taskManager))
        registry.registerPanelContributor(JSPanelContributor(taskManager: taskManager))
        registry.registerStatusItemContributor(JSStatusItemContributor(taskManager: taskManager))
        registry.registerGutterDecorationContributor(JSTestGutterContributor())
    }
}
