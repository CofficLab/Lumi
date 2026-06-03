import Foundation
import EditorService
import LumiCoreKit
import SuperLogKit
import SwiftUI
import os

@MainActor
public enum GoEditorBridge {
    public static var openFileHandler: ((URL, String?) async -> Void)?
}

/// Go 编辑器插件
///
/// 提供 Go 项目支持：
/// - gopls 高级配置（staticcheck、codelenses、analyses）
/// - go.mod 项目检测
/// - go build / go test / go fmt / go mod tidy 命令
/// - 构建输出面板 + 测试结果面板
///
/// LSP 基础能力（补全/跳转/悬停/诊断）复用内核 LSPService，
/// 已内置支持 gopls。
public actor GoEditorPlugin: SuperPlugin, SuperLog {
    public nonisolated static let policy: PluginPolicy = .disabled
    public static let shared = GoEditorPlugin()
    public nonisolated static let emoji = "🐹"
    public nonisolated static let verbose: Bool = true
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.go-editor"
    )

    public static let id = "GoEditor"
    public static let displayName = String(localized: "Go Editor", table: "GoEditor")
    public static let description = String(localized: "Go language support: gopls integration, build, test, format, and module management.", table: "GoEditor")
    public static let iconName = "goforward"
    public static let order = 34
    public static var category: PluginCategory { .editor }

    public nonisolated var providesEditorExtensions: Bool { true }

    @MainActor public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        let buildManager = GoBuildManager()
        let testManager = GoTestManager()
        registry.registerLanguageIntegrationCapability(
            GoLanguageIntegrationCapability()
        )
        registry.registerCompletionContributor(
            GoCompletionContributor()
        )
        // TODO: 暂时停用 Editor 右键菜单命令
        // registry.registerCommandContributor(
        //     GoCommandContributor(buildManager: buildManager, testManager: testManager)
        // )
        registry.registerPanelContributor(
            GoPanelContributor(buildManager: buildManager, testManager: testManager)
        )
        registry.registerStatusItemContributor(
            GoStatusItemContributor(buildManager: buildManager, testManager: testManager)
        )
        registry.registerGutterDecorationContributor(GoTestGutterContributor())
    }
}
