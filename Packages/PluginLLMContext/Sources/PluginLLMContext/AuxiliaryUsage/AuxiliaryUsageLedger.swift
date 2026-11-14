import Foundation
import ProviderLLMContext

/// `LLMAuxiliaryUsageProviding` 的默认实现：内存缓存 + 可选磁盘持久化。
///
/// 由上下文插件注册进内核，压缩与标题调用方写入，上下文弹窗读取。无磁盘存储
/// 时（测试 / 缺少 StorageProviding）退化为纯内存账本，行为不变。
@MainActor
final class AuxiliaryUsageLedger: LLMAuxiliaryUsageProviding {
    private let store: AuxiliaryUsageStore?
    private var cache: [UUID: [LLMAuxiliaryUsageEntry]] = [:]
    private var loadedConversationIDs: Set<UUID> = []

    init(store: AuxiliaryUsageStore? = nil) {
        self.store = store
    }

    func record(_ entry: LLMAuxiliaryUsageEntry) async {
        await ensureLoaded(entry.conversationID)
        cache[entry.conversationID, default: []].append(entry)
        guard let store else { return }
        try? await store.save(entry)
    }

    func entries(for conversationID: UUID) async -> [LLMAuxiliaryUsageEntry] {
        await ensureLoaded(conversationID)
        return (cache[conversationID] ?? []).sorted { lhs, rhs in
            if lhs.date == rhs.date { return lhs.id.uuidString < rhs.id.uuidString }
            return lhs.date < rhs.date
        }
    }

    /// 会话删除时清空内存缓存与磁盘记录（#350）。
    func remove(conversationID: UUID) async {
        cache.removeValue(forKey: conversationID)
        loadedConversationIDs.remove(conversationID)
        try? await store?.remove(conversationID: conversationID)
    }

    /// 首次访问某会话时把磁盘记录并入内存缓存。
    ///
    /// `loadedConversationIDs` 在 await 之前同步置位，避免并发加载；磁盘记录按
    /// id 去重合并，而不是覆盖，防止加载期间新写入的记录被旧快照冲掉。
    private func ensureLoaded(_ conversationID: UUID) async {
        guard !loadedConversationIDs.contains(conversationID) else { return }
        loadedConversationIDs.insert(conversationID)
        guard let store else { return }
        let persisted = (try? await store.entries(for: conversationID)) ?? []
        var merged = cache[conversationID] ?? []
        let existingIDs = Set(merged.map(\.id))
        merged.append(contentsOf: persisted.filter { !existingIDs.contains($0.id) })
        cache[conversationID] = merged
    }
}