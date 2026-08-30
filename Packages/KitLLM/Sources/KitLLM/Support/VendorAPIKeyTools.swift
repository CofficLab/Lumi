import Foundation
@_implementationOnly import KitKeychain

/// API Key 管理工具。
///
/// API Key 使用 macOS Data Protection Keychain，并保留旧 service 的只读
/// 回退路径，以便从历史版本平滑迁移。读取失败和「条目不存在」必须保持
/// 可区分，否则 Keychain 的瞬时不可用会被误报为用户没有配置 Key。
public enum VendorAPIKeyTools {

    /// Lumi 正式使用的 Keychain service；保持与历史版本一致。
    nonisolated(unsafe) public static var keychainService = "com.coffic.lumi.apikey"

    /// `KitLLM` 提取期间曾使用过的临时 service，保留只读迁移能力。
    private static let extractedKitLLMService = "com.kit.llm.apikey"

    /// 已成功读取过的值只在当前进程内短暂缓存，用于抵抗 Keychain 服务的
    /// 瞬时读取失败。删除或成功写入时同步更新，绝不写入 UserDefaults/日志。
    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var cachedAPIKeys: [String: String] = [:]

    /// 从 Keychain 解析 API Key；未配置时抛错。
    public static func resolve(storageKey: String?, displayName: String) throws -> String {
        guard let storageKey, !storageKey.isEmpty else {
            throw VendorAPIError.missingAPIKey(displayName)
        }
        do {
            guard let key = try read(storageKey: storageKey)?
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
                return
            }
        }
        remember(trimmed, for: storageKey)
    }

    /// 删除 API Key。
    public static func remove(storageKey: String) {
        // 清理所有历史寻址路径，避免删除后又从旧 service 回退读出。
        for store in stores() {
            try? store.removeReportingErrors(forKey: storageKey)
        }
        cacheLock.lock()
        cachedAPIKeys.removeValue(forKey: cacheKey(for: storageKey))
        cacheLock.unlock()
    }

    // MARK: - Private

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

    private static func cacheKey(for storageKey: String) -> String {
        "\(keychainService)\u{0}\(storageKey)"
    }

    private static func read(storageKey: String) throws -> String? {
        var firstAccessError: Error?

        for (index, store) in stores().enumerated() {
            do {
                let value: String?
                if index == 0 {
                    value = try store.loadMigratingLegacyUserDefaultsReportingErrors(forKey: storageKey)
                } else {
                    value = try store.stringReportingErrors(forKey: storageKey)
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

        // 只有在本次读取明确遇到访问错误时才使用缓存；纯粹的 missing
        // 仍然代表用户已删除/从未配置，避免缓存复活已删除的 Key。
        if firstAccessError != nil, let cached = cachedValue(for: storageKey) {
            return cached
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
            return cachedValue(for: storageKey)
        }
    }

    private static func remember(_ value: String, for storageKey: String) {
        cacheLock.lock()
        cachedAPIKeys[cacheKey(for: storageKey)] = value
        cacheLock.unlock()
    }

    private static func cachedValue(for storageKey: String) -> String? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return cachedAPIKeys[cacheKey(for: storageKey)]
    }
}
