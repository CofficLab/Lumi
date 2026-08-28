import KernelCore
import ProviderDocsView
import ProviderLLMManager
import ProviderSettingView
import KitSuperLog
import os

/// KernelCore lifecycle for the global selected-text action menu.
@MainActor
public final class TextActionsSuperPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.text-actions", category: "TextActions")
    public let id = "com.coffic.lumi.plugin.text-actions"
    public let order = 275
    public let metadata = PluginMetadata(id: "com.coffic.lumi.plugin.text-actions", name: "Text Actions", description: "Show copy, search, and translation actions for selected text in other macOS apps.", category: .system, stage: .preview, policy: .disabledByDefault)
    public init() {}

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: metadata.name) { TextActionsAboutView() })
            docs.addManual(DocsEntry(id: id, name: metadata.name) { TextActionsManualView() })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        if let llm = kernel.resolveProvider((any LLMManaging).self) { TextActionMenuController.shared.configure(translationProvider: llm) }
        kernel.resolveProvider((any SettingViewProviding).self)?.addEntries([SettingEntryItem(id: id, title: metadata.name, systemImage: "text.cursor", order: order) { TextActionsSettingsView() }])
    }

    public func onEnable(kernel: KernelCoreContainer) async throws {
        if TextActionsSettings.isEnabled { TextSelectionManager.shared.startMonitoring() }
    }

    public func onDisable(kernel: KernelCoreContainer) async throws {
        TextSelectionManager.shared.stopMonitoring()
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        TextSelectionManager.shared.stopMonitoring()
        TextActionMenuController.shared.hide()
        kernel.resolveProvider((any SettingViewProviding).self)?.removeEntries(ids: [id])
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }
}
