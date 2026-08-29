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
    /// 当前选中供应商 / 模型变化（用户切换或注册表变化触发的回退）。
    case selectionChanged(providerID: String?, model: String?)
}

/// 供应商注册表变化的类型。
@MainActor
public enum ProviderChangeReason {
    case added
    case replaced
    case removed
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