import Combine
import EditorService
import Foundation
import KernelLumi
import LumiUI
import os
import SuperLogKit
import SwiftUI

/// Editor Provider Plugin
///
/// Provides default implementation of EditorProviding for LumiCore.
/// Handles file operations and editor theme management.
@MainActor
public final class EditorProviderPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.editor-provider")
    public nonisolated static let emoji = "📝"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.editor-provider"
    public var name: String {
        LumiPluginLocalization.string("Editor Provider Plugin", bundle: .module)
    }
    public let order = 1
    public let policy: LumiPluginPolicy = .alwaysOn
    public let stage: LumiPluginStage = .beta

    // MARK: - State

    /// 持有 provider 实例,以便在 OnReady 阶段注入 EditorService。
    /// OnBoot 阶段创建并注册;此时 EditorService 可能尚未注册(EditorKernelPlugin 同为 order=1,无先后保证)。
    private var editorProvider: EditorProvider?
    private var projectObservation: AnyCancellable?
    private var projectSyncTask: Task<Void, Never>?
    private var lastSyncedProjectFilePath: String?

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {
        let provider = EditorProvider()
        editorProvider = provider
        try await EditorProviderOnBootHook().execute(provider, kernel: kernel)
    }

    public func onReady(kernel: KernelLumi) async throws {
        try EditorProviderOnReadyHook().execute(kernel)

        // Subscribe to theme-change events and apply the matching editor theme.
        // ThemeManager never references the editor directly; it only broadcasts
        // `.themeDidChange`, and we react here by resolving + applying the editor theme.
        editorProvider?.bindThemeSync(kernel: kernel)

        // OnReady 阶段所有 OnBoot 服务已注册完毕,此时 EditorService 必然就绪。
        // 把具象 EditorService 注入 provider,使其文件操作转发到真正的编辑器子系统。
        if let editorService = kernel.resolveService(EditorService.self) {
            editorProvider?.attachEditorService(editorService)
            if Self.verbose {
                Self.logger.info("\(Self.t)EditorProviderPlugin: attached EditorService to EditorProvider")
            }
            // 只订阅 project 的 objectWillChange（精确信号）。
            // 不再额外订阅 kernel.objectWillChange：它是转发所有 service 变更的全局总线，
            // project 的变更会作为其子集被转发，订阅两者只会带来重复触发与噪声。
            bindProjectCurrentFileObservation(kernel: kernel)
            scheduleProjectCurrentFileSync(kernel: kernel)
        } else {
            Self.logger.warning("\(Self.t)EditorProviderPlugin: EditorService unavailable at onReady — openFile/closeFile will fall back to stub")
        }
    }

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
