import Foundation
import Combine
import SwiftUI

/// `InitialPositionGate` 内部竞速的结论：收敛先结束，还是预算先耗尽。
///
/// - Note: 独立类型而非裸 `Bool`，是为了让「收敛失败」与「预算耗尽」在
///   `switch` 里各自成 case —— 两者都放行遮罩，但一个是**已知结果**、
///   一个是**兜底**，诊断时需要能区分。
private enum InitialPositionOutcome {
    /// 收敛过程已返回（参数表示是否成功收敛）。
    case settled(Bool)
    /// 预算耗尽仍未收敛，走兜底放行。
    case timedOut
}

/// 「收敛结束」与「预算耗尽」之间的竞速器。
///
/// ## 为什么不能用 `withTaskGroup`
///
/// 收敛过程可能**永不返回**（List 几何一直不收敛）。`withTaskGroup` 退出会等待
/// 全部子任务结束，于是收敛挂死时——正是需要兜底的那种情况——整个兜底自身
/// 一起被挂住，遮罩再次永久不消失。
///
/// 本类型只 await 一个由「先完成方」唤醒的 continuation，**从不 join** 收敛任务；
/// 落败方由调用方 `cancel()` 回收。因此兜底永远能在预算内返回。
///
/// - Important: 全部状态都在 `@MainActor`，`finish` 的
///   「continuation 已为 nil 则忽略」即天然的一次性闸门，无需额外加锁。
@MainActor
private final class InitialPositionRace {
    private var continuation: CheckedContinuation<InitialPositionOutcome, Never>?
    private var settleTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?

    /// 启动竞速并等待先完成方。返回后两个任务都已确定胜者。
    ///
    /// - Parameters:
    ///   - settle: 收敛过程，返回 true 表示成功收敛。
    ///   - deadlineUptimeNanoseconds: 预算的**绝对截止时刻**（`DispatchTime.uptimeNanoseconds` 口径）。
    ///     必须是绝对时刻而不是时长：竞速的两个 Task 都要排在主线程队列上，
    ///     主线程被占用时它们根本还没启动，这段排队时间同样算在用户等待里。
    ///     若从头睡满整个时长，实际等待会变成「阻塞时长 + 完整预算」。
    func run(
        settle: @escaping @MainActor () async -> Bool,
        deadlineUptimeNanoseconds: UInt64
    ) async -> InitialPositionOutcome {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            settleTask = Task { @MainActor in
                let outcome = InitialPositionOutcome.settled(await settle())
                finish(outcome)
            }
            timeoutTask = Task { @MainActor in
                // 只睡到**截止时刻**，而不是从此刻起睡满整个预算。
                // 减法需要防下溢：截止时刻可能已经过去（例如主线程长时间被占用）。
                let now = DispatchTime.now().uptimeNanoseconds
                let remaining: UInt64 = deadlineUptimeNanoseconds > now
                    ? deadlineUptimeNanoseconds - now
                    : 0
                if remaining > 0 {
                    try? await Task.sleep(nanoseconds: remaining)
                }
                finish(.timedOut)
            }
        }
    }

    /// 取消落败方，避免它在预算结束后继续空转。
    func cancelLoser(of outcome: InitialPositionOutcome) {
        switch outcome {
        case .settled:
            timeoutTask?.cancel()
        case .timedOut:
            settleTask?.cancel()
        }
    }

    private func finish(_ outcome: InitialPositionOutcome) {
        guard let continuation else { return }   // 已有胜者，忽略迟到的一方
        self.continuation = nil
        continuation.resume(returning: outcome)
    }
}

