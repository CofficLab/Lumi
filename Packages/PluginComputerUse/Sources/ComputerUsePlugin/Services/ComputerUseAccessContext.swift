import Foundation
import KernelCore
import KitAgentTool
import ProviderConversation

/// Computer Use 的一次访问判定上下文。
///
/// 回答的问题是：**这次操作能不能碰这个 App，要不要再问用户一次。**
///
/// 判定依据只有一条轴：会话的自动化等级（`AutomationLevel`）。
/// Computer Use 不再维护独立的应用白名单——那是一份需要用户手工维护、
/// 与会话语义无关的持久数据；改成会话等级驱动后，用户的心智负担降到
/// 「选一个模式」，而不是「再维护一张表」。
///
/// 判定语义：
/// - **A3（自主）**：完全放行，不打扰用户。授权的语义已经由模式本身表达过了。
/// - **A2（构建）**：每个 App 在本会话内授权一次即可，授权只在本会话有效。
/// - **A1（对话）**：不执行任何工具，因此不会走到这里；按 A2 保守处理。
struct ComputerUseAccessContext: Sendable, Equatable {
    /// 本次操作所属会话。
    let conversationID: UUID

    /// 会话的自动化等级。
    let automationLevel: AutomationLevel

    init(conversationID: UUID, automationLevel: AutomationLevel) {
        self.conversationID = conversationID
        self.automationLevel = automationLevel
    }

    /// 是否可以直接放行，不需要用户任何形式的授权。
    ///
    /// A3 的语义是「持续自主推进任务」，用户已经通过选择模式表达过授权，
    /// 再弹卡片只会让自主模式名存实亡。
    var allowsUnattendedAccess: Bool {
        automationLevel == .autonomous
    }
}

/// 会话自动化等级的查询入口。
///
/// Computer Use 需要知道「当前会话是不是 A3」，但插件本身不负责会话状态。
/// 本类型是唯一的取数口，注入点在插件的 `onReady`（此时其他插件已 Boot，
/// `ConversationManaging` 可以解析）。
///
/// - Note: 查不到会话时**按 A2 保守处理**：宁可多问一次，也不因为
///   解析失败而静默放行未知应用。
@MainActor
final class ComputerUseAutomationLevelProvider {
    static let shared = ComputerUseAutomationLevelProvider()

    private weak var conversations: (any ConversationManaging)?

    private init() {}

    func start(kernel: KernelCoreContainer) {
        conversations = kernel.resolveProvider((any ConversationManaging).self)
    }

    func stop() {
        conversations = nil
    }

    /// 查询指定会话的自动化等级。
    ///
    /// - Returns: 会话的等级；会话不存在或管理器不可用时返回 `nil`（调用方按 A2 处理）。
    func automationLevel(for conversationID: UUID) -> AutomationLevel? {
        guard let conversations else { return nil }
        return conversations.automationLevel(for: conversationID)
    }

    /// 构造一次访问判定的上下文。
    ///
    /// 查不到等级时降级为 A2（构建）：A2 仍会弹一次性授权卡片，
    /// 用户仍有机会拒绝；A3 则会静默放行一个未知边界的应用。
    func accessContext(for conversationID: UUID) -> ComputerUseAccessContext {
        ComputerUseAccessContext(
            conversationID: conversationID,
            automationLevel: automationLevel(for: conversationID) ?? .build
        )
    }

    /// 从工具执行上下文解析访问判定上下文。
    ///
    /// 工具的执行管线会带上 `conversationID`；直接调用工具（例如调试或
    /// 插件内部调用）时没有会话，退到**当前选中会话**——那至少是一个
    /// 真实存在、等级可查的会话，不会凭空造一个等级。
    ///
    /// - Parameter conversationID: 工具执行上下文里的会话 ID。
    /// - Returns: 访问判定上下文。
    func resolveAccessContext(conversationID: UUID?) async -> ComputerUseAccessContext {
        await MainActor.run { () -> ComputerUseAccessContext in
            guard let conversationID else {
                if let selected = conversations?.selectedConversationID {
                    return accessContext(for: selected)
                }
                // 没有任何会话可用：按 A2 处理，让用户仍然有一次拒绝的机会。
                return ComputerUseAccessContext(
                    conversationID: Self.orphanConversationID,
                    automationLevel: .build
                )
            }
            return accessContext(for: conversationID)
        }
    }

    /// 无会话可用时的占位会话 ID。
    ///
    /// 固定值而非随机值：同一进程内的多次调用必须落到同一个键上，
    /// 否则「授权过一次」永远对不上。
    static let orphanConversationID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
}

/// 工具层取访问判定上下文的入口。
///
/// 工具是 `Sendable` 的值类型，拿不到 `MainActor` 上的 provider 实例；
/// 本类型把「从工具执行上下文解析出访问上下文」这件事收敛成一个静态入口，
/// 避免每个工具各写一份降级逻辑。
enum ComputerUseAccessContextResolver {
    /// 解析访问判定上下文。
    ///
    /// - Parameter context: 工具执行上下文；为 `nil` 时按当前选中会话处理。
    /// - Returns: 访问判定上下文。
    static func resolve(_ context: ToolExecutionContext?) async -> ComputerUseAccessContext {
        await ComputerUseAutomationLevelProvider.shared
            .resolveAccessContext(conversationID: context?.conversationID)
    }
}
