import Foundation
import KernelCore
import LumiLoggingKit
import os
import ProviderMessage
import ProviderMessageRendering
import ProviderStorage
import ProviderToolManager

/// 磁盘测速插件。
///
/// - `onBoot` 注册 `disk_speed_test` 工具到 `ToolManagerProviding`，
///   注册卡片渲染器到 `MessageRenderingProviding`，
///   并把消息管理器交给消息桥，让工具能在聊天区插入测速进度卡片；
/// - `onDisable` / `onShutdown` 撤回全部注册。
///
/// - Important: 内核在运行时禁用插件时只撤回它**显式登记**的贡献
///   （`trackContribution`），不会替插件清理 Provider 侧的写入。
///   因此工具与渲染器必须由本插件自己在 `onDisable` 里撤回，
///   否则插件在设置里显示「已禁用」后，LLM 仍能调用该工具、卡片也仍会渲染。
@MainActor
public final class DiskSpeedTestPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.disk-speed-test",
        category: "DiskSpeedTest"
    )

    public let id = "com.coffic.lumi.plugin.disk-speed-test"

    /// 插件加载顺序，同时也是卡片渲染器的优先级。
    ///
    /// 这个值必须高于核心渲染器的 `core-system-message`（base + 150 = 160）：
    /// 卡片消息是 `role = .system`，若优先级低于它就会被通用系统消息渲染器接管，
    /// 用户看到的是一行纯文本而不是卡片。
    public let order = 200

    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.disk-speed-test",
        name: pluginLocalization.string("Disk Speed Test"),
        description: pluginLocalization.string(
            "Measure disk sequential read and write speed, and show progress in the chat."
        ),
        category: .feature,
        stage: .preview,
        policy: .disabledByDefault
    )

    /// 当前是否已注册工具与渲染器。
    ///
    /// 用于让 `onEnable` 幂等：内核在「曾经 Boot 过再启用」时只调 `onEnable`，
    /// 而「启动时被跳过、首次启用」时会走完整的 `onBoot`。
    private var isRegistered = false

    /// 插入与更新卡片消息的桥。
    ///
    /// 做成插件的实例状态而非全局单例：多个内核并存时（测试进程里并排跑几个
    /// 内核就是这种情况）不会互相抢走消息管理器。
    private let bridge = DiskSpeedMessageBridge()

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        registerContributions(kernel: kernel)
    }

    /// 运行时重新启用：恢复工具与渲染器。
    ///
    /// 走这条路径说明插件曾经 Boot 过、贡献已被撤回，这里重新登记一次即可。
    public func onEnable(kernel: KernelCoreContainer) async throws {
        registerContributions(kernel: kernel)
    }

    /// 运行时禁用：撤回工具与渲染器。
    public func onDisable(kernel: KernelCoreContainer) async throws {
        unregisterContributions(kernel: kernel)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        unregisterContributions(kernel: kernel)
    }

    // MARK: - Contributions

    /// 登记工具、渲染器与消息桥。
    ///
    /// 幂等：重复调用不会重复注册。
    private func registerContributions(kernel: KernelCoreContainer) {
        guard !isRegistered else { return }
        isRegistered = true

        // 测速文件写在插件自己的数据目录，测完即删。
        //
        // 存储 Provider 缺失时不注册工具：没有目录就没有地方写临时文件，
        // 注册一个必然失败的工具只会让 LLM 反复调用并拿到错误。
        guard let storage = kernel.resolveProvider((any StorageProviding).self) else {
            Self.logger.error("\(Self.t)StorageProviding not found; disk speed test tool skipped")
            isRegistered = false
            return
        }
        let workingDirectory = storage
            .pluginDataDirectory(for: id)
            .appendingPathComponent("speedtest", isDirectory: true)

        if let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) {
            toolManager.add(
                DiskSpeedTestTool(
                    bridge: bridge,
                    workingDirectory: workingDirectory
                ),
                pluginID: id
            )
        } else {
            Self.logger.error("\(Self.t)ToolManagerProviding not found; disk speed test tool skipped")
        }

        // 注册卡片渲染器。order 由插件 order 派生，确保卡片消息不被通用渲染器接管。
        if let rendering = kernel.resolveProvider((any MessageRenderingProviding).self) {
            rendering.register(DiskSpeedCardRenderer.item(order: order))
            Self.logger.info("\(Self.t)Registered disk speed card renderer")
        } else {
            Self.logger.warning("\(Self.t)MessageRenderingProviding not found; card renderer skipped")
        }

        bridge.configure(
            messages: kernel.resolveProvider((any MessageManaging).self)
        )
    }

    /// 撤回工具、渲染器与消息桥。
    private func unregisterContributions(kernel: KernelCoreContainer) {
        guard isRegistered else { return }
        isRegistered = false

        kernel.resolveProvider((any MessageRenderingProviding).self)?
            .unregister(id: DiskSpeedTimeline.rendererID)
        bridge.reset()

        kernel.resolveProvider((any ToolManagerProviding).self)?
            .remove(id: DiskSpeedTestTool.toolName)
    }
}
