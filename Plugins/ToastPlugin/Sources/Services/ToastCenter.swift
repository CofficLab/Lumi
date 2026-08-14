import Combine
import Foundation
import KernelLumi

/// `ToastProviding` 的实现:Toast 状态机。
///
/// 持有当前展示的 toast,默认 3 秒后自动消失(`LumiToast.duration` 可覆盖)。
/// 节流策略:新 toast 到达时取消上一个消失计时器并重启——连续高频调用
/// 不会堆叠成一串 toast,只会持续刷新当前这一条。
@MainActor
public final class ToastCenter: ObservableObject, ToastProviding {
    /// 当前显示的 toast;`nil` 表示不显示。
    @Published private(set) var currentToast: LumiToast?

    private var dismissTask: Task<Void, Never>?
    private static let defaultDisplayDuration: Duration = .seconds(3)

    public init() {}

    // MARK: - ToastProviding

    public func show(_ toast: LumiToast) {
        currentToast = toast

        // 重启消失计时器:实现"替换式"节流。
        dismissTask?.cancel()
        let duration = toast.duration.map { Duration.seconds($0) } ?? Self.defaultDisplayDuration
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.currentToast = nil
        }
    }

    /// 立即隐藏当前 toast(供测试与调试)。
    public func dismiss() {
        dismissTask?.cancel()
        currentToast = nil
    }
}
