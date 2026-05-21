import os
import SwiftUI

/// 窗口持久化覆盖层：从 `WindowContainer` 取值写盘；启动恢复由 `WindowPersistenceRestore` 编排。
struct WindowPersistenceOverlay<Content: View>: View, SuperLog {
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
                print(windowId)
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

#Preview("Window Persistence Overlay") {
    WindowPersistenceOverlay(content: Text("Content"))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .inRootView()
}