/// 首屏就绪判定的编排策略（从 `ListV3View` 抽出以便测试）。
///
/// ## 背景
///
/// 消息列表在首屏定位完成前会盖一层遮罩（`isLoading || !isInitialPositionReady`）。
/// 原先这个判定直接写在 View 里：它 `await` 一个可能失败的收敛过程，失败时
/// `isInitialPositionReady` 保持 false，遮罩**永久挂起**，且没有任何重试或
/// 超时兜底。用户在界面上只能看到「正在加载消息…」一直不消失。
///
/// 这里把判定提炼为可测单元：收敛过程由调用方注入，本类型只负责
/// 「何时算就绪」以及**超时兜底**——收敛挂死时超过预算必须强制放行，
/// 否则任何收敛失败都会变成永久卡死。
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
    /// 收敛过程的预算上限。仅在**收敛挂死**时才会被等满。
    ///
    /// 语义是「从 `request()` 被调用那一刻起算的绝对时长」：预算**包含**
    /// 竞速搭建之前在主线程队列上的排队时间。若把它当成「竞速启动后才计时的
    /// 时长」，主线程被占用时用户的实际等待会变成「阻塞时长 + 完整预算」。
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
            isReady = true
            isPreparing = false
            pendingConversationID = nil
            return true
        }

        isPreparing = true
        isReady = false
        pendingConversationID = conversationID

        // Important: 截止时刻必须在**进入 Task 之前**算。
        //   竞速的两个 Task 都排在主线程队列上，主线程被占用时它们还没启动；
        //   预算若从「竞速真正跑起来」才开始计时，用户实际等待就是
        //   「主线程阻塞时长 + 完整预算」——正是「切换后遮罩又多挂一段」的成因。
        let deadlineUptimeNanoseconds = DispatchTime.now().uptimeNanoseconds + budgetNanoseconds

        task = Task { @MainActor [weak self] in
            guard let self else { return }

            // MARK: 收敛与预算的竞速
            //
            // Important: 这是**竞速**，不是「先等满预算再看结果」。
            // 曾经的实现无条件 `await timeout.value`（等满预算才去取收敛结果），
            // 于是无论几何多稳定，一次切换都要等满整个预算才撤遮罩 ——
            // 用户看到的正是「切换对话时消息列表出现很慢」。
            // 收敛一旦结束必须**立即**放行；只有收敛真的挂死才等预算兜底。
            //
            // Important: 禁止用 `withTaskGroup` 实现这个竞速。group 退出会等待
            //   全部子任务结束，而收敛挂死（正是需要兜底的那种情况）会让兜底
            //   自身一起挂住，遮罩再次永久不消失。
            //   正确做法见 `InitialPositionRace`：只 await 先完成方，落败方 cancel。
            let race = InitialPositionRace()
            let outcome = await race.run(
                settle: settle,
                deadlineUptimeNanoseconds: deadlineUptimeNanoseconds
            )
            race.cancelLoser(of: outcome)

            guard conversationID == self.pendingConversationID,
                  stillRelevant() else {
                // Important: 这里**不能**写 isPreparing = false。
                // 此刻 pendingConversationID 可能已属于**新**轮次，那个
                // isPreparing 属于新轮次而非本轮；在这里清零会把新轮次的门禁
                // 提前打开，后续 request 因 isPreparing == false 再启动一轮收敛 ——
                // 多轮收敛同时驱动同一个 scroll view，正是切换卡顿的放大器。
                // 本轮的状态由 resetForConversationSwitch() 统一作废。
                return
            }
            // Note: **两条路径都必须放行遮罩**（这里是遮罩唯一的放行点）：
            //   - 收敛成功 → 位置已对，立即放行；
            //   - 预算耗尽 → 兜底放行；
            //   - 收敛**失败** → 同样放行。首屏遮罩只应遮住「位置明显不对」的
            //     一瞬；用户更需要一个能滚动、可能位置稍有偏差的列表，
            //     而不是永久的加载态。
            //
            // Important: 曾经的写法是 `timedOut || settledSuccessfully`，
            //   它在「收敛已返回但返回 false」时算出 false —— 与紧邻的注释
            //   「收敛失败同样放行」**直接矛盾**，遮罩于是永久挂起且再无兜底
            //   能救（预算已在竞速中结束）。收敛失败必须也放行。
            self.isReady = true
            self.isPreparing = false
            self.task = nil
        }
        return true
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
    }

    deinit {
        task?.cancel()
    }
}
