import KernelCore
import LumiFactory
import ProviderChatSection
import ProviderConversation

/// ACP headless 专用内核工厂。
///
/// 装配流水线（预检 → 基线 Provider → 迁移 → 启动 → 接线）由共享引擎
/// `LumiFactory` 的 `KernelBootstrapper` / `KernelAssembler` 解释，本文件只声明
/// ACP 与兄弟 App 的差异。此前这里自己 new 容器、手动挂 `RootViewPlugin`、逐目录
/// 迁移再同步 `start(plugins:)`——与 GUI 那条路径长期漂移，兄弟 App 修好的启动
/// 时序（异步启动、fd 上限、磁盘预检、逐插件隔离迁移）ACP 一律享受不到。
@MainActor
public enum KernelFactory {
    private static let pluginManagerID = "com.coffic.lumi.plugin.plugin-manager"
    private static let toolManagerID = "com.coffic.lumi.plugin.tool-manager"

    public static func makeKernel(
        providerFactory: any ProviderFactory,
        pluginFactory: any PluginFactory
    ) async throws -> KernelCoreContainer {
        // 与 GUI 共用同一个启动器：fd 上限、磁盘预检、失败归因都在里面，
        // headless 只需要取它装配好的内核。
        let bootstrapper = KernelBootstrapper(
            manifest: makeManifest(providerFactory: providerFactory, pluginFactory: pluginFactory)
        )
        await bootstrapper.boot()
        guard let kernel = bootstrapper.kernel else {
            if case .failed(let report) = bootstrapper.state {
                throw ACPBootstrapError.kernelBootFailed(report)
            }
            throw ACPBootstrapError.kernelBootFailed(
                BootstrapFailureReport(
                    kind: .unknown,
                    technicalDetail: "Kernel boot returned without a ready kernel."
                )
            )
        }
        return kernel
    }

    /// ACP 的宿主清单：headless 不开窗口，因此跳过共享根视图接线。
    static func makeManifest(
        providerFactory: any ProviderFactory,
        pluginFactory: any PluginFactory
    ) -> HostManifest {
        HostManifest(
            identity: HostIdentity(
                appName: "Lumi ACP",
                loggerSubsystem: "com.coffic.lumi",
                mainWindowID: "lumi.main",
                settingsWindowID: "lumi.settings",
                accessibilityPrefix: "lumi"
            ),
            makePlugins: {
                pluginFactory.makePlugins()
            },
            storage: HostStorageConfiguration(
                stateStorePluginID: pluginManagerID,
                legacyDirectoryMigrations: [
                    pluginManagerID: ["PluginManager"],
                    toolManagerID: ["ToolManager"],
                ]
            ),
            legacyPluginIDAliases: DefaultProviderFactory.pluginIDAliases,
            // 根视图由宿主拥有：装配流水线以 host provider 注册，不再套一层插件。
            makeRootViewProvider: {
                providerFactory.makeRootViewProvider()
            },
            registerProviders: { kernel in
                try providerFactory.registerProviders(into: kernel)
            },
            wireKernel: { kernel in
                // 会话由插件替换（PluginConversationManager）后才绑定，
                // 否则聊天区会盯在被替换掉的内存实现上。
                guard let chat = kernel.resolveProvider((any ChatSectionProviding).self),
                      let conversations = kernel.resolveProvider((any ConversationManaging).self)
                else { return }
                chat.bindConversationSelection(conversations)
            },
            features: HostFeatures(
                opensMainWindowOnLaunch: false,
                suppressesMainWindowOnLaunch: true,
                showsSettingsToolbarButton: false,
                skipsSharedRootViewWiring: true
            )
        )
    }
}
