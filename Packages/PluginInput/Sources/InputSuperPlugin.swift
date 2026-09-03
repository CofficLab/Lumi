import KernelCore
import ProviderActivityBar
import ProviderToolbar
import ProviderChatSection
import ProviderContentView
import ProviderDocsView
import ProviderStorage
import ProviderRailView
import ProviderRootView
import SwiftUI
import KitSuperLog
import os

enum InputPluginRuntimeBridge {
    nonisolated(unsafe) static var dataRootDirectory: URL?
    static var fallbackRootDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
    }
}

@MainActor
public final class InputSuperPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.input-manager", category: "Input")
    public let id = "com.coffic.lumi.plugin.input-manager"
    public let order = 70
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.input-manager",
        name: LumiPluginLocalization.string("Input Manager", bundle: .module),
        description: LumiPluginLocalization.string("Configure input methods and their behavior.", bundle: .module),
        category: .system,
        stage: .preview,
        policy: .disabledByDefault
    )

    private let activityItemID = "com.coffic.lumi.plugin.input-manager.entry"
    private var eventObserver: InputEventObserver?
    private var settingsObserver: InputSettingsObserver?
    private var viewModel: InputSettingsViewModel?

    public init() {}

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: metadata.name) { InputAboutView() })
            docs.addManual(DocsEntry(id: id, name: metadata.name) { InputManualView() })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        let inputService = InputService.shared
        let viewModel = InputSettingsViewModel()
        self.viewModel = viewModel
        settingsObserver = InputSettingsObserver(viewModel: viewModel, service: inputService)
        eventObserver?.cancel()
        eventObserver = InputEventObserver(
            onApplicationActivation: { [weak inputService] app in
                inputService?.handleAppActivation(app)
            },
            onInputSourceChange: { [weak inputService] in
                inputService?.handleInputSourceChange()
            }
        )
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            InputPluginRuntimeBridge.dataRootDirectory = storage.dataRootDirectory
        }

        let content = kernel.resolveProvider((any ContentViewProviding).self)
        let chat = kernel.resolveProvider((any ChatSectionProviding).self)
        let railView = kernel.resolveProvider((any RailViewProviding).self)
        let rootView = kernel.resolveProvider((any RootViewProviding).self)
        let toolbar = kernel.resolveProvider((any ToolbarProviding).self)
        if let activityBar = kernel.resolveProvider((any ActivityBarProviding).self) {
            activityBar.addItems([
                ActivityBarItem(
                    id: activityItemID,
                    title: metadata.name,
                    systemImage: "keyboard",
                    order: order,
                    ownerPluginID: id
                ) { state in
                    if state == .activated {
                        toolbar?.setVisibleCategories([.global, .system])
                        content?.setContentView(AnyView(InputSettingsView(viewModel: viewModel)))
                        chat?.setVisible(false)
                        rootView?.setRailView(nil)
                        rootView?.setContentHeaderViewHidden(true)
                    } else {
                        toolbar?.setVisibleCategories(Set(ToolbarItemCategory.allCases))
                        chat?.setVisible(true)
                        rootView?.setRailView(railView?.makeRailView())
                        rootView?.setContentHeaderViewHidden(false)
                    }
                },
            ])
        } else {
            content?.setContentView(AnyView(InputSettingsView(viewModel: viewModel)))
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        eventObserver?.cancel()
        eventObserver = nil
        settingsObserver?.cancel()
        settingsObserver = nil
        viewModel = nil
        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        let wasActive = activityBar?.activeItemID == activityItemID
        activityBar?.removeItems(ids: [activityItemID])
        if wasActive {
            kernel.resolveProvider((any ChatSectionProviding).self)?.setVisible(true)
            kernel.resolveProvider((any RootViewProviding).self)?.setRailView(
                kernel.resolveProvider((any RailViewProviding).self)?.makeRailView()
            )
            kernel.resolveProvider((any RootViewProviding).self)?.setContentHeaderViewHidden(false)
        }
        InputPluginRuntimeBridge.dataRootDirectory = nil
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }
}
