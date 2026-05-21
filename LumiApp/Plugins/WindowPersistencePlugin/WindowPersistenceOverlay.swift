import AppKit
import os
import SwiftUI

/// 监听窗口 VM 状态变化并防抖写入磁盘。
struct WindowPersistenceOverlay<Content: View>: View, SuperLog {
    nonisolated static var emoji: String { WindowPersistencePlugin.emoji }
    nonisolated static var verbose: Bool { WindowPersistencePlugin.verbose }
    nonisolated static var logger: Logger { WindowPersistencePlugin.logger }

    let content: Content

    @EnvironmentObject private var windowManagerVM: WindowManagerVM
    @EnvironmentObject private var projectVM: WindowProjectVM

    var body: some View {
        content
            .onChange(of: persistenceFingerprint) { _, _ in
                WindowPersistenceCoordinator.shared.scheduleSave()
            }
            .onChange(of: projectVM.currentProjectPath) { _, _ in
                if Self.verbose {
                    Self.logger.info("\(Self.t) 项目选择变化，保存")
                }
                WindowPersistenceCoordinator.shared.scheduleSave()
            }
            .onReceive(NotificationCenter.default.publisher(for: .windowStateShouldPersist)) { _ in
                WindowPersistenceCoordinator.shared.scheduleSave()
            }
    }

    /// 聚合各窗口可持久化字段，用于触发保存。
    private var persistenceFingerprint: String {
        windowManagerVM.windowContainers.map { container in
            [
                container.id.uuidString,
                container.projectPath ?? "",
                container.selectedConversationId?.uuidString ?? "",
                container.activePanel.rawValue,
                String(container.sidebarVisibility),
                container.editorState.openFileURLs.map(\.path).joined(separator: ","),
                container.editorState.activeFileURL?.path ?? "",
            ].joined(separator: "|")
        }.joined(separator: ";")
    }
}

#Preview("Window Persistence Overlay") {
    WindowPersistenceOverlay(content: Text("Content"))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .inRootView()
}
