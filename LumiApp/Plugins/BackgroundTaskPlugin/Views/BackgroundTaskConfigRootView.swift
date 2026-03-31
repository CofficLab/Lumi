import SwiftUI
import MagicKit
import os

/// 后台任务配置根视图包裹器
///
/// 功能：
/// 1. 从 Environment 获取当前的 LLM 供应商和模型配置
/// 2. 将配置同步到 BackgroundAgentTaskPlugin，供 Worker 使用
/// 3. 监听配置变化，自动更新插件中的配置
@MainActor
struct BackgroundTaskConfigRootView<Content: View>: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static var emoji: String { "🧵" }
    /// 是否输出详细日志
    nonisolated static var verbose: Bool { BackgroundAgentTaskPlugin.verbose }
    /// 专用 Logger
    nonisolated static var logger: Logger {
        Logger(subsystem: "com.coffic.lumi", category: "background-task.config-root-view")
    }

    let content: Content

    @EnvironmentObject var llmVM: LLMVM
    @EnvironmentObject var projectVM: ProjectVM

    // 用于记录之前的配置，避免重复更新
    @State private var lastSyncedProvider: String = ""
    @State private var lastSyncedModel: String = ""
    @State private var hasAppeared = false

    var body: some View {
        content
            .onChange(of: llmVM.selectedProviderId) { _, _ in
                Task { await handleConfigChange() }
            }
            .onChange(of: llmVM.currentModel) { _, _ in
                Task { await handleConfigChange() }
            }
            .onAppear {
                guard !hasAppeared else { return }
                hasAppeared = true
                Task { await handleConfigChange() }
            }
    }

    /// 处理配置变化
    private func handleConfigChange() async {
        let currentProvider = llmVM.selectedProviderId
        let currentModel = llmVM.currentModel

        // 确保有有效的配置
        guard !currentProvider.isEmpty,
              !currentModel.isEmpty else {
            if Self.verbose {
                Self.logger.info("\(Self.t)⚠️ 当前配置无效，跳过同步")
            }
            return
        }

        // 避免重复同步相同的配置
        if currentProvider == lastSyncedProvider,
           currentModel == lastSyncedModel {
            return
        }

        // 同步配置到插件
        await BackgroundAgentTaskPlugin.shared.setGlobalConfig(
            providerId: currentProvider,
            model: currentModel
        )

        // 更新最后同步的状态
        lastSyncedProvider = currentProvider
        lastSyncedModel = currentModel

        if Self.verbose {
            Self.logger.info("\(Self.t)⚙️ 已同步后台任务配置：\(currentProvider) - \(currentModel)")
        }
    }
}
