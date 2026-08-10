import Foundation
import KeychainKit
import LumiKernel
import Security
import os

/// API Key 存储。
///
/// 在通用的 `KeychainStore` 之上固定一个专属的 Keychain `service`
/// (`com.coffic.lumi.apikey`)，保证历史版本写入的 key 仍可被读到——
/// keychain 按 `(service, account)` 寻址，service 一旦改变旧数据就读不到，
/// 因此这里**不能**使用 `KeychainStore.shared`（其 service 为空）。
public final class APIKeyStore: @unchecked Sendable {
    public static let shared = APIKeyStore()

    /// 历史正式版 service；Debug 会在运行时追加独立后缀。
    static let service = "com.coffic.lumi.apikey"

    private let store: KeychainStore
    private let defaults: UserDefaults
    private let sleeper: (UInt64) -> Void
    private let cache: APIKeyCache
    private let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "llm.apikey-store"
    )

    /// Delays used only when a key that was previously confirmed as configured
    /// is unexpectedly reported as missing.
    static let missingConfirmationDelaysNanoseconds: [UInt64] = [
        50_000_000,
        100_000_000,
        200_000_000,
    ]

    public init(
        store: KeychainStore? = nil,
        defaults: UserDefaults = .standard,
        sleeper: @escaping (UInt64) -> Void = { nanoseconds in
            Thread.sleep(forTimeInterval: TimeInterval(nanoseconds) / 1_000_000_000)
        }
    ) {
        self.store = store ?? KeychainStore(
            service: LumiRuntimeEnvironment.current.keychainService(for: Self.service)
        )
        self.defaults = defaults
        self.sleeper = sleeper
        self.cache = APIKeyCache()
    }

    /// 测试/启动期注入专用缓存（用于 in-memory 兜底独立验证）。
    init(
        store: KeychainStore,
        defaults: UserDefaults,
        sleeper: @escaping (UInt64) -> Void,
        cache: APIKeyCache
    ) {
        self.store = store
        self.defaults = defaults
        self.sleeper = sleeper
        self.cache = cache
    }

    public func string(forKey key: String) -> String? {
        try? stringReportingErrors(forKey: key)
    }

    /// 读取 key 的同时保留 Keychain 错误；额外返回缓存状态，调用方可决定
    /// 是否向用户呈现"暂不可用"等降级提示。
    public func stringReportingErrors(forKey key: String) throws -> String? {
        try loadMigratingLegacyUserDefaultsReportingErrors(forKey: key)
    }

    public func set(_ value: String, forKey key: String) {
        try? setReportingErrors(value, forKey: key)
    }

    public func setReportingErrors(_ value: String, forKey key: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        try store.setReportingErrors(trimmed, forKey: key)
        if trimmed.isEmpty {
            markExpectedConfigured(false, forKey: key)
            cache.remove(forKey: key)
        } else {
            markExpectedConfigured(true, forKey: key)
            cache.store(trimmed, forKey: key)
        }
    }

    public func remove(forKey key: String) {
        try? removeReportingErrors(forKey: key)
    }

    public func removeReportingErrors(forKey key: String) throws {
        try store.removeReportingErrors(forKey: key)
        markExpectedConfigured(false, forKey: key)
        cache.remove(forKey: key)
    }

    /// 读取 key；若 Keychain 中缺失则尝试从同名 UserDefaults 键迁移。
    public func loadMigratingLegacyUserDefaults(forKey key: String) -> String? {
        let value = store.loadMigratingLegacyUserDefaults(forKey: key)
        if let value, !value.isEmpty {
            markExpectedConfigured(true, forKey: key)
            cache.store(value, forKey: key)
        }
        return value
    }

    /// Reads the key while preserving Keychain access failures. A `nil` result
    /// means only that no key exists.
    ///
    /// 当 key 之前已确认配置过、但 Keychain 在重试窗口内持续返回"不存在"
    /// 或抛出错误时，会**回退到内存中上一次成功读取的值**，避免把
    /// `securityd` 短暂视图不一致呈现为"未配置"。
    public func loadMigratingLegacyUserDefaultsReportingErrors(forKey key: String) throws -> String? {
        let expectedConfigured = isExpectedConfigured(forKey: key)
        var statusTrace: [Int] = []

        for attempt in 0...Self.missingConfirmationDelaysNanoseconds.count {
            do {
                if let value = try store.loadMigratingLegacyUserDefaultsReportingErrors(
                    forKey: key,
                    observedStatus: { observedStatus in statusTrace.append(Int(observedStatus)) }
                )?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                    !value.isEmpty {
                    markExpectedConfigured(true, forKey: key)
                    cache.store(value, forKey: key)
                    return value
                }
            } catch let error as KeychainStoreError {
                statusTrace.append(Self.statusFromKeychainError(error))
                guard expectedConfigured, attempt < Self.missingConfirmationDelaysNanoseconds.count else {
                    throw APIKeyStoreError.expectedItemMissing(
                        account: key,
                        attempts: attempt + 1,
                        lastStatus: Self.statusFromKeychainError(error),
                        statusTrace: statusTrace
                    )
                }
                sleeper(Self.missingConfirmationDelaysNanoseconds[attempt])
                continue
            }

            guard expectedConfigured else {
                return nil
            }

            if attempt < Self.missingConfirmationDelaysNanoseconds.count {
                sleeper(Self.missingConfirmationDelaysNanoseconds[attempt])
            }
        }

        // expected-configured 但 4 次都返回 missing —— 回退内存缓存。
        if let cached = cache.value(forKey: key), !cached.isEmpty {
            logger.warning(
                "Keychain reported '\(key, privacy: .public)' missing after \(Self.missingConfirmationDelaysNanoseconds.count + 1) attempts; returning cached value (statusTrace=\(statusTrace, privacy: .public))"
            )
            throw APIKeyStoreError.expectedItemMissing(
                account: key,
                attempts: Self.missingConfirmationDelaysNanoseconds.count + 1,
                lastStatus: Int(errSecItemNotFound),
                statusTrace: statusTrace,
                servedFromCache: cached
            )
        }

        logger.warning(
            "Keychain item '\(key, privacy: .public)' previously configured but was reported missing after \(Self.missingConfirmationDelaysNanoseconds.count + 1) read attempts (statusTrace=\(statusTrace, privacy: .public))"
        )
        throw APIKeyStoreError.expectedItemMissing(
            account: key,
            attempts: Self.missingConfirmationDelaysNanoseconds.count + 1,
            lastStatus: Int(errSecItemNotFound),
            statusTrace: statusTrace
        )
    }

    private func isExpectedConfigured(forKey key: String) -> Bool {
        defaults.bool(forKey: expectationDefaultsKey(for: key))
    }

    private func markExpectedConfigured(_ expected: Bool, forKey key: String) {
        defaults.set(expected, forKey: expectationDefaultsKey(for: key))
    }

    private func expectationDefaultsKey(for key: String) -> String {
        "com.coffic.lumi.apikey.expected-configured.\(key)"
    }

    private static func statusFromKeychainError(_ error: KeychainStoreError) -> Int {
        switch error {
        case .readFailed(let status), .writeFailed(let status), .deleteFailed(let status):
            return Int(status)
        case .missingDataForSuccessfulRead:
            return Int(errSecSuccess)
        case .invalidStringData:
            return -1
        }
    }
}

