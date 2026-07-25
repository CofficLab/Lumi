import Foundation
import LumiKernel
import LumiUI
import EditorService
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
    public let name = "Editor Provider Plugin"
    public let order = 1
    public let policy: LumiPluginPolicy = .alwaysOn

    // MARK: - State

    /// 持有 provider 实例,以便在 OnReady 阶段注入 EditorService。
    /// OnBoot 阶段创建并注册;此时 EditorService 可能尚未注册(EditorKernelPlugin 同为 order=1,无先后保证)。
    private var editorProvider: EditorProvider?

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {
        let provider = EditorProvider()
        editorProvider = provider
        try await EditorProviderOnBootHook().execute(provider, kernel: kernel)
    }

    public func onReady(kernel: LumiKernel) async throws {
        try EditorProviderOnReadyHook().execute(kernel)

        // OnReady 阶段所有 OnBoot 服务已注册完毕,此时 EditorService 必然就绪。
        // 把具象 EditorService 注入 provider,使其文件操作转发到真正的编辑器子系统。
        if let editorService = kernel.resolveService(EditorService.self) {
            editorProvider?.attachEditorService(editorService)
            if Self.verbose {
                Self.logger.info("\(Self.t)EditorProviderPlugin: attached EditorService to EditorProvider")
            }
        } else {
            Self.logger.warning("\(Self.t)EditorProviderPlugin: EditorService unavailable at onReady — openFile/closeFile will fall back to stub")
        }
    }

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func subAgents(kernel: LumiKernel) -> [LumiSubAgentDefinition] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func pluginAboutView(kernel: LumiKernel) -> AnyView? { nil }
    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
}

// MARK: - EditorProvider

@MainActor
public final class EditorProvider: EditorProviding {
    /// 注入的具象 EditorService(弱引用,避免循环)。
    /// 在 OnReady 阶段由 plugin 注入;在此之前文件操作走降级路径。
    private weak var editorService: EditorService?

    public var currentThemeId: String = "default"

    private var themes: [String: EditorThemeInfo] = [:]

    /// 降级用的本地缓存,仅在 EditorService 未注入时使用。
    private var stubCurrentFilePath: String?

    public var allEditorThemes: [EditorThemeInfo] {
        Array(themes.values)
    }

    /// 注入具象 EditorService,启用文件操作转发。
    func attachEditorService(_ service: EditorService) {
        editorService = service
    }

    public var currentFilePath: String? {
        if let url = editorService?.files.currentFileURL {
            return url.path
        }
        return stubCurrentFilePath
    }

    public func openFile(at path: String) async throws {
        if let service = editorService {
            let url = URL(fileURLWithPath: path)
            service.sessions.openFile(at: url)
            return
        }
        // 降级:EditorService 尚未注入时仅记录路径。
        stubCurrentFilePath = path
    }

    public func closeFile(at path: String) async {
        if let service = editorService {
            let url = URL(fileURLWithPath: path)
            // EditorService 目前没有按 URL 关闭单个 session 的公开 API;
            // 这里以"切到 nil"近似:若关闭的是当前文件,则清空当前 URL。
            if service.files.currentFileURL == url {
                service.sessions.openFile(at: nil)
            }
            return
        }
        if stubCurrentFilePath == path {
            stubCurrentFilePath = nil
        }
    }

    public func setCurrentTheme(_ themeId: String) throws {
        guard themes[themeId] != nil else {
            throw LumiKernelError.serviceNotAvailable(service: "Editor theme '\(themeId)' not found")
        }
        currentThemeId = themeId
    }

    public func registerEditorTheme(_ theme: EditorThemeInfo) {
        themes[theme.id] = theme
    }

    public func unregisterEditorTheme(themeId: String) {
        themes.removeValue(forKey: themeId)
    }
}
