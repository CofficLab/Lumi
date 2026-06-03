import SwiftUI
import LumiUI
import LumiCoreKit
import SuperLogKit
import os

public actor ModelPreferencePlugin: SuperPlugin, SuperLog {
    public nonisolated static let policy: PluginPolicy = .disabled
    // MARK: - Plugin Properties

    public nonisolated static let emoji = "🎯"
    public static var category: PluginCategory { .general }
    public nonisolated static let verbose: Bool = true
    /// 专用 Logger
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.model-preference")

    public static let id = "ModelPreference"
    public static let navigationId: String? = nil
    public static let displayName = String(localized: "Model Preference", bundle: .module)
    public static let description = String(localized: "Remember provider and model per conversation", bundle: .module)
    public static let iconName = "target"
    public static var order: Int { 100 }

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = ModelPreferencePlugin()

    // MARK: - Lifecycle

    public init() {}

    // MARK: - Root View

    @MainActor
    public func addPosterViews() -> [AnyView] {
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
    public func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(ModelPreferenceRootView(content: content()))
    }
}
