import Foundation
import KernelLumi

/// `PluginControlling` 能力的实现：统一封装「运行时启停 + 持久化 + 重建贡献」。
///
/// 由 `PluginManagerPlugin` 在 `onBoot` 中创建并注册到内核，供空态提示词等 UI 通过
/// `kernel.pluginControl` 调用——典型场景是用户点击「禁用插件」贡献的提示词时，
/// 先 `enablePlugin(id:)` 启用该插件，再发送消息。
///
/// 相比直接调用 `PluginManager.setPluginEnabled`（仅运行时，且依赖 `.lumiEnabledPluginsDidChange`
/// 通知在下一个 run loop 触发异步重建），本实现额外做了两件事：
/// 1. 落盘持久化用户覆盖（跨重启保留）；
/// 2. **在返回前同步执行 `rebuildAllContributions`**，确保被启用插件的 Agent Tools /
///    UI / 提示词等贡献在调用返回后立即可用，避免「启用后立即发送」抢跑重建。
@MainActor
final class PluginController: ObservableObject, PluginControlling {
    private weak var kernel: KernelLumi?
    private let store: PluginEnabledStateStore

    init(kernel: KernelLumi, store: PluginEnabledStateStore) {
        self.kernel = kernel
        self.store = store
    }

    /// 核心切换逻辑（运行时 + 持久化 + 同步重建）。供 enable/disable 复用。
    @discardableResult
    func setEnabled(id: String, enabled: Bool) async -> Bool {
        guard let kernel else { return false }
        let pluginManager = kernel.pluginManager
        guard pluginManager.plugin(id: id)?.policy.isConfigurable == true else { return false }
        // 已处于目标状态视为成功（避免重复 onEnable/onDisable 与无谓重建）。
        if pluginManager.isPluginEnabled(id: id) == enabled { return true }

        // setPluginEnabled 内部会 await onEnable/onDisable，并 post 异步重建通知。
        guard await pluginManager.setPluginEnabled(id: id, enabled: enabled) else { return false }
        store.savePluginEnabledOverride(enabled, for: id)

        // 同步重建，保证调用返回时该插件的贡献已注册/撤回。
        // 通知触发的异步重建随后会再跑一次，幂等无害。
        pluginManager.rebuildAllContributions(in: kernel)
        return true
    }

    func enablePlugin(id: String) async -> Bool {
        await setEnabled(id: id, enabled: true)
    }

    func disablePlugin(id: String) async -> Bool {
        await setEnabled(id: id, enabled: false)
    }
}
