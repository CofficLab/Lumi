import Foundation
import KernelCore
import ProviderToast
import KitSuperLog
import os

// MARK: - Toast SuperPlugin

/// Toast 插件：实现 `ToastProviding` 能力。
///
/// 在 `onBoot` 中注册 `ToastCenter`（替换式节流 + 自动消失）。
/// 任何持有内核的代码可通过 `kernel.resolveProvider((any ToastProviding).self)?.show(...)` 发出提示。
@MainActor
public final class ToastSuperPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.toast", category: "Toast")
    public let id = "com.coffic.lumi.plugin.toast"
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.toast",
        name: "Toast Super",
        description: "",
        category: .core,
        stage: .stable,
        policy: .alwaysOn
    )


    /// Toast 状态机，由根覆盖层订阅渲染。
    public let center = ToastCenter()

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        kernel.unregisterProvider((any ToastProviding).self)
        try kernel.registerProvider((any ToastProviding).self, center)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        center.dismiss()
    }
}

// MARK: - ToastCenter

/// `ToastProviding` 的实现：Toast 状态机。
///
/// 持有当前展示的 toast，默认 3 秒后自动消失。
/// 节流策略：新 toast 到达时取消上一个消失计时器并重启——连续高频调用
/// 不会堆叠成一串 toast，只会持续刷新当前这一条。
@MainActor
public final class ToastCenter: ToastProviding {
    /// 当前显示的 toast；`nil` 表示不显示。
    public private(set) var currentToast: LumiToast?
    private var observers: [UUID: (ToastProvidingEvent) -> Void] = [:]

    private var dismissTask: Task<Void, Never>?
    private static let defaultDisplayDuration: Duration = .seconds(3)

    public init() {}

    @discardableResult
    public func addObserver(
        _ callback: @escaping (ToastProvidingEvent) -> Void
    ) -> any ToastProvidingObserverHandle {
        let id = UUID()
        observers[id] = callback
        return ObserverHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    // MARK: - ToastProviding

    public func show(_ toast: LumiToast) {
        currentToast = toast
        notify(.currentToastChanged(toast))

        // 重启消失计时器：实现"替换式"节流。
        dismissTask?.cancel()
        let duration = toast.duration.map { Duration.seconds($0) } ?? Self.defaultDisplayDuration
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.currentToast = nil
        }
    }

    /// 立即隐藏当前 toast（供测试与调试）。
    public func dismiss() {
        dismissTask?.cancel()
        guard currentToast != nil else { return }
        currentToast = nil
        notify(.currentToastChanged(nil))
    }

    private func notify(_ event: ToastProvidingEvent) {
        observers.values.forEach { $0(event) }
    }

    private final class ObserverHandle: ToastProvidingObserverHandle {
        private var cancellation: (() -> Void)?

        init(cancellation: @escaping () -> Void) {
            self.cancellation = cancellation
        }

        func cancel() {
            cancellation?()
            cancellation = nil
        }
    }
}
