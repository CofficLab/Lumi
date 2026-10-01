import Foundation
import KernelCore
import ProviderSettingView
import ProviderContentView
import ProviderChatSection
import ProviderRootView
import ProviderToolbar
import ProviderActivityBar
import ProviderToolManager
import SwiftUI
import os
import LumiLoggingKit

/// PluginMail 插件入口。
///
/// 职责：
/// - 注册「邮件账户」设置入口（账户 CRUD / 连接测试 / 删除）；
/// - 装配 ActivityBar 入口：激活时切换三栏工作区并隐藏 chat、加工具栏标题，
///   还原时全部撤销（参照 DatabaseManagerSuperPlugin 对称写法）；
/// - 持有 Session/Cache/Sync 服务生命周期，`onShutdown` 断开全部会话并回收入口。
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
    public let sessionManager = MailSessionManager()
    /// 本地缓存（SwiftData，插件数据目录）。
    public lazy var cacheService = MailCacheService(databaseDirectory: MailPluginRuntime.dataDirectory())
    /// 发送编排。
    public lazy var composerService = MailComposerService(sessionManager: sessionManager)
    /// Agent 工具服务。
    public lazy var agentToolService = MailAgentToolService(
        sessionManager: sessionManager,
        cache: cacheService,
        composer: composerService
    )

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        let sessionManager = self.sessionManager
        kernel.resolveProvider((any SettingViewProviding).self)?.addEntries([
            SettingEntryItem(
                id: "\(id).settings",
                title: pluginLocalization.string("Mail"),
                systemImage: "envelope",
                order: order
            ) {
                MailSettingsView(sessionManager: sessionManager)
            },
        ])

        // ActivityBar 入口：激活/还原对称装配。
        let contentView = kernel.resolveProvider((any ContentViewProviding).self)
        let chat = kernel.resolveProvider((any ChatSectionProviding).self)
        let rootView = kernel.resolveProvider((any RootViewProviding).self)
        let toolbar = kernel.resolveProvider((any ToolbarProviding).self)
        let cache = cacheService
        let pluginID = id
        let tools = kernel.resolveProvider((any ToolManagerProviding).self)
        let agentService = agentToolService
        tools?.add(MailListMessagesTool(service: agentService), pluginID: id)
        tools?.add(MailReadMessageTool(service: agentService), pluginID: id)
        tools?.add(MailSearchMessagesTool(service: agentService), pluginID: id)
        tools?.add(MailSendMessageTool(service: agentService), pluginID: id)

        kernel.resolveProvider((any ActivityBarProviding).self)?.addItems([
            ActivityBarItem(
                id: "\(id).entry",
                title: metadata.name,
                systemImage: "envelope",
                order: order,
                ownerPluginID: id
            ) { state in
                if state == .activated {
                    chat?.setVisible(false)
                    rootView?.setContentHeaderViewHidden(true)
                    contentView?.setContentView(
                        AnyView(
                            MailWorkspaceView(
                                sessionManager: sessionManager,
                                cache: cache
                            )
                        )
                    )
                    toolbar?.addToolbarItems([
                        ToolbarItem(
                            id: "\(pluginID).title",
                            title: self.metadata.name,
                            placement: .center,
                            category: .global,
                            order: 0
                        ) {
                            Text(self.metadata.name).font(.headline)
                        },
                    ])
                } else {
                    chat?.setVisible(true)
                    rootView?.setContentHeaderViewHidden(false)
                    toolbar?.removeToolbarItems(ids: ["\(pluginID).title"])
                    contentView?.setContentView(nil)
                }
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any SettingViewProviding).self)?
            .removeEntries(ids: ["\(id).settings"])
        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        let wasActive = activityBar?.activeItemID == "\(id).entry"
        activityBar?.removeItems(ids: ["\(id).entry"])
        if wasActive {
            kernel.resolveProvider((any ChatSectionProviding).self)?.setVisible(true)
            kernel.resolveProvider((any RootViewProviding).self)?.setContentHeaderViewHidden(false)
            kernel.resolveProvider((any ToolbarProviding).self)?
                .removeToolbarItems(ids: ["\(id).title"])
            kernel.resolveProvider((any ContentViewProviding).self)?.setContentView(nil)
        }
        let tools = kernel.resolveProvider((any ToolManagerProviding).self)
        tools?.remove(id: MailListMessagesTool.toolName)
        tools?.remove(id: MailReadMessageTool.toolName)
        tools?.remove(id: MailSearchMessagesTool.toolName)
        tools?.remove(id: MailSendMessageTool.toolName)
        Task {
            await sessionManager.disconnectAll()
        }
    }
}
