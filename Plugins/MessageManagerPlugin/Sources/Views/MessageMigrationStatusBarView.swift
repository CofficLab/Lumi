import Foundation
import LumiUI
import SwiftUI

/// 仅在消息迁移运行时显示状态栏入口。
struct MessageMigrationStatusBarView: View {
    @ObservedObject private var progress = MessageMigrationProgressStore.shared

    var body: some View {
        if progress.isActive {
            StatusBarHoverContainer(
                detailView: MessageMigrationPopoverView(),
                id: "message-migration-status"
            ) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.appMicroEmphasized)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
        }
    }
}
