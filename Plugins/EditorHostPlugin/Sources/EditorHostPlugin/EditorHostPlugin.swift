import Combine
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
    private var projectObservation: AnyCancellable?
    private var projectSyncTask: Task<Void, Never>?
    private var lastSyncedProjectFilePath: String?

    public init() {}

    // MARK: - Lifecycle

    public func onBoot(kernel: KernelLumi) async throws {
        // 1. 编辑器子系统装配（原 EditorKernelPlugin OnBoot）。
        let registry = EditorExtensionRegistry()
        let service = EditorService(editorExtensionRegistry: registry)
        try kernel.registerService(EditorService.self, service)

        // 2. 文件树/标签栏协同器（同一实例实现两个协同协议）。
        let editorContext = EditorContext(service: service, kernel: kernel)
        try kernel.registerFileTreeEditorCoordination(editorContext)
        try kernel.registerEditorTabStripCoordination(editorContext)

        // 3. legacy EditorProviding 契约（PluginManager 编辑器插件装配、旧消费者）。
        //    同一插件内服务已就绪，构造即注入，无需 pending 回放。
        let provider = EditorProvider(service: service)
        try kernel.registerEditor(provider)

        // 4. 契约 V2（kernel.editorV2），Surface 视图工厂注入。
        let adapter = EditorProvidingV2Adapter(service: service)
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

        editorService = service
        editorProvider = provider

        if Self.verbose {
            Self.logger.info("\(Self.t)EditorHostPlugin: EditorService + legacy provider + V2 adapter registered")
        }
    }

    public func onReady(kernel: KernelLumi) async throws {
        // 主题同步（原 EditorProviderPlugin OnReady）：订阅 .themeDidChange 并应用编辑器主题。
        editorProvider?.bindThemeSync(kernel: kernel)

        // 项目当前文件联动（原 EditorProviderPlugin OnReady）：
        // 只订阅 project 的 objectWillChange（精确信号），project 变更驱动编辑器打开文件。
        bindProjectCurrentFileObservation(kernel: kernel)
        scheduleProjectCurrentFileSync(kernel: kernel)
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
    public func registerEditorExtensions(into registry: AnyObject, kernel: KernelLumi) async {}
    public func configureEditorRuntime(kernel: KernelLumi) async {}

    // MARK: - Project Sync

    private func bindProjectCurrentFileObservation(kernel: KernelLumi) {
        projectObservation?.cancel()
        projectObservation = nil

        guard let project = kernel.project else { return }

        projectObservation = project.objectWillChange.sink { [weak self] _ in
            self?.scheduleProjectCurrentFileSync(kernel: kernel)
        }
    }

    private func scheduleProjectCurrentFileSync(kernel: KernelLumi) {
        projectSyncTask?.cancel()
        projectSyncTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard !Task.isCancelled else { return }
            self?.syncProjectCurrentFile(kernel: kernel)
        }
    }

    private func syncProjectCurrentFile(kernel: KernelLumi) {
        guard let editorProvider else { return }

        let projectFilePath = kernel.project?.currentFileURL?.standardizedFileURL.path
        guard projectFilePath != lastSyncedProjectFilePath else { return }
        lastSyncedProjectFilePath = projectFilePath

        guard let projectFilePath else { return }

        let currentEditorPath = editorProvider.currentFilePath.map {
            URL(fileURLWithPath: $0).standardizedFileURL.path
        }
        guard currentEditorPath != projectFilePath else { return }

        Task { @MainActor in
            try? await editorProvider.openFile(at: projectFilePath)
        }
    }
}
