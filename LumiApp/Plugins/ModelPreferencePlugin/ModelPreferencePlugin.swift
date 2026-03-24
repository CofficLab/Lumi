import MagicKit
import SwiftUI
import os

actor ModelPreferencePlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "🎯"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = true
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

    /// 保存当前项目的模型偏好
    /// - Parameters:
    ///   - provider: 供应商名称 (如 "OpenAI", "Anthropic")
    ///   - model: 模型名称 (如 "gpt-4", "claude-3-opus")
    func savePreference(provider: String, model: String) async {
        guard let projectPath = await getCurrentProjectPath() else {
            if Self.verbose {
                Self.logger.info("\(self.t)⚠️ 没有选中项目，跳过保存")
            }
            return
        }
        
        let store = ModelPreferenceStore.shared
        store.savePreference(forProject: projectPath, provider: provider, model: model)

        if Self.verbose {
            Self.logger.info("\(self.t)💾 保存模型偏好 [\(projectPath)]：\(provider) - \(model)")
        }
    }

    /// 获取当前项目的模型偏好
    /// - Returns: 包含供应商和模型的元组，如果不存在则返回 nil
    func getPreference() async -> (provider: String, model: String, lastUpdated: Date?)? {
        guard let projectPath = await getCurrentProjectPath() else {
            if Self.verbose {
                Self.logger.info("\(self.t)⚠️ 没有选中项目，跳过读取")
            }
            return nil
        }
        
        let store = ModelPreferenceStore.shared
        let result = store.getPreference(forProject: projectPath)
        
        if Self.verbose {
            if let result {
                Self.logger.info("\(self.t)📂 读取模型偏好 [\(projectPath)]：\(result.provider) - \(result.model)")
            } else {
                Self.logger.info("\(self.t)📂 未找到模型偏好 [\(projectPath)]")
            }
        }
        
        return result
    }

    /// 清除当前项目的模型偏好
    func clearPreference() async {
        guard let projectPath = await getCurrentProjectPath() else {
            if Self.verbose {
                Self.logger.info("\(self.t)⚠️ 没有选中项目，跳过清除")
            }
            return
        }
        
        let store = ModelPreferenceStore.shared
        store.clearPreference(forProject: projectPath)

        if Self.verbose {
            Self.logger.info("\(self.t)🗑️ 已清除模型偏好 [\(projectPath)]")
        }
    }

    // MARK: - Private Helpers

    /// 获取当前项目路径
    private func getCurrentProjectPath() async -> String? {
        // 通过通知中心或全局状态获取当前项目路径
        // 这里使用一个简单的方案：从 ProjectVM 获取
        // 由于这是 actor 方法，需要通过 MainActor 获取
        await MainActor.run {
            // 尝试从环境中获取，或者通过其他方式
            // 这里暂时返回 nil，实际使用时由调用方传入
            nil
        }
    }
}