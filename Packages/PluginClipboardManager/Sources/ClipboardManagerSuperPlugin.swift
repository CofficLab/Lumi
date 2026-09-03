import KernelCore
import ProviderActivityBar
import ProviderToolbar
import ProviderChatSection
import ProviderContentView
import ProviderDocsView
import ProviderRailView
import ProviderRootView
import SwiftUI
import os
import KitSuperLog

enum ClipboardManagerPlugin {
    nonisolated static let verbose = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "ClipboardManagerPlugin")
}

@MainActor
public final class ClipboardManagerSuperPlugin: SuperPlugin, SuperLog {
    public let id = "com.coffic.lumi.plugin.clipboard-manager"
    public let order = 270
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.clipboard-manager",
        name: LumiPluginLocalization.string("Clipboard", bundle: .module),
        description: LumiPluginLocalization.string("Clipboard history manager.", bundle: .module),
        category: .system,
        stage: .preview,
        policy: .disabledByDefault
    )

    private var viewModel: ClipboardManagerViewModel?
    private var historyObserver: ClipboardHistoryObserver?

    public init() {}

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: metadata.name) {
                ClipboardManagerAboutView()
            })
            docs.addManual(DocsEntry(id: id, name: metadata.name) {
                ClipboardManagerManualView()
            })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        ClipboardMonitor.shared.startMonitoring()
        let viewModel = ClipboardManagerViewModel()
        self.viewModel = viewModel
        historyObserver = ClipboardHistoryObserver { [weak viewModel] in
            viewModel?.refresh()
        }
        let content = kernel.resolveProvider((any ContentViewProviding).self)
        let chat = kernel.resolveProvider((any ChatSectionProviding).self)
        let railView = kernel.resolveProvider((any RailViewProviding).self)
        let rootView = kernel.resolveProvider((any RootViewProviding).self)
        let toolbar = kernel.resolveProvider((any ToolbarProviding).self)
        let entry = "\(id).entry"

        if let bar = kernel.resolveProvider((any ActivityBarProviding).self) {
            bar.addItems([
                ActivityBarItem(
                    id: entry,
                    title: metadata.name,
                    systemImage: "doc.on.clipboard",
                    order: order,
                    ownerPluginID: id
                ) { state in
                    if state == .activated {
                        toolbar?.setVisibleCategories([.global, .system])
                        content?.setContentView(AnyView(ClipboardHistoryView(viewModel: viewModel)))
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
            content?.setContentView(AnyView(ClipboardHistoryView(viewModel: viewModel)))
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        ClipboardMonitor.shared.stopMonitoring()
        historyObserver?.cancel()
        historyObserver = nil
        viewModel = nil
        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        let wasActive = activityBar?.activeItemID == "\(id).entry"
        activityBar?.removeItems(ids: ["\(id).entry"])
        if wasActive {
            kernel.resolveProvider((any ChatSectionProviding).self)?.setVisible(true)
        }
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }
}
