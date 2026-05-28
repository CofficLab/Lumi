import SwiftUI
import os

actor ModelPreferencePlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    nonisolated static let emoji = "🎯"
    static var category: PluginCategory { .general }
    nonisolated static let verbose: Bool = true
    /// 专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.model-preference")

    static let id = "ModelPreference"
    static let navigationId: String? = nil
    static let displayName = String(localized: "Model Preference", table: "ModelPreference")
    static let description = String(localized: "Remember provider and model per conversation", table: "ModelPreference")
    static let iconName = "target"
    static var order: Int { 100 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = ModelPreferencePlugin()

    // MARK: - Lifecycle

    init() {}

    // MARK: - Root View

    @MainActor
    func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "对话模型偏好",
                subtitle: "为每个对话记住 provider 和模型，切换回来时自动恢复。",
                icon: Self.iconName,
                accent: .orange,
                metrics: [
                    PluginPosterSupport.metric("Model", "模型"),
                    PluginPosterSupport.metric("Chat", "对话级"),
                ],
                rows: ["Provider 记忆", "模型记忆", "根视图监听"],
                chips: ["模型", "偏好", "对话"]
            ),
        ]
    }

    /// 提供根视图包裹器，自动监听对话级别模型偏好变化
    /// - Parameter content: 原始内容视图
    /// - Returns: 包裹了模型偏好监控功能的视图
    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(ModelPreferenceRootView(content: content()))
    }
}
