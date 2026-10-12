import Foundation

/// API Key 的进程内读缓存（read-through）。
///
/// 命中缓存的读取不再访问 Keychain：热路径（每次 LLM 请求解析 Key）上省去
/// 一次 securityd IPC，也把 Keychain 瞬时故障（如 errSecMissingEntitlement）
/// 的暴露面缩小到「缓存未命中」这一小段窗口。缓存仅驻留内存，不落盘。
///
/// 条目语义：
/// - `value != nil`：最近一次成功读到的 Key；
/// - `value == nil`：最近一次已**确认**不存在（负缓存），避免未配置 Key 的
///   供应商在每次请求上重复付出多轮全量查询的代价。
final class APIKeyMemoryCache: @unchecked Sendable {

    struct Entry {
        /// `nil` 表示已确认缺失（负缓存）。
        let value: String?
        /// 最近一次向 Keychain 得出结论的时间。
        let fetchedAt: Date
    }

    // MARK: - 属性

    private let lock = NSLock()
    private var entries: [String: Entry] = [:]

    // MARK: - 公开方法

    /// 新鲜命中：仅返回 `maxAge` 内的条目；过期视为未命中（调用方应回源）。
    func entry(forKey key: String, maxAge: TimeInterval, now: Date = Date()) -> Entry? {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = entries[key] else { return nil }
        return now.timeIntervalSince(entry.fetchedAt) <= maxAge ? entry : nil
    }

    /// 最近已知条目，**不校验新鲜度**。用于 stale-if-error 回退：
    /// Keychain 读取失败或误报 not-found 时，旧值比“中断对话”更好。
    func lastKnownEntry(forKey key: String) -> Entry? {
        lock.lock()
        defer { lock.unlock() }
        return entries[key]
    }

    func remember(_ value: String, forKey key: String, now: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }
        entries[key] = Entry(value: value, fetchedAt: now)
    }

    func rememberMissing(forKey key: String, now: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }
        entries[key] = Entry(value: nil, fetchedAt: now)
    }

    func remove(forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        entries.removeValue(forKey: key)
    }
}
