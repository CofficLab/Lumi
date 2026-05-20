import Foundation
import SwiftUI
import MagicKit
import os

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
actor GoEditorPlugin: SuperPlugin, SuperLog {
    static let shared = GoEditorPlugin()
    nonisolated static let emoji = "🐹"
    nonisolated static let verbose: Bool = false
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.go-editor"
    )

    static let id = "GoEditor"
    static let displayName = String(localized: "Go Editor", table: "GoEditor")
    static let description = String(localized: "Go language support: gopls integration, build, test, format, and module management.", table: "GoEditor")
    static let iconName = "goforward"
    static let order = 34
    static let enable = true
    static var isConfigurable: Bool { false }

    nonisolated var providesEditorExtensions: Bool { true }

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        let buildManager = GoBuildManager()
        let testManager = GoTestManager()
        registry.registerLanguageIntegrationCapability(
            GoLanguageIntegrationCapability()
        )
        registry.registerCompletionContributor(
            GoCompletionContributor()
        )
        registry.registerCommandContributor(
            GoCommandContributor(buildManager: buildManager, testManager: testManager)
        )
        registry.registerPanelContributor(
            GoPanelContributor(buildManager: buildManager, testManager: testManager)
        )
        registry.registerStatusItemContributor(
            GoStatusItemContributor(buildManager: buildManager, testManager: testManager)
        )
        registry.registerGutterDecorationContributor(GoTestGutterContributor())
    }
}
