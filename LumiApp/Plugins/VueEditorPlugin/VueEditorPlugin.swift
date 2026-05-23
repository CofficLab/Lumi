import Foundation
import SwiftUI
import os

/// Vue 编辑器插件
///
/// 提供 Vue 单文件组件 (SFC) 的编辑增强功能：
/// - Vue 版本自动检测 (Vue 2 / Vue 3)
/// - Volar Language Server 集成 (通过内核 LSPService)
/// - Vue 模板指令补全 (v-if, v-for, v-model 等)
/// - Vue 指令与内置组件悬浮提示
/// - SFC 区块导航 (⌘+1/2/3 快速跳转)
/// - 项目组件扫描与自动导入补全
/// - Scoped CSS 深度选择器 (:deep, :slotted, :global) 补全
///
/// LSP 基础能力（补全/跳转/悬停/诊断）复用内核 LSPService，
/// 通过 Volar (vue-language-server) 提供完整 SFC 智能支持。
actor VueEditorPlugin: SuperPlugin, SuperLog {
    static let shared = VueEditorPlugin()
    nonisolated static let emoji = "💚"
    nonisolated static let verbose: Bool = false
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.vue-editor"
    )

    static let id = "VueEditor"
    static let displayName = String(localized: "Vue Editor", table: "VueEditor")
    static let description = String(localized: "Vue SFC editing support: Volar LSP integration, template directive completion, and component hover docs.", table: "VueEditor")
    static let iconName = "curlybraces"
    static let order = 35
    static let enable = true
    static var isConfigurable: Bool { false }
    static var category: PluginCategory { .editor }

    nonisolated var providesEditorExtensions: Bool { true }

    /// Vue 组件大纲视图模型
    @MainActor private var outlineViewModel: VueOutlineViewModel?

    @MainActor func registerEditorExtensions(into registry: EditorExtensionRegistry) {
        // 基础补全：Vue 指令、内置组件、宏、修饰符
        registry.registerCompletionContributor(VueCompletionContributor())

        // 模板指令上下文感知补全：v-for 片段、事件、修饰符、插槽
        registry.registerCompletionContributor(TemplateAttributeCompleter())

        // Script Setup 补全：宏、Composition API、生命周期钩子
        registry.registerCompletionContributor(ScriptSetupCompleter())

        // 悬浮提示：Vue 指令、组件、宏、Scoped CSS
        registry.registerHoverContributor(VueHoverContributor())

        // TODO: 暂时停用 Editor 右键菜单命令
        // registry.registerCommandContributor(VueCommandContributor())

        // 组件自动导入补全
        registry.registerCompletionContributor(VueComponentImportResolver())

        // TODO: 暂时停用 Editor 右键菜单命令
        // registry.registerCommandContributor(VueDevCommandContributor())

        // LSP 集成：Volar 配置注入（含健康检查和版本检测）
        registry.registerLanguageIntegrationCapability(
            VueLanguageIntegrationCapability()
        )
    }

    // MARK: - UI Contributions

    @MainActor func addRailTabs(activeIcon: String?) -> [RailTab] {
        guard activeIcon == Self.iconName else { return [] }
        return [
            RailTab(
                id: "vue-outline",
                title: String(localized: "Vue Outline", table: "VueEditor"),
                systemImage: "curlybraces",
                priority: 2
            )
        ]
    }

    @MainActor func addRailContentView(tabId: String, activeIcon: String?) -> AnyView? {
        guard tabId == "vue-outline", activeIcon == Self.iconName else { return nil }

        if outlineViewModel == nil {
            outlineViewModel = VueOutlineViewModel()
        }

        return AnyView(
            VueOutlineView(
                viewModel: outlineViewModel!,
                onNavigate: { line in
                    // 跳转到指定行 — 由编辑器内核处理
                    NotificationCenter.default.post(
                        name: .vueNavigateToLine,
                        object: nil,
                        userInfo: ["line": line]
                    )
                }
            )
        )
    }

    // MARK: - Lifecycle

    /// 在打开 Vue 项目时预扫描组件
    /// 应在 EditorState 检测到项目根路径变化时调用
    func precacheComponents(projectPath: String) {
        VueComponentImportResolver.precache(projectPath: projectPath)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Vue 区块导航通知（携带 line 参数）
    static let vueNavigateToLine = Notification.Name("com.coffic.lumi.vue.navigate-to-line")
}
