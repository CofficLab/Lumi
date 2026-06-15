import LumiCoreKit
import SuperLogKit
import Foundation
import EditorService
import LumiUI
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
public actor EditorVuePlugin: SuperPlugin, SuperLog {
    public nonisolated static let policy: PluginPolicy = .disabled
    public static let shared = EditorVuePlugin()
    public nonisolated static let emoji = "💚"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.vue-editor"
    )

    public static let id = "VueEditor"
    public static let displayName = LumiPluginLocalization.string("Vue Editor", bundle: .module)
    public static let description = LumiPluginLocalization.string("Vue SFC editing support: Volar LSP integration, template directive completion, and component hover docs.", bundle: .module)
    public static let iconName = "curlybraces"
    public static let order = 35
    public static var category: PluginCategory { .editor }

    public nonisolated var providesEditorExtensions: Bool { true }

    /// Vue 组件大纲视图模型
    @MainActor private var outlineViewModel: VueOutlineViewModel?

    @MainActor public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerLanguage(EditorVuePluginDescriptor.descriptor)

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

        registry.registerRailOutlineProvider(
            languageId: "vue",
            tabID: "vue-outline",
            title: LumiPluginLocalization.string("Vue", bundle: .module),
            systemImage: "curlybraces"
        ) { [weak self] in
            guard let self else { return AnyView(Color.clear) }
            return self.makeOutlineRailViewPrivate()
        }
    }

    // MARK: - UI Contributions

    @MainActor public func addRailItems(context: PluginContext) -> [RailItem] {
        guard context.activeIcon == Self.iconName else { return [] }
        return [
            RailItem(
                id: "vue-outline",
                title: LumiPluginLocalization.string("Vue Outline", bundle: .module),
                systemImage: "curlybraces",
                priority: 2,
                makeView: { [weak self] in
                    guard let self else { return AnyView(Color.clear) }
                    return self.makeOutlineRailViewPrivate()
                }
            )
        ]
    }

    @MainActor public func makeOutlineRailView() -> AnyView {
        makeOutlineRailViewPrivate()
    }

    @MainActor private func makeOutlineRailViewPrivate() -> AnyView {
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
    public func precacheComponents(projectPath: String) {
        VueComponentImportResolver.precache(projectPath: projectPath)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Vue 区块导航通知（携带 line 参数）
    public static let vueNavigateToLine = Notification.Name("com.coffic.lumi.vue.navigate-to-line")
}
