import Combine
import Foundation

/// 「继续」提示条的展示状态。
///
/// ViewModel 只保存「当前会话能不能继续」这一件事；Provider 的观察由
/// `ResumeCoordinator` 持有，避免 ViewModel 与 Provider observer 生命周期耦合。
@MainActor
final class ResumeViewModel: ObservableObject {
    /// 当前会话是否可继续。
    @Published private(set) var isResumable = false
    /// 可继续的原因（展示文案）。
    @Published private(set) var reason = ""
    /// 是否正在执行恢复。
    @Published private(set) var isResuming = false

    /// 恢复动作的执行体。由插件入口注入。
    private let performResume: @MainActor () async -> Void

    init(performResume: @escaping @MainActor () async -> Void) {
        self.performResume = performResume
    }

    /// 应用协调器算出的状态。
    func apply(_ state: ResumeCoordinator.State) {
        isResumable = state.isResumable
        reason = state.reason
    }

    /// 设置恢复进行中状态。
    func setResuming(_ resuming: Bool) {
        isResuming = resuming
    }

    /// 用户点击「继续」。
    func resume() {
        guard isResumable, !isResuming else { return }
        isResuming = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            await performResume()
            isResuming = false
        }
    }
}