/// 进程内 API Key 内存缓存。
///
/// 用于在 `securityd` 短暂视图不一致（典型为长跑后返回假的
/// `errSecItemNotFound`）时，兜底最近一次确认过的 key 值。
/// 仅作为抖动兜底，**不是**对 Keychain 的替代。
final class APIKeyCache: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: String] = [:]

    func store(_ value: String, forKey key: String) {
        lock.withLock { values[key] = value }
    }

    func value(forKey key: String) -> String? {
        lock.withLock { values[key] }
    }

    func remove(forKey key: String) {
        lock.withLock { _ = values.removeValue(forKey: key) }
    }

    func removeAll() {
        lock.withLock { values.removeAll() }
    }
}

public enum APIKeyStoreError: LocalizedError, Sendable, Equatable {
    /// 重试窗口耗尽后底层仍持续报告"不存在"或其他错误。
    ///
    /// - `lastStatus` 是最后一次 `SecItemCopyMatching` 的 OSStatus；为 0
    ///   时表示 4 次都是 `errSecSuccess` 但未返回数据（极少见）。
    /// - `statusTrace` 是每次重试最后一次尝试的 OSStatus 序列，可用于
    ///   区分"持续 missing"和"中途瞬时失败"等不同故障模式。
    /// - `servedFromCache` 非空时表示已用内存缓存兜底；上层可以无感放行
    ///   而非当作"未配置"错误。
    case expectedItemMissing(
        account: String,
        attempts: Int,
        lastStatus: Int,
        statusTrace: [Int],
        servedFromCache: String? = nil
    )

    public var errorDescription: String? {
        switch self {
        case .expectedItemMissing(
            let account,
            let attempts,
            let lastStatus,
            let statusTrace,
            let servedFromCache
        ):
            let traceDescription = statusTrace.isEmpty
                ? "n/a"
                : statusTrace.map { String($0) }.joined(separator: ",")
            let cacheNote = servedFromCache == nil
                ? ""
                : " (served from in-memory cache)"
            return "Keychain item '\(account)' was previously configured but was reported missing after \(attempts) read attempts; last OSStatus=\(lastStatus), trace=[\(traceDescription)]\(cacheNote)"
        }
    }

    /// 若错误是用内存缓存兜底产生的，返回缓存值；否则 nil。
    public var cachedValue: String? {
        if case let .expectedItemMissing(_, _, _, _, cached?) = self {
            return cached
        }
        return nil
    }
}