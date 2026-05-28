import Foundation
import SwiftUI
import LumiCoreKit

/// 请求日志插件
///
/// 记录每次聊天请求的发送数据，包括请求消息、配置、响应等信息。
/// 用于调试和审计。
actor RequestLogPlugin: SuperPlugin, SuperLog {
    nonisolated static let emoji = "📝"
    nonisolated static let verbose: Bool = true
    static let id = "RequestLog"
    static let displayName: String = String(localized: "PluginName", table: "RequestLog")
    static let description: String = String(localized: "PluginDescription", table: "RequestLog")
    static let iconName: String = "doc.text.magnifyingglass"
    static var category: PluginCategory { .agent }
    static var order: Int { 100 }

    static let shared = RequestLogPlugin()

    private init() {}

    @MainActor
    func addPosterViews() -> [AnyView] {
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
    func sendMiddlewares() -> [AnySuperSendMiddleware] {
        [AnySuperSendMiddleware(RequestLogSuperSendMiddleware())]
    }

    @MainActor
    func addStatusBarTrailingView(context: PluginContext) -> AnyView? {
        guard context.activeIcon == EditorPlugin.iconName else { return nil }
        return AnyView(RequestLogStatusBarView())
    }
}
