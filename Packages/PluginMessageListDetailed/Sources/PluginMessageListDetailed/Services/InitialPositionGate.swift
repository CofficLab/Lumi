import Foundation
import Combine
import SwiftUI

/// 首屏就绪判定的编排策略（从 `ListV3View` 抽出以便测试）。
///
/// ## 背景
///
/// 消息列表在首屏定位完成前会盖一层遮罩。原先这个判定直接写在 View 里：
/// 它 `await` 一个可能失败的收敛过程，失败时 `isInitialPositionReady` 保持
/// false，遮罩**永久挂起**，且没有任何重试或超时兜底。用户在界面上只能看到
/// 「正在加载消息…」一直不消失。
///
/// 这里把判定提炼为可测单元：收敛过程由调用方注入，本类型只负责
/// 「何时算就绪」以及**超时兜底**——收敛挂死时超过预算必须强制放行，
/// 否则任何收敛失败都会变成永久卡死。
///
/// ## 两条不可让步的不变式
///
/// 1. **遮罩的寿命有确定上界。**
///    兜底计时器与「收敛轮次是否被启动」**解耦**：遮罩一旦挂起（加载开始 /
///    会话切换复位），预算计时就已经开始；即便之后没有任何一轮收敛被启动
///    （加载卡住、请求被去重挡掉……），遮罩也必须在预算内落下。
///    兜底若挂在收敛轮次上，遮罩就会在「没有任何东西在推进它」时永久挂起。
/// 2. **失效的一轮不得把门禁焊死。**
///    一轮收敛若因「会话被换掉 / 又进入加载」而失效，它既不置为就绪，
///    也必须**释放准备状态**；否则同一会话的后续请求会被去重挡掉，
///    再没有任何一轮收敛能启动——遮罩永远落不下来。
///
/// - Important: 必须继承 `ObservableObject`。`isReady` 是 `@Published`，
///   遮罩的显示条件依赖它；缺少 `ObservableObject` 就不会产生
///   `objectWillChange`，属性变化无法触发 SwiftUI 重绘。
/// - Important: 必须由 View 以 `@StateObject` 持有。本类型是引用类型且
///   有生命周期（等待中的 Task、取消语义），`let` 属性会在 View 每次 init
///   时重新构造 —— 新实例 `isReady` 恒为 false，旧实例立即释放使 Task 内
///   `weak self` 落空，遮罩将永久不消失，且超时兜底也随之失效。
@MainActor
final class InitialPositionGate: ObservableObject {
    /// 遮罩挂起后的预算上限。
    ///
    /// 语义是「从**遮罩被挂起那一刻**起算的绝对时长」：预算**包含**任务在
    /// 主线程队列上的排队时间。若把它当成「任务真正跑起来后才计时的时长」，
    /// 主线程被占用时用户的实际等待会变成「阻塞时长 + 完整预算」。
    private let budgetNanoseconds: UInt64

    /// 首屏是否就绪。必须 `@Published`：遮罩的显示条件依赖它，
    /// 非发布属性变化不会触发 SwiftUI 重绘，遮罩将永不消失。
    @Published private(set) var isReady = false
    private(set) var isPreparing = false

    /// 记录当前正在等待的会话；切换会话必须让上一轮的等待失效。
    private var pendingConversationID: UUID?

    /// 收敛轮次。
    private var task: Task<Void, Never>?

    /// 兜底放行计时器：遮罩挂起后必须在预算内落下，**与收敛是否启动无关**。
    private var deadlineTask: Task<Void, Never>?

    /// 轮次序号：在飞轮次回来时若序号已变，说明它已被新一轮取代，
    /// 不得再改动任何状态。
    private var roundGeneration: UInt64 = 0

    init(budgetNanoseconds: UInt64 = 3_000_000_000) {
        self.budgetNanoseconds = budgetNanoseconds
    }

    /// 当前等待中的会话 id；用于观察失效与竞态。
    var awaitingConversationID: UUID? { pendingConversationID }

