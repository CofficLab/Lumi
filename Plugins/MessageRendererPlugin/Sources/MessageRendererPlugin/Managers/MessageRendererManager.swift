import Foundation
import LumiKernel

/// 消息渲染器管理器
///
/// 负责管理所有已注册的消息渲染器，提供渲染器查询接口。
/// 插件通过 LumiPlugin.messageRenderers(kernel:) 贡献渲染器，
/// 由本服务统一注册和管理。
///
/// 缓存说明:`renderer(for:)` 会在消息列表滚动/流式刷新时被高频调用(每行每次
/// body 求值一次)。原始实现每次都重新构建数组 + 排序 + 逐个 canRender 匹配,
/// 在 LazyVStack 滚动时会压垮主线程。这里加两层缓存:
/// 1. `sortedRenderers` —— 按 order 降序排好的渲染器列表,只在注册/注销时重算;
/// 2. `matchCache` —— 按 (id, content, role, renderKind) 缓存的匹配结果,
///    流式更新(content 变化)会自然产生不同的 key 从而重新匹配。
@MainActor
public final class MessageRendererManager: MessageRendering {
    public static let shared = MessageRendererManager()

    // MARK: - State

    private var messageRenderers: [String: LumiMessageRendererItem] = [:]
    private var messageRendererOrder: [String] = []

    /// 缓存的"按 order 降序排列"的渲染器快照;`nil` 表示需要重算。
    private var sortedRenderersCache: [LumiMessageRendererItem]?

    /// 按 (消息 id, content, role, renderKind) 缓存匹配到的 renderer id;
    /// 渲染器集合变化时整体清空。
    private var matchCache: [MatchKey: String] = [:]

    public init() {}

    // MARK: - MessageRendererManaging

    public func allMessageRenderers() -> [LumiMessageRendererItem] {
        sortedRenderers
    }

    public func registerMessageRenderer(_ renderer: LumiMessageRendererItem) {
        if messageRenderers[renderer.id] == nil {
            messageRendererOrder.append(renderer.id)
        }
        messageRenderers[renderer.id] = renderer
        invalidateCaches()
    }

    public func unregisterMessageRenderer(id: String) {
        guard messageRenderers.removeValue(forKey: id) != nil else { return }
        messageRendererOrder.removeAll { $0 == id }
        invalidateCaches()
    }

    public func renderer(for message: LumiChatMessage) -> LumiMessageRendererItem? {
        let key = MatchKey(message: message)
        // 命中缓存:用 id 反查已匹配的 renderer。
        if let cachedID = matchCache[key] {
            return messageRenderers[cachedID]
        }
        // 未命中:在排好序的列表里找第一个 canRender 的,并缓存其 id。
        let matched = sortedRenderers.first { $0.canRender(message) }
        matchCache[key] = matched?.id
        return matched
    }

    // MARK: - Private

    /// 按 order 降序排列的渲染器列表(带缓存)。
    private var sortedRenderers: [LumiMessageRendererItem] {
        if let cached = sortedRenderersCache {
            return cached
        }
        let sorted = messageRendererOrder
            .compactMap { messageRenderers[$0] }
            .sorted { $0.order > $1.order }
        sortedRenderersCache = sorted
        return sorted
    }

    /// 渲染器集合变化时清空两层缓存。
    private func invalidateCaches() {
        sortedRenderersCache = nil
        matchCache.removeAll()
    }

    /// renderer 匹配的缓存键。
    /// 包含 content/role/renderKind,使流式更新(同 id 但 content 增长)能正确重新匹配。
    private struct MatchKey: Hashable {
        let id: UUID
        let content: String
        let role: String
        let renderKind: String?

        init(message: LumiChatMessage) {
            self.id = message.id
            self.content = message.content
            self.role = message.role.rawValue
            self.renderKind = message.renderKind
        }
    }
}
