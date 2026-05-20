import SwiftUI
import os

/// 模型偏好根视图包裹器
///
/// 优先级：对话偏好 > 项目偏好 > 全局兜底
///
/// 功能：
/// 1. 监听模型选择变化，自动保存到当前对话和当前项目
/// 2. 监听对话切换，先保存旧对话偏好，再加载新对话偏好
/// 3. 监听项目切换，加载对应项目的模型偏好
@MainActor
struct ModelPreferenceRootView<Content: View>: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static var emoji: String { "🎯" }
    /// 是否输出详细日志
    nonisolated static var verbose: Bool { ModelPreferencePlugin.verbose }
    /// 专用 Logger
    nonisolated static var logger: Logger {
        ModelPreferencePlugin.logger
    }

    let content: Content

    @EnvironmentObject var llmVM: AppLLMVM
    @EnvironmentObject var projectVM: WindowProjectVM
    @EnvironmentObject var conversationVM: WindowConversationVM

    // 用于记录之前的模型配置，避免重复保存
    @State private var lastSavedProvider: String = ""
    @State private var lastSavedModel: String = ""
    @State private var lastSavedProjectPath: String = ""
    @State private var hasAppeared = false
    // 标记是否正在加载配置，避免加载时触发保存
    @State private var isLoadingConfig = false
    @State private var preferenceLoadTask: Task<Void, Never>?
    @State private var preferenceLoadToken: UUID?

    var body: some View {
        content
            .onChange(of: llmVM.selectedProviderId) { _, _ in
                handleModelChange()
            }
            .onChange(of: llmVM.currentModel) { _, _ in
                handleModelChange()
            }
            .onChange(of: conversationVM.selectedConversationId) { oldId, newId in
                handleConversationChange(oldId: oldId, newId: newId)
            }
            .onChange(of: projectVM.currentProjectPath) { oldPath, newPath in
                handleProjectChange(oldPath: oldPath, newPath: newPath)
            }
            .onAppear {
                guard !hasAppeared else { return }
                hasAppeared = true
                // 首次加载：按优先级恢复配置
                restoreConfigOnStartup()
            }
            .onDisappear {
                preferenceLoadTask?.cancel()
                preferenceLoadTask = nil
                preferenceLoadToken = nil
                isLoadingConfig = false
            }
    }

    // MARK: - 启动恢复

    /// 首次启动时按优先级恢复配置
    private func restoreConfigOnStartup() {
        isLoadingConfig = true

        // 优先级 1：当前对话的偏好
        if let conversationPref = conversationVM.getModelPreference() {
            applyConfig(provider: conversationPref.providerId, model: conversationPref.model, source: "对话")
            isLoadingConfig = false
            return
        }

        // 优先级 2：当前项目的偏好
        let projectPath = projectVM.currentProjectPath
        if !projectPath.isEmpty {
            loadProjectPreference(for: projectPath, source: "项目") {
                if Self.verbose {
                    if Self.verbose {
                                            Self.logger.info("\(self.t)🔄 启动时无对话/项目偏好，保持 AppLLMVM 默认值")
                    }
                }
            }
            return
        }

        // 优先级 3：AppLLMVM 全局兜底（ensureProviderAndModelSelection 已在 init 中调用）
        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("\(self.t)🔄 启动时无对话/项目偏好，保持 AppLLMVM 默认值")
            }
        }
        isLoadingConfig = false
    }

    // MARK: - 模型变化处理

    /// 处理模型变化：保存到当前对话 + 当前项目
    private func handleModelChange() {
        let currentProvider = llmVM.selectedProviderId
        let currentModel = llmVM.currentModel
        let currentProjectPath = projectVM.currentProjectPath

        // 只在有项目和有效值时保存
        guard !currentProjectPath.isEmpty,
              !currentProvider.isEmpty,
              !currentModel.isEmpty else {
            return
        }

        // 如果正在加载配置，不要触发保存
        guard !isLoadingConfig else {
            return
        }

        // 避免重复保存相同的配置
        if currentProvider == lastSavedProvider,
           currentModel == lastSavedModel,
           currentProjectPath == lastSavedProjectPath {
            return
        }

        // 保存到当前对话
        conversationVM.saveModelPreference(providerId: currentProvider, model: currentModel)

        // 保存到当前项目
        Task {
            await ModelPreferencePlugin.shared.setCurrentProjectPath(currentProjectPath)
            await ModelPreferencePlugin.shared.savePreference(
                provider: currentProvider,
                model: currentModel
            )
        }

        // 更新最后保存的状态
        lastSavedProvider = currentProvider
        lastSavedModel = currentModel
        lastSavedProjectPath = currentProjectPath

        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("\(self.t)💾 已保存模型偏好（对话+项目）：\(currentProvider) - \(currentModel)")
            }
        }
    }

    // MARK: - 对话切换处理

    /// 处理对话切换
    private func handleConversationChange(oldId: UUID?, newId: UUID?) {
        isLoadingConfig = true

        // 清除上次保存的记录，确保新对话可以正常保存
        lastSavedProjectPath = ""

        // 优先级 1：新对话自身的偏好
        if let newId,
           let conversation = conversationVM.fetchConversation(id: newId),
           let providerId = conversation.providerId,
           let model = conversation.model {
            applyConfig(provider: providerId, model: model, source: "对话[\(conversation.title)]")
            isLoadingConfig = false
            return
        }

        // 优先级 2：当前项目的偏好
        let projectPath = projectVM.currentProjectPath
        if !projectPath.isEmpty {
            let projectName = projectVM.currentProjectName
            loadProjectPreference(for: projectPath, source: "项目[\(projectName)]") {
                if Self.verbose {
                    if Self.verbose {
                                            Self.logger.info("\(self.t)🔄 切换对话时无对话/项目偏好，保持 AppLLMVM 当前值")
                    }
                }
                lastSavedProvider = llmVM.selectedProviderId
                lastSavedModel = llmVM.currentModel
            }
            return
        }

        // 优先级 3：保持 AppLLMVM 当前值（全局兜底）
        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("\(self.t)🔄 切换对话时无对话/项目偏好，保持 AppLLMVM 当前值")
            }
        }

        // 更新 lastSaved 状态，避免触发不必要的保存
        lastSavedProvider = llmVM.selectedProviderId
        lastSavedModel = llmVM.currentModel
        isLoadingConfig = false
    }

    // MARK: - 项目切换处理

    /// 处理项目切换
    private func handleProjectChange(oldPath: String, newPath: String) {
        isLoadingConfig = true

        // 清除上次保存的项目路径记录
        lastSavedProjectPath = ""

        // 更新 Plugin 中的项目路径
        Task {
            await ModelPreferencePlugin.shared.setCurrentProjectPath(newPath)
        }

        guard !newPath.isEmpty else {
            if Self.verbose {
                if Self.verbose {
                                    Self.logger.info("\(self.t)📁 已清除项目，不加载模型偏好")
                }
            }
            isLoadingConfig = false
            return
        }

        // 优先级 1：当前对话的偏好（如果对话有独立偏好，项目切换不影响）
        if let conversationPref = conversationVM.getModelPreference() {
            if Self.verbose {
                if Self.verbose {
                                    Self.logger.info("\(self.t)📂 项目切换，但当前对话有独立偏好，保持不变：\(conversationPref.providerId) - \(conversationPref.model)")
                }
            }
            lastSavedProvider = conversationPref.providerId
            lastSavedModel = conversationPref.model
            lastSavedProjectPath = newPath
            isLoadingConfig = false
            return
        }

        // 优先级 2：新项目的偏好
        let projectName = projectVM.currentProjectName
        loadProjectPreference(for: newPath, source: "项目[\(projectName)]") {
            // 优先级 3：保持 AppLLMVM 当前值
            if Self.verbose {
                if Self.verbose {
                                    Self.logger.info("\(self.t)📂 项目 '\(projectName)' 没有保存的模型偏好，保持当前值")
                }
            }
            lastSavedProvider = llmVM.selectedProviderId
            lastSavedModel = llmVM.currentModel
        }
    }

    // MARK: - 辅助方法

    /// 将配置应用到 AppLLMVM，并更新去重状态
    private func applyConfig(provider: String, model: String, source: String) {
        llmVM.selectedProviderId = provider
        llmVM.currentModel = model

        // 更新去重状态，避免 onChange 触发重复保存
        lastSavedProvider = provider
        lastSavedModel = model
        lastSavedProjectPath = projectVM.currentProjectPath

        if Self.verbose {
            if Self.verbose {
                            Self.logger.info("\(self.t)📂 已加载 \(source) 的模型偏好：\(provider) - \(model)")
            }
        }
    }

    private func loadProjectPreference(
        for projectPath: String,
        source: String,
        onMissing: @escaping @MainActor () -> Void
    ) {
        preferenceLoadTask?.cancel()
        let token = UUID()
        preferenceLoadToken = token
        isLoadingConfig = true

        preferenceLoadTask = Task { @MainActor in
            let preference = await Task.detached(priority: .utility) {
                ModelPreferenceStore.shared.getPreference(forProject: projectPath)
            }.value

            guard preferenceLoadToken == token else { return }
            defer {
                if preferenceLoadToken == token {
                    preferenceLoadToken = nil
                    preferenceLoadTask = nil
                    isLoadingConfig = false
                }
            }

            guard !Task.isCancelled, projectVM.currentProjectPath == projectPath else { return }

            if let preference {
                applyConfig(provider: preference.provider, model: preference.model, source: source)
            } else {
                onMissing()
            }
        }
    }
}
