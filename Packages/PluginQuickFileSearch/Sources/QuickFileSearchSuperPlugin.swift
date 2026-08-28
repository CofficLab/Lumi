import KernelCore
import ProviderDocsView
import ProviderProject
import ProviderRootView
import ProviderSettingView
import SwiftUI
import KitSuperLog
import os

@MainActor
public final class QuickFileSearchSuperPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.quick-file-search", category: "QuickFileSearch")
    public let id = "QuickFileSearch"
    public let order = 50
    public let metadata = PluginMetadata(id: "QuickFileSearch", name: "Quick File Search", description: "Search and open project files with Cmd+P.", category: .editor, stage: .preview, policy: .alwaysOn)
    public init() {}
    public func onBoot(kernel: KernelCoreContainer) throws {
        let project = kernel.resolveProvider((any ProjectProviding).self)
        QuickFileSearchBridge.selectFileHandler = { path, _ in
            Task { @MainActor in
                guard let documents = kernel.resolveProvider((any EditorDocumentProviding).self) else { return }
                _ = try? await documents.open(EditorOpenRequest(uri: URL(fileURLWithPath: path)))
            }
        }
        QuickFileSearchBridge.activeWindowIdProvider = { nil }
        FileSearchHotkeyManager.shared.startMonitoring()
        kernel.resolveProvider((any RootViewProviding).self)?.addOverlays([RootOverlayItem(id: id, order: order) { content in
            FileSearchOverlay(content: content, projectPathProvider: { project?.currentProject?.path ?? "" }, windowIdProvider: { nil })
        }])
        kernel.resolveProvider((any SettingViewProviding).self)?.addEntries([SettingEntryItem(id: id, title: LumiPluginLocalization.string("Quick File Search", bundle: .module), systemImage: "magnifyingglass", order: order) { QuickFileSearchSettingsView(projectPath: project?.currentProject?.path ?? "") }])
        let title = metadata.name
        kernel.resolveProvider((any DocsViewProviding).self)?.addAbout(
            DocsEntry(id: id, name: title) { QuickFileSearchAboutView() }
        )
        kernel.resolveProvider((any DocsViewProviding).self)?.addManual(
            DocsEntry(id: id, name: title) { QuickFileSearchManualView() }
        )
    }
    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any RootViewProviding).self)?.removeOverlays(ids: [id])
        kernel.resolveProvider((any SettingViewProviding).self)?.removeEntries(ids: [id])
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
        FileSearchHotkeyManager.shared.stopMonitoring()
        QuickFileSearchBridge.selectFileHandler = nil; QuickFileSearchBridge.activeWindowIdProvider = nil
    }
}
