import Foundation
@_implementationOnly import KitKeychain

/// API Key 管理工具。
///
/// API Key 使用 macOS Data Protection Keychain，并保留旧 service 的只读
/// 回退路径，以便从历史版本平滑迁移。读取失败和「条目不存在」必须保持
/// 可区分，否则 Keychain 的瞬时不可用会被误报为用户没有配置 Key。
///
/// 读取策略为 **read-through 缓存**：TTL 内的读取直接命中进程内缓存，不再
/// 每次访问 Keychain——热路径（每次 LLM 请求解析 Key）因此不暴露在
/// securityd 的瞬态故障（如 errSecMissingEntitlement / -34018）之下。写入和
/// 删除同步更新缓存，保证本进程内的增删改立即生效。
public enum VendorAPIKeyTools {

    /// Lumi 正式使用的 Keychain service；保持与历史版本一致。
    nonisolated(unsafe) public static var keychainService = "com.coffic.lumi.apikey"

    /// `KitLLM` 提取期间曾使用过的临时 service，保留只读迁移能力。
    private static let extractedKitLLMService = "com.kit.llm.apikey"

    /// 缓存新鲜度窗口：窗口内的读取不回源 Keychain。10 分钟是「外部直接改
    /// Keychain（绕过本工具）后最多多久可见」的上界；通过 `set` / `remove`
    /// 的修改立即生效。
    private static let cacheLifetime: TimeInterval = 10 * 60

    private static let cache = APIKeyMemoryCache()

    /// 同一 key 的回源读取/写入/删除互斥（in-flight 合并）：并发读取同一 key
    /// 时，后来者等锁结束后直接吃到先行者写入的缓存，避免重复 IPC 与竞态。
    private static let keyLocksLock = NSLock()
    nonisolated(unsafe) private static var keyLocks: [String: NSLock] = [:]

    /// 从 Keychain 解析 API Key；未配置时抛错。
    public static func resolve(storageKey: String?, displayName: String) throws -> String {
        guard let storageKey, !storageKey.isEmpty else {
            throw VendorAPIError.missingAPIKey(displayName)
        }
        do {
            guard let key = try read(storageKey: storageKey, retryMissing: true)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !key.isEmpty else {
                throw VendorAPIError.missingAPIKey(displayName)
            }
            return key
        } catch let error as VendorAPIError {
            throw error
        } catch {
            throw VendorAPIError.apiKeyAccessFailed(
                provider: displayName,
                details: error.localizedDescription
            )
        }
    }

    /// 是否已配置 API Key。
    public static func has(storageKey: String?) -> Bool {
        guard let storageKey, !storageKey.isEmpty else { return false }
        return !(bestEffortRead(storageKey: storageKey)?.isEmpty ?? true)
    }

    /// 读取 API Key（未配置返回空串）。
    public static func get(storageKey: String?) -> String {
        guard let storageKey, !storageKey.isEmpty else { return "" }
        return bestEffortRead(storageKey: storageKey) ?? ""
    }

    /// 写入 API Key。
    public static func set(_ apiKey: String, storageKey: String) {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            remove(storageKey: storageKey)
            return
        }

