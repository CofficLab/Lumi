import Foundation
import SwiftUI
import LumiKernel
import SuperLogKit
import os

/// Conversation Store Plugin
///
/// Implements ConversationManaging protocol with SwiftData persistence.
@MainActor
public final class ConversationStorePlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-store")
    nonisolated public static let emoji = "💬"
    public static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.conversation-store"
    public let name = "Conversation Store"
    public let order = 61
    public let policy: LumiPluginPolicy = .alwaysOn

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func onBoot(kernel: LumiKernel) async throws {}

    public func onReady(kernel: LumiKernel) async throws {
        let manager = ConversationManager(kernel: kernel)
        kernel.registerConversations(manager)

        // Register initial (empty) state - will be loaded properly in boot()
        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 ConversationManager")
        }

        // Initialize ConversationStore with proper database root URL
        let databaseRootURL: URL
        let dataDirectory: URL

        if let storage = kernel.storage {
            databaseRootURL = storage.dataRootDirectory
            dataDirectory = storage.dataRootDirectory
        } else {
            databaseRootURL = ConversationStore.defaultDatabaseRootURL
            dataDirectory = ConversationStore.defaultDatabaseRootURL
        }

        do {
            let store = try ConversationStore(databaseRootURL: databaseRootURL)
            ConversationManagerRuntimeBridge.shared.store = store
            ConversationManagerRuntimeBridge.shared.dataDirectory = dataDirectory

            // Load conversations into the manager
            if let manager = kernel.conversations as? ConversationManager {
                manager.loadConversations()
            }

            if Self.verbose {
                Self.logger.info("\(Self.t)ConversationStorePlugin 启动完成，数据库路径: \(databaseRootURL.path)")
            }
        } catch {
            throw ConversationStoreError.initializationFailed("ConversationStorePlugin 数据库初始化失败: \(error.localizedDescription)")
        }
    }

    public func boot(kernel: LumiKernel) async throws {}

    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func subAgents(kernel: LumiKernel) -> [LumiSubAgentDefinition] { [] }
    public func sendMiddlewares(kernel: LumiKernel) -> [any LumiSendMiddleware] { [] }
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
