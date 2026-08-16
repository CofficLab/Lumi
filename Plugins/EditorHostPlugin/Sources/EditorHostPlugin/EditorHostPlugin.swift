import EditorService
import Foundation
import KernelLumi
import os
import SuperLogKit
import SwiftUI

/// 编辑器宿主插件（Editor Host）
///
/// 合并自 `EditorKernelPlugin`（创建/注册 `EditorService` 与协同器）与
/// `EditorProviderPlugin`（legacy `EditorProviding` 契约、主题同步、项目当前文件联动），
/// 见 `docs/editor-kernel-plugin-rearchitecture-plan.md` §18 / §20 Phase 2。
///
/// 本插件是**唯一**持有 `EditorService` 的插件，在 OnBoot 一次性完成：
/// 1. 创建 `EditorExtensionRegistry` + `EditorService`，以具象类型注册到内核。
/// 2. 注册 `EditorContext`（文件树/标签栏协同）。
/// 3. 创建 legacy `EditorProvider` 并注入服务（同一插件内同步装配，
///    不再存在跨插件启动顺序约束、pending plugin 与弱引用兜底）。
/// 4. 创建 `EditorProvidingV2Adapter`（契约 V2），注入 Surface 视图工厂并注册 `kernel.editorV2`。
@MainActor
public final class EditorHostPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.editor-host")
    public nonisolated static let emoji = "🧩"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.editor-host"
    public var name: String {
        LumiPluginLocalization.string("Editor Host Plugin", bundle: .module)
    }
    public let order = 1
    public let policy: LumiPluginPolicy = .alwaysOn // 核心基础设施
    public let stage: LumiPluginStage = .beta

    // MARK: - State

    private var editorProvider: EditorProvider?
    private var editorService: EditorService?
    private var embeddedEditorProvider: EmbeddedEditorSurfaceProvider?

    public init() {}

    // MARK: - Lifecycle

    public func onBoot(kernel: KernelLumi) async throws {
        // 1. 编辑器子系统装配（原 EditorKernelPlugin OnBoot）。
        let registry = EditorExtensionRegistry()
        let service = EditorService(editorExtensionRegistry: registry)
        try kernel.registerService(EditorService.self, service)

        // 3.5 贡献包注册表（契约 V2 §9）：编辑器贡献按插件维度原子安装/撤回。
        let contributionRegistry = EditorContributionRegistry(registry: service.editorExtensions)

        // 3. legacy EditorProviding 契约（旧消费者）。
        //    同一插件内服务已就绪，构造即注入，无需 pending 回放。
        let provider = EditorProvider(service: service)
        try kernel.registerEditor(provider)

        // 4. 契约 V2（kernel.editorV2），Surface 视图工厂注入。
        let adapter = EditorProvidingV2Adapter(service: service, extensions: contributionRegistry)
        adapter.surfaceBox.makeView = { [weak service] in
            guard let service else {
                return AnyView(
                    Text("Editor service unavailable")
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                )
            }
            return AnyView(EditorSurfaceView(state: service.state))
        }
        try kernel.registerEditorV2(adapter)

        // 4.5 嵌入式编辑器能力（§17.2）：供 Feature 插件在自身面板内
        //     使用同一语言/语法高亮栈，而不依赖 EditorService/EditorSource。
        let embeddedProvider = EmbeddedEditorSurfaceProvider(service: service)
        try kernel.registerService(EditorEmbeddedEditorProviding.self, embeddedProvider)

        editorService = service
        editorProvider = provider
        embeddedEditorProvider = embeddedProvider

        if Self.verbose {
            Self.logger.info("\(Self.t)EditorHostPlugin: EditorService + legacy provider + V2 adapter registered")
        }
    }

    public func onReady(kernel: KernelLumi) async throws {
        // 主题同步（原 EditorProviderPlugin OnReady）：订阅 .themeDidChange 并应用编辑器主题。
        editorProvider?.bindThemeSync(kernel: kernel)
    }

    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func pluginAboutView(kernel: KernelLumi) -> AnyView? { nil }
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}

}
