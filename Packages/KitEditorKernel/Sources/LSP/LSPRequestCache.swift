import Foundation

/// LSP 请求结果缓存
///
/// 缓存 LSP 请求的结果，避免对相同位置的重复请求。
/// 缓存条目会在一定时间后过期，确保数据的时效性。
@MainActor
public final class LSPRequestCache {
    // MARK: - Types

    /// 缓存键的组成部分
    private struct CacheKey: Hashable, Sendable {
        let kind: LSPViewportScheduler.Kind
        let uri: String
        let line: Int
        let character: Int
    }

    /// 缓存条目
    private struct CacheEntry<T: Sendable> {
        let value: T
        let timestamp: Date
        let generation: UInt64

        @MainActor var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > LSPRequestCache.defaultExpiration
        }
    }

    // MARK: - Constants

    /// 默认缓存过期时间（秒）
    public static let defaultExpiration: TimeInterval = 30.0

    /// 最大缓存条目数
    public static let maxCacheEntries = 1000

    // MARK: - State

    /// 缓存存储
    private var cache: [CacheKey: Any] = [:]

    /// 请求代管理（用于缓存失效）
    private let generation = RequestGeneration()

    /// LRU 追踪（最近使用的键）
    private var lruOrder: [CacheKey] = []

    public init() {}

    // MARK: - Public API

    /// 获取缓存的请求结果
    ///
    /// - Parameters:
    ///   - kind: 请求类型
    ///   - uri: 文档 URI
    ///   - line: 行号（0-based）
    ///   - character: 列号（0-based）
    /// - Returns: 缓存的值，如果未找到或已过期则返回 nil
    public func get<T: Sendable>(
        kind: LSPViewportScheduler.Kind,
        uri: String,
        line: Int,
        character: Int
    ) -> T? {
        let key = CacheKey(kind: kind, uri: uri, line: line, character: character)

        guard let entry = cache[key] as? CacheEntry<T> else {
            return nil
        }

        // 检查是否过期
        if entry.isExpired {
            remove(key: key)
            return nil
        }

        // 检查是否与当前代匹配
        if entry.generation != generation.generation {
            remove(key: key)
            return nil
        }

        // 更新 LRU 顺序
        updateLRU(key: key)

        return entry.value
    }

    /// 设置缓存的请求结果
    ///
    /// - Parameters:
    ///   - kind: 请求类型
    ///   - uri: 文档 URI
    ///   - line: 行号（0-based）
    ///   - character: 列号（0-based）
    ///   - value: 要缓存的值
    public func set<T: Sendable>(
        kind: LSPViewportScheduler.Kind,
        uri: String,
        line: Int,
        character: Int,
        value: T
    ) {
        let key = CacheKey(kind: kind, uri: uri, line: line, character: character)

        // 如果缓存已满，移除最旧的条目
        if cache.count >= LSPRequestCache.maxCacheEntries {
            removeLRU()
        }

        let entry = CacheEntry<T>(
            value: value,
            timestamp: Date(),
            generation: generation.generation
        )

        cache[key] = entry
        updateLRU(key: key)
    }

    /// 移除指定位置的缓存
    ///
    /// - Parameters:
    ///   - kind: 请求类型
    ///   - uri: 文档 URI
    ///   - line: 行号（0-based）
    ///   - character: 列号（0-based）
    public func remove(
        kind: LSPViewportScheduler.Kind,
        uri: String,
        line: Int,
        character: Int
    ) {
        let key = CacheKey(kind: kind, uri: uri, line: line, character: character)
        remove(key: key)
    }

    /// 清除指定类型的所有缓存
    ///
    /// - Parameter kind: 请求类型
    public func removeAll(kind: LSPViewportScheduler.Kind) {
        cache = cache.filter { key, _ in
            if let cacheKey = key as? CacheKey {
                return cacheKey.kind != kind
            }
            return true
        }
        lruOrder.removeAll { key in
            key.kind != kind
        }
    }

    /// 清除所有缓存
    public func clear() {
        cache.removeAll()
        lruOrder.removeAll()
        generation.invalidate()
    }

    /// 失效指定文档的所有缓存
    ///
    /// - Parameter uri: 文档 URI
    public func invalidate(uri: String) {
        cache = cache.filter { key, _ in
            if let cacheKey = key as? CacheKey {
                return cacheKey.uri != uri
            }
            return true
        }
        lruOrder.removeAll { key in
            key.uri != uri
        }
    }

    // MARK: - Private Helpers

    private func remove(key: CacheKey) {
        cache.removeValue(forKey: key)
        lruOrder.removeAll { $0 == key }
    }

    private func updateLRU(key: CacheKey) {
        lruOrder.removeAll { $0 == key }
        lruOrder.append(key)
    }

    private func removeLRU() {
        guard let oldestKey = lruOrder.first else { return }
        remove(key: oldestKey)
    }
}
