import Foundation

/// V1 过程折叠区的**展开状态机**。
///
/// ## 为什么需要它
///
/// 需求是「用户发送消息后过程区自动展开，LLM 的各种动作实时展示」——
/// 回合进行中，用户应该**不用点任何按钮**就能看到 agent 在干什么。
/// 但同时不能变成「强制展开」：用户手动折叠后想安静看回复，
/// 下一轮流式更新不该把折叠区又撑开。
///
/// ## 状态语义
///
/// 三种状态：
///
/// - `collapsed`：用户手动折叠了 —— **用户的显式意图**，后续自动展开不得覆盖它；
/// - `expandedByUser`：用户手动展开了 —— 保持展开；
/// - `expandedAutomatically`：自动展开（用户尚未表达过偏好）。
///
/// 抽成纯逻辑是为了让「用户意图不被覆盖」这条规则可被单测锁定 ——
/// 它是这套交互里最容易回归的地方。
enum ProcessSectionExpansionState: Equatable {
    /// 用户手动折叠了。自动展开不得覆盖。
    case collapsed
    /// 用户手动展开了。
    case expandedByUser
    /// 自动展开（用户尚未表达过偏好）。
    case expandedAutomatically

    /// 当前是否应当展开。
    var isExpanded: Bool {
        switch self {
        case .collapsed:
            return false
        case .expandedByUser, .expandedAutomatically:
            return true
        }
    }

    /// 用户点击折叠按钮。
    mutating func userToggled(toExpanded expanded: Bool) {
        self = expanded ? .expandedByUser : .collapsed
    }
}

/// 把「是否应当自动展开」与「用户是否表达过偏好」分开记录的状态容器。
///
/// 与 ``ProcessSectionExpansionState`` 的区别：这个类型额外记住
/// 「用户是否曾经手动操作过」，因为自动展开只应发生在用户**从未手动
/// 操作过**的情况下 —— 否则每次新回合都会把用户折叠好的过程区撑开。
struct ProcessSectionExpansion: Equatable {
    /// 当前展开状态。
    private(set) var state: ProcessSectionExpansionState

    /// 用户是否曾经手动展开/折叠过。
    private(set) var hasUserPreference = false

    /// 当前是否应当展开。
    var isExpanded: Bool {
        state.isExpanded
    }

    /// 初始状态。
    ///
    /// - Parameter isActive: 该 turn 当前是否处于活跃（回合进行中）状态。
    /// - Important: **只有活跃回合才默认展开**。历史 turn 的过程区默认折叠 ——
    ///   否则打开一个长会话就会看到几十个过程区全部铺开，既刷屏又让
    ///   「真正在跑的那个回合」淹没在噪声里。
    init(isActive: Bool) {
        self.state = isActive ? .expandedAutomatically : .collapsed
    }

    /// 用户点击了折叠按钮。
    mutating func userToggled(toExpanded expanded: Bool) {
        hasUserPreference = true
        state.userToggled(toExpanded: expanded)
    }

    /// 回合状态变化（活跃 ↔ 结束）。
    ///
    /// - Important: 自动展开只在「用户从未手动操作过」时生效。
    ///   用户手动折叠过一次，之后所有回合都尊重这个选择。
    /// - Important: 回合**结束**时不做任何事 —— 保持用户最后看到的状态。
    ///   用户在回合进行中手动折叠了，回合结束后依然折叠（他刚才就表达了
    ///   这个意图）；自动展开的状态也保持展开，让最终回复紧接在过程区下方。
    mutating func turnStateChanged(isActive: Bool) {
        guard isActive else { return }
        guard !hasUserPreference else { return }
        state = .expandedAutomatically
    }
}