    /// 请求为首屏定位。同一时间只允许一轮进行中。
    ///
    /// - Parameters:
    ///   - conversationID: 本轮等待对应的会话；切换会让本轮失效。
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
            deadlineTask?.cancel()
            deadlineTask = nil
            isReady = true
            isPreparing = false
            pendingConversationID = nil
            return true
        }

        isPreparing = true
        isReady = false
        pendingConversationID = conversationID
        roundGeneration &+= 1
        let generation = roundGeneration

        // Important: 兜底必须与「收敛是否被启动」解耦。遮罩此刻已经挂起，
        //   若没有任何东西在推进它，它就必须自己到点落下。
        //   已有更早的截止时刻时不延长它 —— 遮罩的寿命上界从**首次挂起**起算。
        armDeadlineIfNeeded()

        task = Task { @MainActor [weak self] in
            guard let self else { return }

            // Note: 收敛的**返回值**不参与放行判定。
            //   收敛成功、收敛失败、收敛挂死（由兜底计时器兜住）三条路径都会
            //   放行遮罩：首屏遮罩只应遮住「位置明显不对」的一瞬；用户更需要
            //   一个能滚动、可能位置稍有偏差的列表，而不是永久的加载态。
            //
            // Important: 禁止在这里 `await` 任何「必须等它结束」的东西。
            //   收敛可能永不返回（几何一直不收敛），兜底计时器就是为这种情况
            //   准备的；兜底若挂在收敛上，收敛挂死时兜底自身也会被挂住，
            //   遮罩再次永久不消失。
            _ = await settle()

            // 已被新一轮取代 → 不得改动状态。
            guard generation == self.roundGeneration else { return }
            guard conversationID == self.pendingConversationID else { return }
            guard stillRelevant() else {
                // Important: 这里**必须**释放准备状态。
                //   本轮已失效（会话被换掉 / 又进入加载），它不会置为就绪；
                //   若还把「准备中」留在 true，同一会话的后续请求会被去重挡掉，
                //   再没有任何一轮收敛能启动 —— 遮罩就此永久挂起。
                //   上面的轮次序号与 pending 校验已保证此刻的 pending 仍属于
                //   **本轮**，因此清零不会误伤新一轮的状态。
                self.isPreparing = false
                self.pendingConversationID = nil
                self.task = nil
                return
            }
            self.isReady = true
            self.isPreparing = false
            self.pendingConversationID = nil
            self.deadlineTask?.cancel()
            self.deadlineTask = nil
            self.task = nil
        }
        return true
    }

    /// 兜底放行：遮罩挂起后必须在预算内落下。
    ///
    /// - Important: 与收敛轮次**完全解耦**。收敛没被启动、收敛挂死、
    ///   收敛被去重挡掉……这些情况下遮罩都靠它收尾。
    /// - Note: 已有更早的截止时刻时**不延长**它：遮罩的寿命上界从首次挂起
    ///   起算，后续请求不得把用户等待重新拉长成一个又一个预算。
    private func armDeadlineIfNeeded() {
        guard deadlineTask == nil else { return }

        // 截止时刻必须在**排队之前**算：任务都排在主线程队列上，
        // 主线程被占用时它们还没启动，这段排队时间同样算在用户等待里。
        let deadlineUptimeNanoseconds = DispatchTime.now().uptimeNanoseconds + budgetNanoseconds
        deadlineTask = Task { @MainActor [weak self] in
            let now = DispatchTime.now().uptimeNanoseconds
            // 减法需要防下溢：截止时刻可能已经过去（例如主线程长时间被占用）。
            let remaining: UInt64 = deadlineUptimeNanoseconds > now
                ? deadlineUptimeNanoseconds - now
                : 0
            if remaining > 0 {
                try? await Task.sleep(nanoseconds: remaining)
            }
            guard !Task.isCancelled, let self else { return }
            // 兜底放行：遮罩的寿命有确定上界，绝不因为「没有人在推进它」而永久挂起。
            self.isReady = true
            self.isPreparing = false
            self.deadlineTask = nil
        }
    }

    /// 会话切换时复位：撤销就绪状态，让遮罩重新出现。
    ///
    /// - Important: **不**取消在飞的收敛。
    ///
    ///   收敛是否还有效由它自己的 `stillRelevant` 判定（会话是否被换掉、是否仍在加载），
    ///   而不是由这里无条件取消。若无条件取消，就会踩中「同一 update cycle 内
    ///   **准备先于切换复位**到达」的顺序：View 的 `onChange(isLoading)`（转 false →
    ///   触发准备）与 `onChange(selectedConversationID)`（→ 触发本方法）谁先到并不确定；
    ///   复位晚到时那一轮收敛刚启动就被作废，而此后不再有任何触发点能重新准备 ——
    ///   遮罩就此永久挂起。
    ///
    ///   旧会话那一轮也不会因此误放行遮罩：它的 `stillRelevant` 会因为会话已被换掉
    ///   而返回 false，收敛结束时不会置为就绪。
    func resetForConversationSwitch() {
        isReady = false
        // 遮罩重新挂起 → 兜底计时重新开始：这一轮遮罩的寿命同样有确定上界。
        restartDeadline()
    }

    /// 加载开始时复位（用于切换会话后重新进入加载）。
    ///
    /// - Important: 这里**要**作废在飞的收敛：加载开始意味着窗口内的消息即将被整体
    ///   替换，上一轮的收敛结果已经无意义。
    ///
    ///   注意它与会话切换复位的差别：加载开始一定会伴随随后的「加载完成 → 重新准备」，
    ///   因此在这里作废是安全的；而会话切换复位可能与准备同处一个 update cycle，
    ///   作废反而会切断刚启动的那一轮。
    func resetForLoadingStart() {
        task?.cancel()
        task = nil
        isPreparing = false
        isReady = false
        pendingConversationID = nil
        // 在飞轮次已作废：轮次序号前进，让它回来时不得改动任何状态。
        roundGeneration &+= 1
        // 遮罩重新挂起 → 兜底计时重新开始。
        restartDeadline()
    }

    /// 重新开始兜底计时：上一轮的截止时刻作废，从此刻起算新的预算。
    ///
    /// - Important: 遮罩「重新挂起」是一轮新的遮罩周期，它的寿命上界从此刻起算。
    private func restartDeadline() {
        deadlineTask?.cancel()
        deadlineTask = nil
        armDeadlineIfNeeded()
    }

    deinit {
        task?.cancel()
        deadlineTask?.cancel()
    }
}
