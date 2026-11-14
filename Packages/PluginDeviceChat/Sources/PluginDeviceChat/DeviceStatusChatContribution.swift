import KernelCore
import LumiLoggingKit
import PluginDevice
import ProviderMessage
import ProviderMessageRendering
import ProviderToolManager
import os

/// Lumi 宿主的设备插件对话贡献。
///
/// 共享的 `PluginDevice` 远程包只负责指标采集与菜单栏展示；把设备状态卡片
/// 投递进聊天区依赖 Lumi 自己的消息契约，因此由本包实现
/// ``DeviceChatContributing`` 并在装配时注入。
@MainActor
public final class DeviceStatusChatContribution: DeviceChatContributing, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: DeviceConfiguration.loggerSubsystem,
        category: "DeviceStatusChatContribution"
    )

    /// 设备状态卡片渲染器的优先级。
    ///
    /// 必须高于核心渲染器的 `core-system-message`（base + 150 = 160）：
    /// 卡片消息是 `role = .system`，若优先级低于它就会被通用系统消息渲染器接管，
    /// 用户看到的是一行纯文本而不是卡片。
    ///
    /// 取 190 而非 200，是为了与同样用 200 的 Finder / HTMLCanvas / DiskSpeed
    /// 卡片渲染器错开，避免顺序相同的渲染器之间出现不确定的命中顺序。
    public static let cardRendererOrder = 190

    /// 插入设备状态卡片消息的桥。
    ///
    /// 做成实例状态而非全局单例：多个内核并存时（测试进程里并排跑几个内核
    /// 就是这种情况）不会互相抢走消息管理器。
    private let messageBridge = DeviceStatusMessageBridge()

    /// 已登记的宿主插件标识；非 nil 表示当前已注册。
    private var registeredPluginID: String?

    public init() {}

    /// 登记工具、渲染器与消息桥。幂等：重复调用不会重复注册。
    public func register(
        kernel: KernelCoreContainer,
        pluginID: String,
        collector: DeviceStatusCollector
    ) {
        guard registeredPluginID == nil else { return }
        registeredPluginID = pluginID

        if let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            toolManager.add(
                DeviceStatusTool(bridge: messageBridge, collector: collector),
                pluginID: pluginID
            )
        } else {
            Self.logger.error("\(Self.t)ToolManagerProviding not found; device status tool skipped")
        }

        if let rendering = kernel.resolveProvider((any MessageRenderingProviding).self) {
            rendering.register(DeviceStatusCardRenderer.item(order: Self.cardRendererOrder))
        } else {
            Self.logger.warning("\(Self.t)MessageRenderingProviding not found; card renderer skipped")
        }

        messageBridge.configure(
            messages: kernel.resolveProvider((any MessageManaging).self)
        )
    }

    /// 撤回工具、渲染器与消息桥。未注册时为空操作。
    public func unregister(kernel: KernelCoreContainer) {
        guard registeredPluginID != nil else { return }
        registeredPluginID = nil

        kernel.resolveProvider((any MessageRenderingProviding).self)?
            .unregister(id: DeviceStatusTimeline.rendererID)
        messageBridge.reset()

        kernel.resolveProvider((any ToolManagerProviding).self)?
            .remove(id: DeviceStatusTool.toolName)
    }
}

/// 本包内共享的品牌常量：与共享包的默认配置保持同一插件标识。
private enum DeviceConfiguration {
    static let loggerSubsystem = DevicePluginConfiguration.defaultLoggerSubsystem
}
