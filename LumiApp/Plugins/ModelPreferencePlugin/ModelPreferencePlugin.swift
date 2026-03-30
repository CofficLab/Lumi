import MagicKit
import SwiftUI
import os

actor ModelPreferencePlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "🎯"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false
    /// 专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "model-preference.plugin")

    static let id = "ModelPreference"
    static let navigationId: String? = nil
    static let displayName = String(localized: "Model Preference", table: "ModelPreference")
    static let description = String(localized: "Remember current project's provider and model", table: "ModelPreference")
    static let iconName = "target"
    static var order: Int { 100 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = ModelPreferencePlugin()

    // 保存当前的项目路径
    private var currentProjectPath: String = ""

    // MARK: - Lifecycle

    init() {}

    // MARK: - Root View

    /// 提供根视图包裹器，自动监听模型偏好变化
    /// - Parameter content: 原始内容视图
    /// - Returns: 包裹了模型偏好监控功能的视图
    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(ModelPreferenceRootView(content: content()))
    }

    // MARK: - Public API

    /// 设置当前项目路径（由 ModelPreferenceRootView 调用）
    func setCurrentProjectPath(_ path: String) {
        currentProjectPath = path
    }

    /// 获取当前项目路径
    func getCurrentProjectPath() -> String {
        currentProjectPath
    }

    /// 保存当前项目的模型偏好
    /// - Parameters:
    ///   - provider: 供应商名称 (如 "OpenAI", "Anthropic")
    ///   - model: 模型名称 (如 "gpt-4", "claude-3-opus")
    func savePreference(provider: String, model: String) {
        let projectPath = getCurrentProjectPath()
        
        guard !projectPath.isEmpty else {
            if Self.verbose {
                Self.logger.info("\(self.t)⚠️ 没有选中项目，跳过保存")
            }
            return
        }
        
        let store = ModelPreferenceStore.shared
        store.savePreference(forProject: projectPath, provider: provider, model: model)

        if Self.verbose {
            Self.logger.info("\(self.t)💾 保存模型偏好 [\(URL(fileURLWithPath: projectPath).lastPathComponent)]：\(provider) - \(model)")
        }
    }

    /// 获取当前项目的模型偏好
    /// - Returns: 包含供应商和模型的元组，如果不存在则返回 nil
    func getPreference() -> (provider: String, model: String, lastUpdated: Date?)? {
        let projectPath = getCurrentProjectPath()
        
        guard !projectPath.isEmpty else {
            if Self.verbose {
                Self.logger.info("\(self.t)⚠️ 没有选中项目，跳过读取")
            }
            return nil
        }
        
        let store = ModelPreferenceStore.shared
        let result = store.getPreference(forProject: projectPath)
        
        if Self.verbose {
            if let result {
                Self.logger.info("\(self.t)📂 读取模型偏好 [\(URL(fileURLWithPath: projectPath).lastPathComponent)]：\(result.provider) - \(result.model)")
            } else {
                Self.logger.info("\(self.t)📂 未找到模型偏好 [\(URL(fileURLWithPath: projectPath).lastPathComponent)]")
            }
        }
        
        return result
    }

    /// 清除当前项目的模型偏好
    func clearPreference() {
        let projectPath = getCurrentProjectPath()
        
        guard !projectPath.isEmpty else {
            if Self.verbose {
                Self.logger.info("\(self.t)⚠️ 没有选中项目，跳过清除")
            }
            return
        }
        
        let store = ModelPreferenceStore.shared
        store.clearPreference(forProject: projectPath)

        if Self.verbose {
            Self.logger.info("\(self.t)🗑️ 已清除模型偏好 [\(URL(fileURLWithPath: projectPath).lastPathComponent)]")
        }
    }
}
