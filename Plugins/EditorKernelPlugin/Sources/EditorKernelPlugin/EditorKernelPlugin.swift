import EditorService
import Foundation
import SwiftUI
import LumiKernel
import LumiUI
import SuperLogKit
import os

/// Editor kernel plugin
///
/// Registers EditorCore with LumiKernel, bridging the editor subsystem
/// to the app's plugin and theme infrastructure.
@MainActor
public final class EditorKernelPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.editor")
    nonisolated public static let emoji = "\u{1F4DD}"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.editor"
    public let name = "Editor Plugin"
    public let order = 50
	public let policy: LumiPluginPolicy = .alwaysOn  // Core plugin

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func onBoot(kernel: LumiKernel) async throws {}

    public func onReady(kernel: LumiKernel) async throws {
        // Register the EditorService with an extension registry.
        // EditorService from the EditorService module doesn't conform to
        // EditorServiceProviding, so we use a thin adapter.
        let extensionRegistry = EditorExtensionRegistry()
        let editorService = EditorService(editorExtensionRegistry: extensionRegistry)
        let adapter = EditorServiceProvidingAdapter(wrapping: editorService)
        kernel.registerEditor(adapter)
        if Self.verbose {
            Self.logger.info("\(Self.t)Registered Editor service")
            Self.logger.info("\(Self.t)Editor plugin booted")
        }
    }


    // MARK: - LumiPlugin stubs

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
    public func workspaceVisibility(kernel: LumiKernel) -> WorkspaceVisibility { WorkspaceVisibility() }
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
}

/// Thin adapter that bridges EditorService (EditorService module) to EditorServiceProviding.
@MainActor
private final class EditorServiceProvidingAdapter: EditorServiceProviding {
    private let service: EditorService

    @Published var currentFilePath: String?
    @Published var currentThemeId: String = "xcode-dark"

    init(wrapping service: EditorService) {
        self.service = service
    }

    func openFile(at path: String) async throws {
        currentFilePath = path
    }

    func closeFile(at path: String) async {
        if currentFilePath == path {
            currentFilePath = nil
        }
    }

    func setCurrentTheme(_ themeId: String) throws {
        service.theme.syncInitialThemeFromExternal(themeId)
        currentThemeId = themeId
    }

    var allEditorThemes: [EditorThemeInfo] {
        []
    }

    func registerEditorTheme(_ theme: EditorThemeInfo) {}
    func unregisterEditorTheme(themeId: String) {}

    func editorSyntaxPalette(for themeId: String) -> EditorSyntaxPalette? {
        nil
    }

    // MARK: - Raw EditorService Access

    var rawEditorService: AnyObject? {
        service
    }
}
