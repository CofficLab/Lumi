import CryptoKit
import Foundation

/// 线程安全的查询结果缓存
public final class RAGCache: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [String: Entry] = [:]
    private let ttlSeconds: TimeInterval
    private let maxSize: Int

    private struct Entry {
        let results: [RAGSearchResult]
        let timestamp: CFAbsoluteTime
    }

    public init(ttlSeconds: TimeInterval = 120, maxSize: Int = 50) {
        self.ttlSeconds = ttlSeconds
        self.maxSize = maxSize
    }

    /// 构建缓存 key（SHA256 哈希）
    ///
    /// 每个字段先写入 UTF-8 字节长度再写入内容。query 和项目路径都可能包含
    /// 分隔符，直接拼接会让不同三元组产生相同的散列输入（回归 #1112）。
    public func buildKey(query: String, projectPath: String?, topK: Int) -> String {
        var hasher = SHA256()
        for field in [query, projectPath ?? "", String(topK)] {
            let bytes = Data(field.utf8)
            hasher.update(data: Data("\(bytes.count):".utf8))
            hasher.update(data: bytes)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// 获取缓存，过期返回 nil
    public func get(key: String) -> [RAGSearchResult]? {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = entries[key] else { return nil }
        let now = CFAbsoluteTimeGetCurrent()
        guard now - entry.timestamp < ttlSeconds else {
            entries.removeValue(forKey: key)
            return nil
        }
        return entry.results
    }

    /// 存入缓存，自动淘汰过期和最旧条目
    public func set(key: String, results: [RAGSearchResult]) {
        lock.lock()
        defer { lock.unlock() }
        let now = CFAbsoluteTimeGetCurrent()
        // 淘汰过期条目
        entries = entries.filter { now - $0.value.timestamp < ttlSeconds }
        // 如果超过上限，移除最旧的
        if entries.count >= maxSize {
            let oldest = entries.min { $0.value.timestamp < $1.value.timestamp }?.key
            if let oldest { entries.removeValue(forKey: oldest) }
        }
        entries[key] = Entry(results: results, timestamp: now)
    }

    /// 清除所有缓存
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
    }
}
