import LumiCoreKit
import PluginWindowPersistence
import SuperLogKit
import SwiftUI
import os

/// App-side registration adapter for the packaged window persistence plugin.
actor WindowPersistencePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = PluginWindowPersistence.WindowPersistencePlugin.logger
    nonisolated static let emoji = PluginWindowPersistence.WindowPersistencePlugin.emoji
    nonisolated static let verbose = PluginWindowPersistence.WindowPersistencePlugin.verbose

    static var category: PluginCategory { PluginCategory(package: PluginWindowPersistence.WindowPersistencePlugin.category) }
    static let id = PluginWindowPersistence.WindowPersistencePlugin.id
    static let displayName = PluginWindowPersistence.WindowPersistencePlugin.displayName
    static let description = PluginWindowPersistence.WindowPersistencePlugin.description
    static let iconName = PluginWindowPersistence.WindowPersistencePlugin.iconName
    static var order: Int { PluginWindowPersistence.WindowPersistencePlugin.order }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = WindowPersistencePlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(WindowPersistenceOverlay(content: content()))
    }
}

private struct WindowPersistenceOverlay<Content: View>: View, SuperLog {
    nonisolated static var emoji: String { WindowPersistencePlugin.emoji }
    nonisolated static var verbose: Bool { WindowPersistencePlugin.verbose }
    nonisolated static var logger: Logger { WindowPersistencePlugin.logger }

    private let store = WindowStateStore.shared

    let content: Content

    @EnvironmentObject private var windowManagerVM: AppWindowManagerVM
    @EnvironmentObject private var windowContainer: WindowContainer
    @EnvironmentObject private var projectVM: WindowProjectVM
    @EnvironmentObject private var conversationVM: WindowConversationVM

    private var windowId: UUID { windowContainer.id }

    var body: some View {
        content
            .onAppear {
                restoreCurrentWindowIfNeeded()
            }
            .onChange(of: projectVM.currentProjectPath) {
                store.saveProject(
                    windowId: windowId,
                    projectPath: windowContainer.projectPath,
                    createdAt: windowContainer.createdAt
                )
            }
            .onChange(of: conversationVM.selectedConversationId) {
                store.saveConversation(
                    windowId: windowId,
                    conversationId: windowContainer.selectedConversationId
                )
            }
            .onChange(of: windowContainer.sidebarVisibility) {
                store.saveSidebar(
                    windowId: windowId,
                    sidebarVisibility: windowContainer.sidebarVisibility
                )
            }
            .onChange(of: windowContainer.editorOpenFileURLs) {
                store.saveEditor(
                    windowId: windowId,
                    editorOpenFilePaths: editorOpenPaths,
                    editorActiveFilePath: windowContainer.editorActiveFileURL?.path
                )
            }
            .onChange(of: windowContainer.editorActiveFileURL) {
                store.saveEditor(
                    windowId: windowId,
                    editorOpenFilePaths: editorOpenPaths,
                    editorActiveFilePath: windowContainer.editorActiveFileURL?.path
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .windowStateShouldPersist)) { _ in
                store.saveAll(snapshotRecords(from: windowManagerVM.windowContainers))
            }
            .onReceive(NotificationCenter.default.publisher(for: .windowClosed)) { _ in
                store.saveAll(snapshotRecords(from: windowManagerVM.windowContainers))
            }
            .onApplicationWillTerminate {
                store.saveAllSynchronously(snapshotRecords(from: windowManagerVM.windowContainers))
            }
    }

    private var editorOpenPaths: [String]? {
        let paths = windowContainer.editorOpenFileURLs.map(\.path)
        return paths.isEmpty ? nil : paths
    }

    private func restoreCurrentWindowIfNeeded() {
        guard let record = store.record(for: windowId) else { return }
        windowContainer.applyPersistenceRecord(record)
    }

    private func snapshotRecords(from containers: [WindowContainer]) -> [WindowPersistenceRecord] {
        containers.map { container in
            let openPaths = container.editorOpenFileURLs.map(\.path)
            return WindowPersistenceRecord(
                windowId: container.id,
                conversationId: container.selectedConversationId,
                projectPath: container.projectPath,
                editorOpenFilePaths: openPaths.isEmpty ? nil : openPaths,
                editorActiveFilePath: container.editorActiveFileURL?.path,
                sidebarVisibility: container.sidebarVisibility,
                createdAt: container.createdAt
            )
        }
    }
}
