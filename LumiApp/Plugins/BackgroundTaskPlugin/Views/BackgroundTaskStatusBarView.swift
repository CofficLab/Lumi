import Foundation
import SwiftUI

// MARK: - Status Bar View

struct BackgroundTaskStatusBarView: View {
    @State private var runningCount: Int = 0

    var body: some View {
        StatusBarHoverContainer(
            detailView: BackgroundTaskListView(onRefresh: reload),
            popoverWidth: 560,
            id: "background-task-status"
        ) {
            HStack(spacing: 4) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 11))
                    // 运行中图标保留蓝色以区分状态
                    .foregroundColor(runningCount > 0 ? .blue : .white)

                if runningCount > 0 {
                    Text("\(runningCount)")
                        .font(.system(size: 11))
                        .opacity(0.8)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .onAppear {
            reload()
        }
    }

    private func reload() {
        // 仅统计运行中的任务数量
        let allTasks = BackgroundAgentTaskStore.shared.fetchRecent(limit: 1000)
        runningCount = allTasks.filter { BackgroundAgentTaskStatus(rawOrDefault: $0.statusRawValue) == .running }.count
    }
}
