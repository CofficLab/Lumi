import SwiftUI
import os

/// 模型偏好根视图包裹器
///
/// 功能：
/// 1. 监听模型选择变化，自动保存到当前项目
/// 2. 监听项目切换，自动加载对应项目的模型偏好
@MainActor
struct ModelPreferenceRootView<Content: View>: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static var emoji: String { "🎯" }
    /// 是否输出详细日志
    nonisolated static var verbose: Bool { ModelPreferencePlugin.verbose }
    /// 专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "model-preference.root-view")

    let content: Content

    @EnvironmentObject var llmVM: LLMVM
    @EnvironmentObject var projectVM: ProjectVM

    // 用于记录之前的模型配置，避免重复保存
    @State private var lastSavedProvider: String = ""
    @State private var lastSavedModel: String = ""
    @State private var lastSavedProjectPath: String = ""
    @State private var hasAppeared = false

    var body: some View {
        content
            .onChange(of: llmVM.selectedProviderId) { _, _ in
                Task { await handleModelChange() }
            }
            .onChange(of: llmVM.currentModel) { _, _ in
                Task { await handleModelChange() }
            }
            .onChange(of: projectVM.currentProjectPath) { _, _ in
                Task { await handleProjectChange() }
            }
            .onAppear {
                guard !hasAppeared else { return }
                hasAppeared = true
                Task { await handleProjectChange() }
            }
    }

    /// 处理模型变化
    private func handleModelChange() async {
        let currentProvider = llmVM.selectedProviderId
        let currentModel = llmVM.currentModel
        let currentProjectPath = projectVM.currentProjectPath

        // 只在有项目时保存
        guard !currentProjectPath.isEmpty,
              !currentProvider.isEmpty,
              !currentModel.isEmpty else {
            return
        }

        // 避免重复保存相同的配置
        if currentProvider == lastSavedProvider,
           currentModel == lastSavedModel,
           currentProjectPath == lastSavedProjectPath {
            return
        }

        // 更新 Plugin 中的项目路径
        await ModelPreferencePlugin.shared.setCurrentProjectPath(currentProjectPath)

        // 保存偏好
        await ModelPreferencePlugin.shared.savePreference(
            provider: currentProvider,
            model: currentModel
        )

        // 更新最后保存的状态
        lastSavedProvider = currentProvider
        lastSavedModel = currentModel
        lastSavedProjectPath = currentProjectPath

        if Self.verbose {
            Self.logger.info("\(self.t)💾 已保存项目 '\(projectVM.currentProjectName)' 的模型偏好：\(currentProvider) - \(currentModel)")
        }
    }

    /// 处理项目切换
    private func handleProjectChange() async {
        let currentProjectPath = projectVM.currentProjectPath

        // 更新 Plugin 中的项目路径
        await ModelPreferencePlugin.shared.setCurrentProjectPath(currentProjectPath)

        // 清除上次保存的项目路径记录
        lastSavedProjectPath = ""

        // 如果有项目，尝试加载该项目的模型偏好
        guard !currentProjectPath.isEmpty else {
            if Self.verbose {
                Self.logger.info("\(self.t)📁 已清除项目，不加载模型偏好")
            }
            return
        }

        // 使用新的 API 获取带 lastUpdated 的信息
        let store = ModelPreferenceStore.shared
        if let (provider, model, lastUpdated) = store.getPreference(forProject: currentProjectPath) {
            // 只有当当前没有设置模型，或者设置不同的模型时才更新
            if llmVM.selectedProviderId.isEmpty || llmVM.currentModel.isEmpty {
                llmVM.selectedProviderId = provider
                llmVM.currentModel = model

                // 更新最后保存的状态，避免触发保存
                lastSavedProvider = provider
                lastSavedModel = model
                lastSavedProjectPath = currentProjectPath

                if Self.verbose {
                    let dateStr = lastUpdated.map { " (更新于：\($0.formatted()))" } ?? ""
                    Self.logger.info("\(self.t)📂 已加载项目 '\(projectVM.currentProjectName)' 的模型偏好：\(provider) - \(model)\(dateStr)")
                }
            } else {
                if Self.verbose {
                    Self.logger.info("\(self.t)📂 项目 '\(projectVM.currentProjectName)' 有保存的模型偏好 (\(provider) - \(model))，但用户已手动选择其他模型，不覆盖")
                }
            }
        } else {
            if Self.verbose {
                Self.logger.info("\(self.t)📂 项目 '\(projectVM.currentProjectName)' 没有保存的模型偏好")
            }
        }
    }
}