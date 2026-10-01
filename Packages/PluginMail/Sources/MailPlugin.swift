import Foundation
import KernelCore
import ProviderSettingView
import SwiftUI
import os
import LumiLoggingKit

/// PluginMail 插件入口。
///
/// 职责：
/// - 注册「邮件账户」设置入口（账户 CRUD / 连接测试 / 删除）；
/// - 持有 Session/Sync 服务生命周期（Phase 2 Task 2.3），
///   `onShutdown` 断开全部会话。
@MainActor
public final class MailPlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.mail",
        category: "MailPlugin"
    )

    public let id = "com.coffic.lumi.plugin.mail"
    public let order = 120
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.mail",
        name: pluginLocalization.string("Mail"),
        description: "IMAP/SMTP 邮件客户端：多账户、三栏工作区、撰写发送与 Agent 工具。",
        category: .system,
        stage: .preview,
        policy: .disabledByDefault
    )

    /// 会话池（懒连接 / 断线重连 / onShutdown 全断）。
    private let sessionManager = MailSessionManager()

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let settings = kernel.resolveProvider((any SettingViewProviding).self) else {
            // 设置视图未注册：优雅降级，不贡献入口。
            return
        }
        let sessionManager = self.sessionManager
        settings.addEntries([
            SettingEntryItem(
                id: "\(id).settings",
                title: pluginLocalization.string("Mail"),
                systemImage: "envelope",
                order: order
            ) {
                MailSettingsView(sessionManager: sessionManager)
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any SettingViewProviding).self)?
            .removeEntries(ids: ["\(id).settings"])
        Task {
            await sessionManager.disconnectAll()
        }
    }
}
