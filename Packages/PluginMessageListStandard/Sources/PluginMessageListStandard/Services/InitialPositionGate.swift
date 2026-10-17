import Foundation
import Combine

/// 首屏就绪判定的编排策略（从 `ListV2View` 抽出以便测试）。
///
/// ## 背景
///
/// 消息列表在首屏定位完成前会盖一层遮罩（`isLoading || !isInitialPositionReady`）。
/// 原先这个判定直接写在 View 里：它 `await` 一个可能失败的收敛过程，失败时
/// `isInitialPositionReady` 保持 false，遮罩**永久挂起**，且没有任何重试或
/// 超时兜底。用户在界面上只能看到「正在加载消息…」一直不消失。
///
/// 这里把判定提炼为可测单元：收敛过程由调用方注入，本类型只负责
/// 「何时算就绪」以及**超时兜底**——无论收敛成功与否，超过预算都必须放行，
/// 否则任何收敛失败都会变成永久卡死。
@MainActor
final class InitialPositionGate {
    /// 收敛过程的预算上限。超时后强制视为就绪。
    private let budgetNanoseconds: UInt64

    /// 首屏是否就绪。必须 `@Published`：遮罩的显示条件依赖它，
    /// 非发布属性变化不会触发 SwiftUI 重绘，遮罩将永不消失。
    @Published private(set) var isReady = false
    private(set) var isPreparing = false

    /// 记录当前正在等待的会话；切换会话必须让上一轮的等待失效。
    private var pendingConversationID: UUID?

    private var task: Task<Void, Never>?

    init(budgetNanoseconds: UInt64 = 3_000_000_000) {
        self.budgetNanoseconds = budgetNanoseconds
    }

    /// 当前等待中的会话 id；用于观察失效与竞态。
    var awaitingConversationID: UUID? { pendingConversationID }

    /// 请求为首屏定位。同一时间只允许一轮进行中。
    ///
    /// - Parameters:
    ///   - conversationID: 本轮等待对应的会话；切��会让本轮失效。
    ///   - settle: 真正的收敛过程（返回 true 表示成功收敛）。
    ///   - stillRelevant: 判定本轮是否仍然有效（如会话未被换掉、仍在加载）。
    /// - Returns: 是否真的启动了新一轮（false 表示被去重或被忽略）。
    @discardableResult
    func request(
        conversationID: UUID?,
        settle: @escaping @MainActor () async -> Bool,
        stillRelevant: @escaping @MainActor () -> Bool
    ) -> Bool {
        // 已有同会话在等待 → 去重，避免并发多轮收敛互相取消。
        if isPreparing, pendingConversationID == conversationID { return false }
        // 会话已切换且当前轮属于旧会话 → 作废，重新开始。
        if isPreparing, pendingConversationID != conversationID {
            task?.cancel()
            isPreparing = false
        }
        guard conversationID != nil else {
            // 没有选中会话：无需定位，直接就绪。
            task?.cancel()
            isReady = true
            isPreparing = false
            pendingConversationID = nil
            return true
        }

        isPreparing = true
        isReady = false
        pendingConversationID = conversationID

        task = Task { @MainActor [weak self] in
            guard let self else { return }
            // 竞态跑：收敛过程与超时兜底并行，谁先结束听谁的。
            let settled = Task { @MainActor in await settle() }
            let timeout = Task { @MainActor in
                try? await Task.sleep(nanoseconds: self.budgetNanoseconds)
            }

            // - Important: 超时到达后**不能**再 `await settled.value`。
            //   收敛过程可能永不返回（List 几何一直不收敛）；此时 await 会把
            //   兜底本身也一起挂住，遮罩依旧永久不消失 —— 正是要修的症状。
            //   超时即代表「预算耗尽」，直接按兜底结果放行并取消收敛任务。
            _ = await timeout.value
            let timedOut = timeout.isCancelled == false
            if timedOut {
                settled.cancel()
            }
            let settledSuccessfully = timedOut ? false : await settled.value

            guard conversationID == self.pendingConversationID,
                  stillRelevant() else {
                self.isPreparing = false
                return
            }
            // Note: 收敛失败（settled 返回 false）时同样放行。首屏遮罩只应
            //   遮住「位置明显不对」的一瞬；用户更需要一个能滚动、可能位置
            //   稍有偏差的列表，而不是永久的加载态。
            self.isReady = timedOut || settledSuccessfully
            self.isPreparing = false
            self.task = nil
        }
        return true
    }

    /// 会话切换时复位：作废当前等待并撤销就绪状态。
    func resetForConversationSwitch() {
        task?.cancel()
        task = nil
        isPreparing = false
        isReady = false
        pendingConversationID = nil
    }

    /// 加载开始时复位（用于切换会话后重新进入 loading）。
    func resetForLoadingStart() {
        resetForConversationSwitch()
    }

    deinit {
        task?.cancel()
    }
}
