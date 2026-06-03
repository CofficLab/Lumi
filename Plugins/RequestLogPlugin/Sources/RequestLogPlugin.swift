import Foundation
import SuperLogKit
import SwiftUI
import LumiCoreKit
import LumiUI

/// 请求日志插件
///
/// 记录每次聊天请求的发送数据，包括请求消息、配置、响应等信息。
/// 用于调试和审计。
public actor RequestLogPlugin: SuperPlugin, SuperLog {
    public nonisolated static let emoji = "📝"
    public nonisolated static let verbose: Bool = true
    public nonisolated static let policy: PluginPolicy = .alwaysOn
    public static let id = "RequestLog"
    public static let displayName: String = String(localized: "PluginName", bundle: .module)
    public static let description: String = String(localized: "PluginDescription", bundle: .module)
    public static let iconName: String = "doc.text.magnifyingglass"
    public static var category: PluginCategory { .agent }
    public static var order: Int { 100 }

    public static let shared = RequestLogPlugin()

    private init() {}

    @MainActor
    public func addPosterViews() -> [AnyView] {
        [
            PluginPosterSupport.poster(
                title: "请求日志",
                subtitle: "记录聊天请求、配置和响应，方便调试与审计。",
                icon: Self.iconName,
                accent: .gray,
                metrics: [
                    PluginPosterSupport.metric("JSON", "请求体"),
                    PluginPosterSupport.metric("Audit", "审计"),
                ],
                rows: ["发送消息", "模型配置", "响应结果"],
                chips: ["Agent", "日志", "调试"]
            ),
        ]
    }

    @MainActor
    public func sendMiddlewares() -> [AnySuperSendMiddleware] {
        [AnySuperSendMiddleware(RequestLogSuperSendMiddleware())]
    }

    @MainActor
    public func addStatusBarTrailingView(context: PluginContext) -> AnyView? {
        guard context.activeIcon == "chevron.left.forwardslash.chevron.right" else { return nil }
        return AnyView(RequestLogStatusBarView())
    }
}
