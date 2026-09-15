import Foundation

/// LLM 供应商/模型状态变更事件。
///
/// 与其它 Providing 的 typed event 机制一致：消费者通过 `addObserver` 注册
/// 回调，收到精准的“谁变了、为什么变”，避免只用 `objectWillChange`
/// 粗粒度通知导致的不必要刷新与歧义。
@MainActor
public enum LLMManagerEvent {
    /// 供应商注册表变化：新增 / 覆盖 / 注销。
    case providersChanged(providerID: String, reason: ProviderChangeReason)
    /// 当前选中供应商 / 模型变化；`reason` 说明本次变更的触发来源。
    case selectionChanged(providerID: String?, model: String?, reason: ModelSelectionReason)
}

/// 供应商注册表变化的类型。
@MainActor
public enum ProviderChangeReason {
    case added
    case replaced
    case removed
}

/// 切换当前选中模型的原因。
///
/// 由 `LLMManaging.select(...)` 传入，随 `LLMManagerEvent.selectionChanged`
/// 透传给观察者，便于区分「用户主动切换」与「系统 / 会话联动引起的回退」。
public enum ModelSelectionReason: Sendable, Equatable {
    /// 用户在模型选择器 / 供应商设置页主动选择。
    case userSelected
    /// 切换对话时跟随该会话绑定的模型同步。
    case conversationSwitch
    /// 供应商注册 / 注销导致选中态回退到可用模型。
    case providerChanged
    /// 应用启动时从持久化存储恢复上一次选中。
    case appRestore
}

/// LLM 供应商管理器观察句柄。
@MainActor
public protocol LLMManagerObserverHandle: AnyObject {
    func cancel()
}

public extension LLMManaging {
    /// 注册 LLM 供应商/模型状态观察者。默认实现为空，保持自定义实现兼容。
    @discardableResult
    func addObserver(
        _ callback: @escaping (LLMManagerEvent) -> Void
    ) -> any LLMManagerObserverHandle {
        NoopLLMManagerObserverHandle()
    }
}

@MainActor
private final class NoopLLMManagerObserverHandle: LLMManagerObserverHandle {
    func cancel() {}
}