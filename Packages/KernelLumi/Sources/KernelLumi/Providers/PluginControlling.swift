import Combine
import Foundation

/// 插件启用控制能力协议
///
/// 定义「启用 / 禁用插件」的最小契约：运行时切换（`onEnable` / `onDisable`）+
/// 持久化用户意图 + 全量重建插件贡献，三者由实现方一次完成。消费方（如空态提示词
/// 视图）只需调用 `enablePlugin(id:)` 即可在点击禁用插件的提示词时「启用并发送」。
///
/// 由 `PluginManagerPlugin` 提供实现 `PluginController` 并注册到内核。
/// `ObjectWillChangePublisher == ObservableObjectPublisher` 约束与
/// `MessageSending` / `PromptSuggestionProviding` 一致，用于让协议存在类型
/// （`any PluginControlling`）的 `objectWillChange` 可被订阅。
@MainActor
public protocol PluginControlling: ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    /// 启用指定插件。
    ///
    /// 完成运行时启用（含 `onEnable`）、持久化用户覆盖，并在返回前同步重建插件贡献，
    /// 确保该插件贡献的 Agent Tools / UI / 提示词等在调用返回后立即可用。
    ///
    /// - Parameters:
    ///   - id: 插件 ID。
    /// - Returns: 是否成功。`alwaysOn` / 已启用视为成功（`true`）；`disabled` 策略或
    ///   生命周期钩子失败时返回 `false`。
    func enablePlugin(id: String) async -> Bool

    /// 禁用指定插件。
    ///
    /// 完成运行时禁用（含 `onDisable`）、持久化用户覆盖，并在返回前同步重建插件贡献，
    /// 确保被禁用插件的贡献即时撤回。
    ///
    /// - Parameters:
    ///   - id: 插件 ID。
    /// - Returns: 是否成功。`disabled` / 已禁用视为成功（`true`）；`alwaysOn` 策略或
    ///   生命周期钩子失败时返回 `false`。
    func disablePlugin(id: String) async -> Bool
}