        let key = cacheKey(for: storageKey)
        withKeyLock(key) {
            // KeychainStore 使用 Update/Add，写入失败时保留旧值，避免
            // 「先删除、后添加」造成不可恢复的丢 Key。
            do {
                try primaryStore().setReportingErrors(trimmed, forKey: storageKey)
            } catch {
                // 未签名的 Swift Package 测试进程以及未配置 DP entitlement 的
                // 开发构建无法访问 Data Protection Keychain。回退到历史
                // file-based service，保证升级/开发期间仍可保存；正式 App
                // 优先使用上面的 DP 路径。
                do {
                    try legacyFileStore().setReportingErrors(trimmed, forKey: storageKey)
                } catch {
                    // 写入全部失败时保留旧缓存，避免把未落盘的新值记成可用。
                    return
                }
            }
            cache.remember(trimmed, forKey: key)
        }
    }

    /// 删除 API Key。
    public static func remove(storageKey: String) {
        let key = cacheKey(for: storageKey)
        withKeyLock(key) {
            // 清理所有历史寻址路径，避免删除后又从旧 service 回退读出。
            for store in stores() {
                try? store.removeReportingErrors(forKey: storageKey)
            }
            cache.remove(forKey: key)
        }
    }

    // MARK: - 私有方法

    private static func cacheKey(for storageKey: String) -> String {
        "\(keychainService)\u{0}\(storageKey)"
    }

    private static func keyLock(for key: String) -> NSLock {
        keyLocksLock.lock()
        defer { keyLocksLock.unlock() }
        if let lock = keyLocks[key] {
            return lock
        }
        let lock = NSLock()
        keyLocks[key] = lock
        return lock
    }

    private static func withKeyLock(_ key: String, _ body: () -> Void) {
        let lock = keyLock(for: key)
        lock.lock()
        defer { lock.unlock() }
        body()
    }

    private static func read(storageKey: String, retryMissing: Bool = false) throws -> String? {
        let key = cacheKey(for: storageKey)

        // read-through：新鲜命中（含负缓存）直接返回，不访问 Keychain。
        if let entry = cache.entry(forKey: key, maxAge: cacheLifetime) {
            return entry.value
        }

        // 回源路径按 key 串行化；double-check 先行者刚写入的缓存。
        let lock = keyLock(for: key)
        lock.lock()
        defer { lock.unlock() }

        if let entry = cache.entry(forKey: key, maxAge: cacheLifetime) {
            return entry.value
        }

        do {
            let value: String?
            if retryMissing {
                value = try readWithMissingRetry(operation: {
                    try readOnce(storageKey: storageKey)
                })
            } else {
                value = try readOnce(storageKey: storageKey)
            }
            if let value {
                return value
            }
        } catch {
            // 如果当前查询路径暂时不可用，继续尝试最近一次已确认可用的值。
            return try staleFallback(forKey: key, error: error)
        }

        // macOS 的旧式 file-based Keychain 在无交互/锁定场景下可能把
        // 暂时不可访问表现为 not-found。只有多轮完整查询仍未命中才走到这里；
        // 对最近成功读取的 Key 做短期回退，避免中断正在进行的对话；确认无
        // 历史值时记录负缓存，让未配置 Key 的读取不必反复回源。
        if let known = cache.lastKnownEntry(forKey: key)?.value {
            cache.remember(known, forKey: key)  // 滑动续期，保持「短期回退」语义
            return known
        }
        cache.rememberMissing(forKey: key)
        return nil
    }

    /// stale-if-error 回退：Keychain 读取失败时旧值比中断对话更好；没有任何
    /// 历史值时才把错误抛给上层（保持「读取失败」与「不存在」可区分）。
    private static func staleFallback(forKey key: String, error: Error) throws -> String? {
        guard let known = cache.lastKnownEntry(forKey: key)?.value else {
            throw error
        }
        cache.remember(known, forKey: key)  // 滑动续期
        return known
    }

    private static func readOnce(storageKey: String) throws -> String? {
        var firstAccessError: Error?

        for (index, store) in stores().enumerated() {
            do {
                let value: String?
                // API Key 解析是**自动路径**（每次请求都可能触发），且会在
                // headless / 后台进程里执行。这里一律使用无提示读取：若某个
                // 历史条目需要用户授权，系统对话框在无界面进程中会永久阻塞
                // 该线程（表现为 ACP 回合卡死），因此宁可立即失败后走缓存/
                // 回退，也不弹窗。
                if index == 0 {
                    value = try store.loadMigratingLegacyUserDefaultsWithoutPromptReportingErrors(forKey: storageKey)
                } else {
                    value = try store.stringWithoutPromptReportingErrors(forKey: storageKey)
                }

                guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
                    continue
                }

                remember(value, for: storageKey)
                if index != 0 {
                    // 迁移失败不阻断当前请求；下次仍可从历史路径读取。
                    try? primaryStore().setReportingErrors(value, forKey: storageKey)
                }
                return value
            } catch {
                firstAccessError = firstAccessError ?? error
            }
        }

        if let firstAccessError {
            throw firstAccessError
        }
        return nil
    }

    /// 对完整的多存储查询做有限重试。KeychainStore 已经重试明确的临时
    /// OSStatus；这里另外覆盖「一次完整查询看起来全部 not-found」的情况。
    static func readWithMissingRetry(
        maxAttempts: Int = 3,
        sleeper: (UInt64) -> Void = { nanoseconds in
            Thread.sleep(forTimeInterval: TimeInterval(nanoseconds) / 1_000_000_000)
        },
        operation: () throws -> String?
    ) throws -> String? {
        guard maxAttempts > 0 else { return nil }
        var firstAccessError: Error?

        for attempt in 0..<maxAttempts {
            do {
                if let value = try operation() {
                    return value
                }
            } catch {
                firstAccessError = firstAccessError ?? error
            }

            if attempt < maxAttempts - 1 {
                sleeper(KeychainStore.transientRetryDelayNanoseconds(for: attempt))
            }
        }

        if let firstAccessError {
            throw firstAccessError
        }
        return nil
    }

    private static func bestEffortRead(storageKey: String) -> String? {
        do {
            return try read(storageKey: storageKey)
        } catch {
            return cache.lastKnownEntry(forKey: cacheKey(for: storageKey))?.value
        }
    }

    private static func remember(_ value: String, for storageKey: String) {
        cache.remember(value, forKey: cacheKey(for: storageKey))
    }

    private static func primaryStore() -> KeychainStore {
        KeychainStore(service: keychainService, useDataProtectionKeychain: true)
    }

    private static func legacyFileStore() -> KeychainStore {
        KeychainStore(service: keychainService)
    }

    private static func stores() -> [KeychainStore] {
        var result = [primaryStore()]

        // 历史 Lumi service 的 file-based Keychain 条目。
        result.append(legacyFileStore())

        // KitLLM 提取期间错误使用过的 service，仅读取并迁移。
        if keychainService != extractedKitLLMService {
            result.append(KeychainStore(service: extractedKitLLMService))
        }
        return result
    }
}
