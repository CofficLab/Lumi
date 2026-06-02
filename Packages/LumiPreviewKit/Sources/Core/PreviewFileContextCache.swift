import Foundation

public extension LumiPreviewFacade {
/// 基于标准化文件路径的小型 LRU 缓存。
///
/// 用途：缓存源码文件解析后的上下文（如 `#Preview` 扫描结果），
/// 避免每次文件变化时重新扫描全部源码。
///
/// 线程安全：`struct` 语义，调用方通过 `actor` 或其他同步机制保护。
///
/// 使用示例：
/// ```swift
/// var cache = PreviewFileContextCache<[PreviewDiscovery]>(maximumCount: 32)
/// cache.store(discoveries, for: fileURL)
/// ```
struct PreviewFileContextCache<Context> {
    private var contexts: [String: Context] = [:]
    private var recency: [String] = []
    private let maximumCount: Int

    /// 创建缓存，指定最大容量。
    ///
    /// - Parameter maximumCount: 缓存条目上限，超出时按 LRU 策略淘汰。
    public init(maximumCount: Int) {
        self.maximumCount = max(0, maximumCount)
    }

    /// 当前缓存条目数。
    public var count: Int {
        contexts.count
    }

    /// 按最近最少使用顺序排列的所有缓存键。
    public var keysInLeastRecentOrder: [String] {
        recency
    }

    /// 将文件 URL 转换为标准化缓存键。
    ///
    /// 对路径进行标准化处理（解析符号链接、去除冗余），确保同一文件始终映射到同一键。
    public static func key(for fileURL: URL) -> String {
        fileURL.standardizedFileURL.resolvingSymlinksInPath().path
    }

    /// 按键查找缓存值，同时更新最近使用顺序。
    public mutating func value(forKey key: String) -> Context? {
        guard let value = contexts[key] else { return nil }
        markRecentlyUsed(key)
        return value
    }

    /// 按文件 URL 查找缓存值。
    public mutating func value(for fileURL: URL) -> Context? {
        value(forKey: Self.key(for: fileURL))
    }

    /// 移除指定键的缓存条目。
    @discardableResult
    public mutating func removeValue(forKey key: String) -> Context? {
        removeRecency(key)
        return contexts.removeValue(forKey: key)
    }

    /// 移除指定文件的缓存条目。
    @discardableResult
    public mutating func removeValue(for fileURL: URL) -> Context? {
        removeValue(forKey: Self.key(for: fileURL))
    }

    /// 清空所有缓存，返回按最近最少使用顺序排列的被移除条目。
    @discardableResult
    public mutating func removeAll() -> [(key: String, value: Context)] {
        let removed = recency.compactMap { key -> (key: String, value: Context)? in
            guard let value = contexts[key] else { return nil }
            return (key, value)
        }
        contexts.removeAll()
        recency.removeAll()
        return removed
    }

    /// 存储上下文到缓存，返回因超出容量上限被淘汰的条目。
    @discardableResult
    public mutating func store(_ context: Context, forKey key: String) -> [(key: String, value: Context)] {
        guard maximumCount > 0 else {
            let existing = contexts.removeValue(forKey: key).map { [(key: key, value: $0)] } ?? []
            removeRecency(key)
            return existing
        }

        contexts[key] = context
        markRecentlyUsed(key)
        return prune()
    }

    @discardableResult
    public mutating func store(_ context: Context, for fileURL: URL) -> [(key: String, value: Context)] {
        store(context, forKey: Self.key(for: fileURL))
    }

    public mutating func markRecentlyUsed(_ key: String) {
        removeRecency(key)
        recency.append(key)
    }

    private mutating func removeRecency(_ key: String) {
        recency.removeAll { $0 == key }
    }

    private mutating func prune() -> [(key: String, value: Context)] {
        var removed: [(key: String, value: Context)] = []
        while recency.count > maximumCount {
            let removedKey = recency.removeFirst()
            if let context = contexts.removeValue(forKey: removedKey) {
                removed.append((key: removedKey, value: context))
            }
        }
        return removed
    }
}

}
