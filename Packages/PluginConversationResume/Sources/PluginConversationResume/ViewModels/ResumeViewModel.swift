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
    ///
    /// - Important: 这是**当前会话**的恢复状态，不是全局的（#888）。
    ///   旧实现是单个全局布尔，会话 A 恢复期间会把会话 B 的「继续」按钮
    ///   一起禁用。一次慢速或长期未结束的恢复不该阻塞其它会话的故障恢复。
    ///
    ///   这里的语义是「当前展示的这条横幅所属会话正在恢复」。
    @Published private(set) var isResuming = false

    /// 恢复动作的执行体。由插件入口注入。
    private let performResume: @MainActor () async -> Void

    init(performResume: @escaping @MainActor () async -> Void) {
        self.performResume = performResume
    }

    /// 应用协调器算出的状态。
    ///
    /// - Important: `isResuming` 由协调器按**会话**给出（#888），ViewModel
    ///   不再自己维护全局布尔 —— 那会让会话 A 的恢复禁用会话 B 的按钮。
    func apply(_ state: ResumeCoordinator.State) {
        isResumable = state.isResumable
        reason = state.reason
        isResuming = state.isResuming
    }

    /// 用户点击「继续」。
    ///
    /// - Important: 这里**不**自行置 `isResuming`。该标志由协调器按会话
    ///   驱动（#888），ViewModel 自行置位会在恢复结束时把它清掉，从而
    ///   抹掉协调器刚发布的「另一个会话正在恢复」状态。
    ///
    ///   重复点击由协调器按会话去重挡住：同一会话第二次点击会被
    ///   `resumingConversationIDs.insert` 直接拒绝，不会启动第二个回合。
    func resume() {
        guard isResumable, !isResuming else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            await performResume()
        }
    }
}
