import MagicKit
import SwiftUI
import os

actor ModelPreferencePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.model-preference")
    // MARK: - Plugin Properties

    nonisolated static let emoji = "🎯"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = true

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

    // MARK: - Public API

    /// 保存当前项目的模型偏好
    /// - Parameters:
    ///   - provider: 供应商名称 (如 "OpenAI", "Anthropic")
    ///   - model: 模型名称 (如 "gpt-4", "claude-3-opus")
    func savePreference(provider: String, model: String) {
        let store = ModelPreferenceStore.shared
        store.set(provider, forKey: "provider")
        store.set(model, forKey: "model")

        if Self.verbose {
            Self.logger.info("\(self.t)保存模型偏好: \(provider) - \(model)")
        }
    }

    /// 获取当前项目的模型偏好
    /// - Returns: 包含供应商和模型的元组，如果不存在则返回 nil
    func getPreference() -> (provider: String, model: String)? {
        let store = ModelPreferenceStore.shared

        guard let provider = store.object(forKey: "provider") as? String,
              let model = store.object(forKey: "model") as? String else {
            if Self.verbose {
                Self.logger.info("\(self.t)未找到模型偏好设置")
            }
            return nil
        }

        return (provider, model)
    }

    /// 清除当前项目的模型偏好
    func clearPreference() {
        let store = ModelPreferenceStore.shared
        store.set(nil, forKey: "provider")
        store.set(nil, forKey: "model")

        if Self.verbose {
            Self.logger.info("\(self.t)已清除模型偏好")
        }
    }
}
