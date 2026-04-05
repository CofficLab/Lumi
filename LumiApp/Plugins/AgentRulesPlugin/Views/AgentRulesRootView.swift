import SwiftUI
import MagicKit
import os

/// Agent 规则插件根视图包裹器
///
/// 功能：
/// 1. 从 Environment 获取当前项目路径
/// 2. 将项目路径同步到 AgentRulesService
/// 3. 监听项目变化，自动更新 Service 中的路径
@MainActor
struct AgentRulesRootView<Content: View>: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static var emoji: String { "📜" }
    /// 是否输出详细日志
    nonisolated static var verbose: Bool { AgentRulesPlugin.verbose }
    /// 专用 Logger
    nonisolated static var logger: Logger {
        Logger(subsystem: "com.coffic.lumi", category: "plugin.agent-rules.root-view")
    }

    let content: Content

    @EnvironmentObject var projectVM: ProjectVM

    // 用于记录之前的路径，避免重复更新
    @State private var lastSyncedPath: String = ""
    @State private var hasAppeared = false

    var body: some View {
        content
            .onChange(of: projectVM.currentProjectPath) { _, newPath in
                Task { await handleProjectChange(newPath) }
            }
            .onAppear {
                guard !hasAppeared else { return }
                hasAppeared = true
                Task { await handleProjectChange(projectVM.currentProjectPath) }
            }
    }

    /// 处理项目变化
    private func handleProjectChange(_ path: String) async {
        // 避免重复同步相同的路径
        if path == lastSyncedPath {
            return
        }

        // 同步路径到 Service
        await AgentRulesService.shared.setCurrentProjectPath(path)

        // 更新最后同步的路径
        lastSyncedPath = path

        if Self.verbose {
            if path.isEmpty {
                Self.logger.info("\(Self.t)⚠️ 已清除当前项目路径")
            } else {
                Self.logger.info("\(Self.t)⚙️ 已同步当前项目路径：\(path)")
            }
        }
    }
}
