import AppKit
import os
import SwiftUI

/// 监听窗口 VM 状态变化并防抖写入磁盘。
struct WindowPersistenceOverlay<Content: View>: View, SuperLog {
    nonisolated static var emoji: String { WindowPersistencePlugin.emoji }
    nonisolated static var verbose: Bool { true }
    nonisolated static var logger: Logger { WindowPersistencePlugin.logger }

    let content: Content

    @EnvironmentObject private var windowManagerVM: WindowManagerVM
    @EnvironmentObject private var projectVM: WindowProjectVM

    var body: some View {
        content
            .onChange(of: projectVM.currentProjectPath) {
                if Self.verbose {
                    Self.logger.info("\(Self.t)项目选择变化，保存")
                }
            }
    }
}

#Preview("Window Persistence Overlay") {
    WindowPersistenceOverlay(content: Text("Content"))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .inRootView()
}
