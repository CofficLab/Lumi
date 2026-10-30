import Foundation
import KernelCore
import ProviderSettingView
import ProviderContentView
import ProviderRailView
import ProviderChatSection
import ProviderRootView
import ProviderToolbar
import ProviderActivityBar
import ProviderToolManager
import ProviderStorage
import KitMail
import SwiftUI
import os
import LumiLoggingKit

/// PluginMail 插件入口。
///
/// 职责：
/// - 解析 `StorageProviding` 得到插件数据目录，装配账户存储 / 偏好存储 / 缓存；
/// - 注册「邮件账户」设置入口（账户 CRUD / 连接测试 / 删除）；
/// - 装配 ActivityBar 入口：激活时切换三栏工作区并隐藏 chat、加工具栏标题，
///   还原时全部撤销（参照 DatabaseManagerPlugin 对称写法）；
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

    // MARK: - 依赖装配

    /// 装配时解析到的存储 Provider；`onShutdown` 置空以打破引用环。
    private var storageProvider: (any StorageProviding)?

    /// 插件数据目录。优先用 Provider 解析出的版本化目录。
    ///
    /// - Important: 所有 lazy 属性都读它，所以 `onBoot` 必须**先**给
    ///   `storageProvider` 赋值，再触碰任何 lazy 属性。
    private var dataDirectory: URL {
        storageProvider?.pluginDataDirectory(for: id)
            ?? MailPluginRuntime.fallbackDataDirectory()
    }

    /// 账户配置存储（插件数据目录内的 accounts.plist + 系统 Keychain 密码）。
    ///
    /// - Note: 构造时会触发旧版 `UserDefaults` 账户配置的一次性迁移。
    public private(set) lazy var accountStore = MailAccountStore(directory: dataDirectory)

    /// UI 级偏好存储（插件数据目录内的 preferences.plist）。
    public private(set) lazy var localStore = MailPluginLocalStore(directory: dataDirectory)

    /// 本地缓存（SwiftData，插件数据目录）。
    public lazy var cacheService = MailCacheService(databaseDirectory: dataDirectory)

    /// 会话池（懒连接 / 断线重连 / onShutdown 全断）。
    public lazy var sessionManager = MailSessionManager(
        factory: MailCoreAdapterFactory(),
        accountStore: accountStore
    )

    /// 发送编排。
    public lazy var composerService = MailComposerService(
        sessionManager: sessionManager,
        accountStore: accountStore
    )

    /// Agent 工具服务。
    public lazy var agentToolService = MailAgentToolService(
        sessionManager: sessionManager,
        cache: cacheService,
        composer: composerService,
        accountStore: accountStore
    )

    public init() {}

    // MARK: - 生命周期

    public func onBoot(kernel: KernelCoreContainer) throws {
        // 先解析存储 Provider：其余 lazy 属性都依赖 dataDirectory。
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            storageProvider = storage
        } else {
            Self.logger.warning(
                "\(self.t)StorageProviding 未注册，邮件数据将写入兜底目录 \(MailPluginRuntime.fallbackDataDirectory().path, privacy: .public)"
            )
        }

        let sessionManager = self.sessionManager
        let accountStore = self.accountStore
        let cache = cacheService

        kernel.resolveProvider((any SettingViewProviding).self)?.addEntries([
            SettingEntryItem(
                id: "\(id).settings",
                title: pluginLocalization.string("Mail"),
                systemImage: "envelope",
                order: order
            ) {
                MailSettingsView(sessionManager: sessionManager, accountStore: accountStore)
            },
        ])

        // Agent 工具注册。
        let tools = kernel.resolveProvider((any ToolManagerProviding).self)
        let agentService = agentToolService
        tools?.add(MailListMessagesTool(service: agentService), pluginID: id)
        tools?.add(MailReadMessageTool(service: agentService), pluginID: id)
        tools?.add(MailSearchMessagesTool(service: agentService), pluginID: id)
        tools?.add(MailSendMessageTool(service: agentService), pluginID: id)

        // ActivityBar 入口：激活/还原对称装配。
        let contentView = kernel.resolveProvider((any ContentViewProviding).self)
        let chat = kernel.resolveProvider((any ChatSectionProviding).self)
        let rootView = kernel.resolveProvider((any RootViewProviding).self)
        let railView = kernel.resolveProvider((any RailViewProviding).self)
        let toolbar = kernel.resolveProvider((any ToolbarProviding).self)
        let pluginID = id

        kernel.resolveProvider((any ActivityBarProviding).self)?.addItems([
            ActivityBarItem(
                id: "\(id).entry",
                title: metadata.name,
                systemImage: "envelope",
                order: order,
                ownerPluginID: id
            ) { state in
                if state == .activated {
                    // 工作区自带三栏（文件夹树侧栏），不依赖宿主 RailView：激活时移除。
                    rootView?.setRailView(nil)
                    chat?.setVisible(false)
                    rootView?.setContentHeaderViewHidden(true)
                    contentView?.setContentView(
                        AnyView(
                            MailWorkspaceView(
                                sessionManager: sessionManager,
                                cache: cache,
                                accountStore: accountStore,
                                dataDirectory: self.dataDirectory
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
                    // 还原：重建宿主 RailView（若其它插件有可见 tab）。
                    rootView?.setRailView(railView?.makeRailView())
                    rootView?.setRailViewVisible(railView?.hasVisibleTabs ?? false)
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
            let railView = kernel.resolveProvider((any RailViewProviding).self)
            let rootView = kernel.resolveProvider((any RootViewProviding).self)
            rootView?.setRailView(railView?.makeRailView())
            rootView?.setRailViewVisible(railView?.hasVisibleTabs ?? false)
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

        storageProvider = nil
        Task {
            await sessionManager.disconnectAll()
        }
    }
}
