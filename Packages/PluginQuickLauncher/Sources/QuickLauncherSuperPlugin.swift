import AppKit
import KernelCore
import ProviderCommand
import ProviderDocsView
import ProviderMessageSender
import ProviderSettingView
import SwiftUI
import os
import KitSuperLog

struct QuickLauncherPlugin {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "QuickLauncherPlugin")
}

/// KernelCore lifecycle for the Raycast-style global launcher.
///
/// It preserves the global hotkey, floating panel, persisted source switches,
/// command search, and `?` direct-send behavior from the legacy plugin.
@MainActor
public final class QuickLauncherSuperPlugin: SuperPlugin, SuperLog {
    public let id = "com.coffic.lumi.plugin.quick-launcher"
    public let order = 8
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.quick-launcher",
        name: "Quick Launcher",
        description: "Open apps, files and Lumi commands from a global hotkey.",
        category: .system,
        stage: .preview,
        policy: .alwaysOn
    )

    public init() {}

    public func onRegister(kernel: KernelCoreContainer) throws {
        let title = metadata.name
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: title) { QuickLauncherAboutView() })
            docs.addManual(DocsEntry(id: id, name: title) { QuickLauncherManualView() })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        FileSearchService.shared.configureGatheringObserverFactory { query, timeout in
            SpotlightGatheringObserver(query: query, timeout: timeout)
        }
        kernel.resolveProvider((any SettingViewProviding).self)?.addEntries([
            SettingEntryItem(
                id: id,
                title: LumiPluginLocalization.string("Quick Launcher", bundle: .module),
                systemImage: "bolt.fill",
                order: order
            ) {
                LauncherSettingsView()
            },
        ])

        let commands = kernel.resolveProvider((any CommandProviding).self)
        let sender = kernel.resolveProvider((any MessageSendingProviding).self)

        LauncherBridge.askAIHandler = { question in
            LauncherBridge.activateMainWindowHandler?()
            guard let sender else { return }
            Task { @MainActor in
                try? await sender.sendMessage(question, conversationID: nil)
            }
        }
        LauncherBridge.commandGroupsProvider = {
            (commands?.allCommandGroups ?? []).map { group in
                LauncherCommandGroup(
                    id: group.id,
                    name: group.name,
                    items: group.items.map { item in
                        LauncherCommandItem(id: item.id, title: item.title, action: item.action)
                    }
                )
            }
        }
        LauncherBridge.activateMainWindowHandler = {
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.mainWindow ?? NSApp.windows.first(where: { !$0.isKind(of: NSPanel.self) }) {
                window.makeKeyAndOrderFront(nil)
            }
        }

        GlobalHotkeyManager.shared.onToggle = { LauncherWindowController.shared.toggle() }
        GlobalHotkeyManager.shared.start()
        AppSearchService.shared.scanApplications()
    }

    public func onEnable(kernel: KernelCoreContainer) async throws {
        GlobalHotkeyManager.shared.start()
    }

    public func onDisable(kernel: KernelCoreContainer) async throws {
        GlobalHotkeyManager.shared.stop()
        LauncherWindowController.shared.hide()
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        FileSearchService.shared.cancelSearch()
        GlobalHotkeyManager.shared.stop()
        LauncherWindowController.shared.hide()
        LauncherBridge.askAIHandler = nil
        LauncherBridge.commandGroupsProvider = nil
        LauncherBridge.activateMainWindowHandler = nil
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any SettingViewProviding).self)?.removeEntries(ids: [id])
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }
}
