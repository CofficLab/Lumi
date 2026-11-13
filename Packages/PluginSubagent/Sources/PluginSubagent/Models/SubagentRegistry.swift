import Foundation
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import ProviderToolManager

/// 树内寻址失败的原因。
public enum SubagentRegistryError: Error, Equatable {
    /// 发起方会话不存在（可能已被删除）。
    case conversationNotFound(UUID)
    /// 当前树里没有这个名字，或它在另一棵树里。
    case unknownName(String)
    /// 持久化数据里出现重名，无法安全猜测目标。
    case ambiguousName(String)
}

/// 树中的一个子代理。
public struct SubagentNode: Identifiable, Equatable, Sendable {
    /// 树内稳定名字；旧委托没有名字，保持 nil。
    public let name: String?
    /// 模型给的短标签，仅用于展示。
    public let label: String
    public let childConversationID: UUID
    /// 父会话里对应 `run_subagent` 的 Job ID。
    public let parentJobID: String
    /// 最近的 Job 状态；Job 快照尚未恢复时为 nil。
    public let jobStatus: ToolJobStatus?
    /// AgentLoop 当前是否在该子会话里跑回合。
    public let isRunning: Bool
    public let createdAt: Date

    public var id: UUID { childConversationID }

    /// 只有带名字的委托能被寻址；旧卡片只用于展示。
    public var isAddressable: Bool { name != nil }

    /// 已结束（且当前没有回合在跑）的子代理可以被 followup 唤醒。
    public var isResumable: Bool {
        !isRunning && (jobStatus?.isTerminal ?? true)
    }

    /// 运行中或 Job 尚未进入终态。
    public var isActive: Bool {
        isRunning || !(jobStatus?.isTerminal ?? false)
    }
}

/// 从某个会话看到的整棵树。
public struct SubagentTreeSnapshot: Equatable, Sendable {
    public let rootConversationID: UUID
    public let callerConversationID: UUID
    /// 根会话的直接子代理，按创建时间排序。
    public let members: [SubagentNode]

    /// 带名字、可寻址的成员。
    public var addressableMembers: [SubagentNode] {
        members.filter(\.isAddressable)
    }
}

/// 寻址结果。
public enum SubagentTarget: Equatable, Sendable {
    case lead(conversationID: UUID)
    case child(name: String, conversationID: UUID, parentJobID: String)

    public var conversationID: UUID {
        switch self {
        case .lead(let conversationID):
            return conversationID
        case .child(_, let conversationID, _):
            return conversationID
        }
    }

    public var displayName: String {
        switch self {
        case .lead:
            return SubagentRegistry.leadName
        case .child(let name, _, _):
            return name
        }
    }
}

/// 子代理树的派生注册表（#1328 Task 2）。
///
/// 不引入第二份真源：成员来自根会话里持久化的委托卡片载荷，状态来自
/// ToolJob，活跃状态来自 AgentLoop。每次查询都从持久化数据重建，所以
/// 重启后不需要额外恢复逻辑，也不会出现「内存与磁盘各有一份名单」。
///
/// 寻址范围严格限制在当前树内：根会话是 `lead`，其余目标只能是根的直接
/// 子代理。名字解析本身不授予任何权限。
@MainActor
public final class SubagentRegistry {
    /// 根代理的固定寻址名。
    public nonisolated static let leadName = "lead"

    private let conversations: any ConversationManaging
    private let messages: any MessageManaging
    private let toolManager: any ToolManagerProviding
    private let agentLoop: any AgentLoopProviding

    public init(
        conversations: any ConversationManaging,
        messages: any MessageManaging,
        toolManager: any ToolManagerProviding,
        agentLoop: any AgentLoopProviding
    ) {
        self.conversations = conversations
        self.messages = messages
        self.toolManager = toolManager
        self.agentLoop = agentLoop
    }

    /// 派生 `conversationID` 所在的树；会话不存在时返回 nil。
    public func snapshot(for conversationID: UUID) async -> SubagentTreeSnapshot? {
        guard let rootID = await rootConversationID(for: conversationID) else {
            return nil
        }

        let payloads = await messages.messagesSnapshot(in: rootID)
            .compactMap { SubagentTimeline.decodePayload(from: $0.metadata) }
            .filter { $0.parentConversationID == rootID }

        var seenChildren: Set<UUID> = []
        var members: [SubagentNode] = []
        for payload in payloads {
            guard seenChildren.insert(payload.childConversationID).inserted else { continue }
            // 已删除（或连带删除）的子会话不能再被寻址。
            guard let child = await conversations.fetchConversation(id: payload.childConversationID) else {
                continue
            }
            let job = toolManager.job(for: payload.jobID)
            members.append(
                SubagentNode(
                    name: payload.name,
                    label: payload.label,
                    childConversationID: payload.childConversationID,
                    parentJobID: payload.jobID,
                    jobStatus: job?.status,
                    isRunning: agentLoop.isRunning(for: payload.childConversationID),
                    createdAt: job?.createdAt ?? child.createdAt
                )
            )
        }

        members.sort {
            if $0.createdAt != $1.createdAt {
                return $0.createdAt < $1.createdAt
            }
            return $0.childConversationID.uuidString < $1.childConversationID.uuidString
        }

        return SubagentTreeSnapshot(
            rootConversationID: rootID,
            callerConversationID: conversationID,
            members: members
        )
    }

    /// 把名字解析为当前树内的目标。
    public func resolve(name: String, from conversationID: UUID) async throws -> SubagentTarget {
        guard let snapshot = await snapshot(for: conversationID) else {
            throw SubagentRegistryError.conversationNotFound(conversationID)
        }
        if name == Self.leadName {
            return .lead(conversationID: snapshot.rootConversationID)
        }

        let matches = snapshot.members.filter { $0.name == name }
        switch matches.count {
        case 0:
            throw SubagentRegistryError.unknownName(name)
        case 1:
            let node = matches[0]
            return .child(
                name: name,
                conversationID: node.childConversationID,
                parentJobID: node.parentJobID
            )
        default:
            throw SubagentRegistryError.ambiguousName(name)
        }
    }

    /// 沿 `parentConversationID` 上溯到根；遇到缺失或成环时返回 nil。
    private func rootConversationID(for conversationID: UUID) async -> UUID? {
        var current = conversationID
        var visited: Set<UUID> = []
        while visited.insert(current).inserted {
            guard let summary = await conversations.fetchConversation(id: current) else {
                return nil
            }
            guard let parent = summary.parentConversationID else {
                return current
            }
            current = parent
        }
        return nil
    }
}
