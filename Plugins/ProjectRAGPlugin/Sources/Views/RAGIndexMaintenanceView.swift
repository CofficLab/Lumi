import Foundation
import SwiftUI
import LumiKernel

/// 后台索引维护视图
///
/// 作为 rootOverlay 常驻运行，不渲染任何 UI，
/// 仅负责在项目切换或索引过期时自动触发增量索引。
struct RAGIndexMaintenanceView: View {
    @State private var lastMaintainedProject: String = ""
    @State private var lastMaintenanceAt: Date = .distantPast

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .task(id: RAGPluginRuntime.currentProjectPath) {
                await maintainIndex()
            }
            // 定期检查索引是否过期
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 5 * 60_000_000_000) // 每 5 分钟检查一次
                    if Task.isCancelled { break }
                    await maintainIndex()
                }
            }
    }

    private func maintainIndex() async {
        let projectPath = RAGPluginRuntime.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !projectPath.isEmpty else { return }

        // 项目切换时立即维护
        if projectPath != lastMaintainedProject {
            lastMaintainedProject = projectPath
            lastMaintenanceAt = .now
            await triggerIndexIfNeeded(projectPath: projectPath)
            return
        }

        // 距离上次维护超过阈值，检查是否需要更新
        if Date().timeIntervalSince(lastMaintenanceAt) > Self.maintenanceInterval {
            lastMaintenanceAt = .now
            await triggerIndexIfNeeded(projectPath: projectPath)
        }
    }

    private func triggerIndexIfNeeded(projectPath: String) async {
        let service = RAGPlugin.getService()
        try? await service.initialize()

        do {
            let needsIndex = try await service.checkNeedsIndex(projectPath: projectPath)
            if needsIndex {
                await service.ensureIndexedBackground(projectPath: projectPath)
            }
        } catch {
            // 静默处理，下次维护周期会重试
        }
    }

    private static let maintenanceInterval: TimeInterval = 60 // 每 60 秒检查一次
}
