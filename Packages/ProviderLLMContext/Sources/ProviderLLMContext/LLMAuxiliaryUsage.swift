import Foundation
import KitLLM

/// 幕后 LLM 调用的用途标签。
///
/// 这些调用（压缩摘要、对话标题）不属于对话回合，不进入上下文曲线，
/// 但确实消耗额度。账本按用途聚合，让「省了多少 / 花了多少」可被核算。
public enum LLMAuxiliaryPurpose: String, Sendable, Equatable, Codable, CaseIterable {
    case compaction
    case title
}

/// 一次幕后 LLM 调用的用量记录。
///
/// 五个用量字段与 `LLMResponse` 一致；供应商未上报用量时用估算值填充并置
/// `isEstimated == true`，绝不伪造零值。`spentTokens` 为本次调用实际消耗的
/// 输入 + 输出 token，用于和压缩节省量相减得到净收益。
public struct LLMAuxiliaryUsageEntry: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let conversationID: UUID
    public let purpose: LLMAuxiliaryPurpose
    public let providerID: String?
    public let modelName: String?
    public let inputTokenCount: Int?
    public let outputTokenCount: Int?
    public let cachedInputTokenCount: Int?
    public let cacheWriteInputTokenCount: Int?
    public let cacheTotalInputTokenCount: Int?
    /// 用量来自估算而非供应商上报。
    public let isEstimated: Bool
    public let date: Date
    /// 压缩摘要关联的源历史末条消息 ID，用于把用量 joins 到压缩时间线事件。
    public let sourceLastMessageID: UUID?

    public init(
        id: UUID = UUID(),
        conversationID: UUID,
        purpose: LLMAuxiliaryPurpose,
        providerID: String?,
        modelName: String?,
        inputTokenCount: Int?,
        outputTokenCount: Int?,
        cachedInputTokenCount: Int? = nil,
        cacheWriteInputTokenCount: Int? = nil,
        cacheTotalInputTokenCount: Int? = nil,
        isEstimated: Bool,
        date: Date = Date(),
        sourceLastMessageID: UUID? = nil
    ) {
        self.id = id
        self.conversationID = conversationID
        self.purpose = purpose
        self.providerID = providerID
        self.modelName = modelName
        self.inputTokenCount = inputTokenCount
        self.outputTokenCount = outputTokenCount
        self.cachedInputTokenCount = cachedInputTokenCount
        self.cacheWriteInputTokenCount = cacheWriteInputTokenCount
        self.cacheTotalInputTokenCount = cacheTotalInputTokenCount
        self.isEstimated = isEstimated
        self.date = date
        self.sourceLastMessageID = sourceLastMessageID
    }

    /// 从一次完成响应构建用量记录。
    ///
    /// 供应商上报了输入或输出用量时直接采用（`isEstimated == false`）；
    /// 完全没有上报时用调用方提供的估算值填充（`isEstimated == true`）。
    /// 估算值也缺失时保留 `nil`，由 UI 标注「不可用」而不是显示零。
    public init(
        response: LLMResponse,
        purpose: LLMAuxiliaryPurpose,
        conversationID: UUID,
        providerID: String?,
        modelName: String?,
        sourceLastMessageID: UUID? = nil,
        estimatedInputTokens: Int? = nil,
        estimatedOutputTokens: Int? = nil,
        date: Date = Date()
    ) {
        let hasReportedUsage = response.inputTokenCount != nil || response.outputTokenCount != nil
        self.init(
            conversationID: conversationID,
            purpose: purpose,
            providerID: providerID,
            modelName: modelName,
            inputTokenCount: hasReportedUsage ? response.inputTokenCount : estimatedInputTokens,
            outputTokenCount: hasReportedUsage ? response.outputTokenCount : estimatedOutputTokens,
            cachedInputTokenCount: response.cachedInputTokenCount,
            cacheWriteInputTokenCount: response.cacheWriteInputTokenCount,
            cacheTotalInputTokenCount: response.cacheTotalInputTokenCount,
            isEstimated: !hasReportedUsage,
            date: date,
            sourceLastMessageID: sourceLastMessageID
        )
    }

    /// 本次调用消耗的 token（输入 + 输出）；两者皆缺时为 `nil`（不可用）。
    public var spentTokens: Int? {
        guard inputTokenCount != nil || outputTokenCount != nil else { return nil }
        return (inputTokenCount ?? 0) + (outputTokenCount ?? 0)
    }
}

/// 按用途聚合的幕后开销。
public struct LLMAuxiliaryOverhead: Sendable, Equatable {
    public let purpose: LLMAuxiliaryPurpose
    public let callCount: Int
    /// 已知用量的调用消耗总和；没有任何可用用量时为 `nil`。
    public let spentTokens: Int?
    /// 是否存在估算口径的用量。
    public let hasEstimatedUsage: Bool
    /// 是否存在完全无用量（不可用）的调用。
    public let hasUnavailableUsage: Bool

    public init(
        purpose: LLMAuxiliaryPurpose,
        callCount: Int,
        spentTokens: Int?,
        hasEstimatedUsage: Bool,
        hasUnavailableUsage: Bool
    ) {
        self.purpose = purpose
        self.callCount = callCount
        self.spentTokens = spentTokens
        self.hasEstimatedUsage = hasEstimatedUsage
        self.hasUnavailableUsage = hasUnavailableUsage
    }

    /// 把一组用量记录按用途聚合，顺序与 `LLMAuxiliaryPurpose.allCases` 一致。
    public static func summarize(_ entries: [LLMAuxiliaryUsageEntry]) -> [LLMAuxiliaryOverhead] {
        LLMAuxiliaryPurpose.allCases.compactMap { purpose in
            let matching = entries.filter { $0.purpose == purpose }
            guard !matching.isEmpty else { return nil }
            let known = matching.compactMap(\.spentTokens)
            return LLMAuxiliaryOverhead(
                purpose: purpose,
                callCount: matching.count,
                spentTokens: known.isEmpty ? nil : known.reduce(0, +),
                hasEstimatedUsage: matching.contains { $0.isEstimated && $0.spentTokens != nil },
                hasUnavailableUsage: matching.contains { $0.spentTokens == nil }
            )
        }
    }
}

/// 幕后 LLM 调用账本。
///
/// 由上下文插件实现并注册进内核，压缩与标题两个调用方写入，上下文弹窗读取
/// 聚合开销。账本独立于上下文曲线：曲线只表示「prompt 有多大」，幕后调用不是
/// prompt 的一部分。
@MainActor
public protocol LLMAuxiliaryUsageProviding: AnyObject, Sendable {
    /// 记录一次幕后调用用量。
    func record(_ entry: LLMAuxiliaryUsageEntry) async
    /// 读取某会话的全部幕后调用用量（按时间升序）。
    func entries(for conversationID: UUID) async -> [LLMAuxiliaryUsageEntry]
}