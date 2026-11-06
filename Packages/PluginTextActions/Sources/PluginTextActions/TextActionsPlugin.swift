import Foundation
import KernelCore
import ProviderDocsView
import ProviderLLMManager
import ProviderSettingView
import ProviderStorage
import LumiLoggingKit
import os

/// KernelCore lifecycle for the global selected-text action menu.
@MainActor
public final class TextActionsPlugin: SuperPlugin, PluginDataMigrating, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.text-actions", category: "TextActions")
    public let id = "com.coffic.lumi.plugin.text-actions"
    public let order = 275
    public let metadata = PluginMetadata(id: "com.coffic.lumi.plugin.text-actions", name: pluginLocalization.string("Text Actions"), description: pluginLocalization.string("Show copy, search, and translation actions for selected text in other macOS apps."), category: .system, stage: .preview, policy: .enabledByDefault)

    /// 历史实现把开关存在 `UserDefaults.standard`，未使用插件专属目录。
    /// 目录名未变过，无需版本根搬迁。
    public let legacyDataDirectoryNames: [String] = []

    /// 辅助功能权限状态，由设置页共享。
    ///
    /// 授权状态会在应用之外变化（系统授权弹窗、系统设置里的开关），
    /// 只能靠「应用重新激活」来重新读取。该监听随本对象生命周期存在，
    /// 因此状态对象必须由插件持有，而不是由设置页临时创建。
    private var permissionState: TextActionsPermissionState?

    /// 选区监听的启停入口。
    ///
    /// - Important: 注入点而非直接调用 `TextSelectionManager.shared`。
    ///   「冷启动有没有启动监听」正是本插件最关键的行为，而它必须能被
    ///   单测**直接断言**——否则就只能靠人工划词来验证，
    ///   回归时无人能察觉监听又没起来。
    private let selectionMonitor: any TextSelectionMonitoring

    /// 划词功能自身是否开启（与插件是否启用是两件事）。
    ///
    /// - Important: 同样是注入点。直接读全局单例会让用例受
    ///   **其它用例留下的目录状态**影响——`TextActionsPluginLocalStore.shared`
    ///   在首次访问时就把目录固化了，后续用例换目录也不会生效。
    ///   那种失败表现为「断言随机翻转」，极难归因。
    private let isFeatureEnabled: () -> Bool

    public init() {
        self.selectionMonitor = TextSelectionManager.shared
        self.isFeatureEnabled = { TextActionsSettings.isEnabled }
    }

    /// 注入选区监听与开关读取（供单测使用）。
    init(selectionMonitor: any TextSelectionMonitoring, isFeatureEnabled: @escaping () -> Bool) {
        self.selectionMonitor = selectionMonitor
        self.isFeatureEnabled = isFeatureEnabled
    }

    /// 读取旧版开关所在的 UserDefaults 域。
    ///
    /// 抽成可替换的入口，便于单测注入假域：测试进程里 `Bundle.main`
    /// 是 xctest 可执行文件（没有 bundle identifier），拿不到 app 的持久化域。
    nonisolated(unsafe) static var legacyDefaultsDomainProvider: () -> [String: Any]? = {
        UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
    }

    /// 把 `UserDefaults.standard` 中的旧开关导入插件专属存储。
    ///
    /// 仅在插件存储尚无该键时导入，避免覆盖用户后续在设置页的修改。
    /// `UserDefaults` 原 key 保留，便于回退。
    public func migrateData(context: PluginDataMigrationContext) throws {
        let key = "TextActions.enabled"
        guard let domain = Self.legacyDefaultsDomainProvider(),
              let legacyValue = domain[key] as? Bool
        else {
            return
        }

        let directory = context.currentPluginDataDirectory
        let store = TextActionsPluginLocalStore(settingsDirectory: directory)
        guard store.object(forKey: key) == nil else { return }
        store.set(legacyValue, forKey: key)
        Self.logger.info("\(Self.t)Imported legacy TextActions.enabled from UserDefaults: \(legacyValue)")
    }

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: metadata.name) { TextActionsAboutView() })
            docs.addManual(DocsEntry(id: id, name: metadata.name) { TextActionsManualView() })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        // 存储目录注入必须早于 TextActionsPluginLocalStore.shared 的首次访问。
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            TextActionsRuntime.configure(settingsDirectory: storage.pluginDataDirectory(for: id))
        }
        if let llm = kernel.resolveProvider((any LLMManaging).self) { TextActionMenuController.shared.configure(translationProvider: llm) }
        // 权限状态由插件持有，设置页只读它——授权状态在应用外部变化
        // （系统弹窗、系统设置开关），只有插件级对象能持续监听到。
        let permissionState = TextActionsPermissionState()
        // 用户在系统设置里打开权限后，必须补启动选区监听，否则划词功能
        // 仍然不工作，且没有任何报错。
        permissionState.onPermissionGranted = { [weak self] in
            guard let self, self.isFeatureEnabled() else { return }
            self.selectionMonitor.startMonitoring()
        }
        self.permissionState = permissionState
        kernel.resolveProvider((any SettingViewProviding).self)?.addEntries([SettingEntryItem(id: id, title: metadata.name, systemImage: "text.cursor", order: order) { TextActionsSettingsView(permissionState: permissionState) }])
    }

    public func onReady(kernel: KernelCoreContainer) throws {
        // 划词监听必须在**冷启动**时就能起来。
        //
        // - Important: 内核启动流程只调用 `onBoot` / `onReady`，**从不调用
        //   `onEnable`**——`onEnable` 只在用户于插件管理面板当场把开关
        //   从关打到开时触发。若把启动逻辑只挂在 `onEnable` 上，
        //   「插件已启用 → 重启 App → 划词」这条最常见的路径就永远不工作，
        //   且既不报错也不弹菜单，用户完全无从判断原因。
        //
        // 因此启动监听放在 `onReady`（每个被启用的插件都会走），
        // `onEnable` 保留为「运行时重新启用」的兜底路径。
        startSelectionMonitoringIfNeeded()
    }

    public func onEnable(kernel: KernelCoreContainer) async throws {
        startSelectionMonitoringIfNeeded()
    }

    /// 在插件自身开关开启且已获辅助功能授权时启动选区监听。
    ///
    /// 幂等：`TextSelectionManager.startMonitoring()` 自身短路重复注册，
    /// 因此「冷启动 + 运行时重新启用 + 权限回调」三条路径都走这里也安全。
    private func startSelectionMonitoringIfNeeded() {
        guard isFeatureEnabled() else { return }
        selectionMonitor.startMonitoring()
    }

    public func onDisable(kernel: KernelCoreContainer) async throws {
        selectionMonitor.stopMonitoring()
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        selectionMonitor.stopMonitoring()
        kernel.resolveProvider((any SettingViewProviding).self)?.removeEntries(ids: [id])
        // 摘掉权限状态的应用激活监听，并释放状态对象。
        permissionState?.stop()
        permissionState = nil
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }
}
