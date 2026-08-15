import AppKit
import KernelLumi
import SuperLogKit
import LumiUI
import os
import SwiftUI

/// Quick Launcher 插件
///
/// Raycast 风格全局启动器：
/// - 系统级全局热键（默认 ⌥Space，可自定义）
/// - 独立悬浮搜索窗口（跨 Space）
/// - 聚合搜索：应用 / 文件（Spotlight）/ Lumi 命令 / `?` 前缀询问 AI
@MainActor
public final class QuickLauncherPlugin: LumiPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.quicklauncher")
    public nonisolated static let emoji = "🚀"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.quick-launcher"
    public var name: String {
        LumiPluginLocalization.string("Quick Launcher", bundle: .module)
    }
    public let order = 8
    public let policy: LumiPluginPolicy = .alwaysOn
    public let stage: LumiPluginStage = .beta

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func onBoot(kernel: KernelLumi) async throws {}

    public func onReady(kernel: KernelLumi) async throws {
        // 注入内核桥：AI 问答（激活主窗口 + 发送到会话）
        LauncherBridge.askAIHandler = { [weak kernel] question in
            Task { @MainActor in
                guard let kernel else { return }
                LauncherBridge.activateMainWindowHandler?()
                guard let chat = kernel.resolveService((any LumiChatServicing).self) else {
                    Self.logger.error("LumiChatServicing 未注册，无法发送 AI 问答")
                    return
                }
                let conversationID: UUID
                if let selected = chat.selectedConversationID {
                    conversationID = selected
                } else {
                    conversationID = chat.createConversation(title: nil)
                }
                await chat.send(question, in: conversationID)
            }
        }

        // 注入内核桥：命令组（来自 CommandProviding）
        LauncherBridge.commandGroupsProvider = { [weak kernel] in
            kernel?.command?.allCommandGroups ?? []
        }

        // 注入内核桥：激活主窗口
        LauncherBridge.activateMainWindowHandler = {
            NSApp.activate(ignoringOtherApps: true)
            if let mainWindow = NSApp.mainWindow ?? NSApp.windows.first(where: { !$0.isKind(of: NSPanel.self) }) {
                mainWindow.makeKeyAndOrderFront(nil)
            }
        }

        // 启动全局热键：toggle 悬浮窗口
        let hotkeyManager = GlobalHotkeyManager.shared
        hotkeyManager.onToggle = {
            LauncherWindowController.shared.toggle()
        }
        hotkeyManager.start()

        // 预热应用扫描（后台，带 mtime 缓存）
        AppSearchService.shared.scanApplications()

        if Self.verbose {
            Self.logger.info("\(Self.t)QuickLauncher 已就绪，热键: \(hotkeyManager.currentCombo.displayString)")
        }
    }

    // MARK: - Lifecycle

    public func onEnable(kernel: KernelLumi) async throws {
        GlobalHotkeyManager.shared.start()
    }

    public func onDisable(kernel: KernelLumi) async throws {
        GlobalHotkeyManager.shared.stop()
        LauncherWindowController.shared.hide()
    }

    // MARK: - Settings

    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] {
        [
            SettingsTabItem(
                id: id,
                title: LumiPluginLocalization.string("Quick Launcher", bundle: .module),
                systemImage: "bolt.fill",
                order: order
            ) {
                LauncherSettingsView()
            },
        ]
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
}
