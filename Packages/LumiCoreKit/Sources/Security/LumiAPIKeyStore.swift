import Foundation
import Security

/// Secure API key storage backed by the system Keychain.
///
/// 读写均经过 `LumiKeychainBackend` 抽象，对 `transientFailure`（钥匙串瞬时不可用）
/// 做有限次静默重试，避免把 `securityd` 抖动误判成「API Key 未配置」。
public final class LumiAPIKeyStore: @unchecked Sendable {
    public static let shared = LumiAPIKeyStore()

    private let service = "com.coffic.lumi.apikey"
    private let backend: any LumiKeychainBackend
    private let sleeper: (UInt64) -> Void

    /// 重试上限（含首次读取）。瞬时失败最坏情况下的总尝试次数。
    static let maxTransientAttempts = 4

    public init(
        backend: any LumiKeychainBackend = SystemKeychainBackend(),
        sleeper: @escaping (UInt64) -> Void = { nanoseconds in
            Thread.sleep(forTimeInterval: TimeInterval(nanoseconds) / 1_000_000_000)
        }
    ) {
        self.backend = backend
        self.sleeper = sleeper
    }

    public func string(forKey key: String) -> String? {
        guard !key.isEmpty else { return nil }

        for attempt in 0..<Self.maxTransientAttempts {
            let result = backend.read(service: service, account: key)
            switch classifyKeychainReadResult(status: result.status, data: result.data) {
            case .found(let data):
                return String(data: data, encoding: .utf8)
            case .missing, .unexpected:
                return nil
            case .transientFailure:
                // 最后一次不再 sleep，直接以 missing 处理。
                if attempt < Self.maxTransientAttempts - 1 {
                    sleeper(Self.transientRetryDelayNanoseconds(for: attempt))
                    continue
                }
                return nil
            }
        }
        return nil
    }

    public func set(_ value: String, forKey key: String) {
        guard !key.isEmpty else { return }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            remove(forKey: key)
            return
        }

        _ = backend.write(Data(trimmed.utf8), service: service, account: key)
    }

    public func remove(forKey key: String) {
        guard !key.isEmpty else { return }
        _ = backend.delete(service: service, account: key)
    }

    /// Reads from Keychain, migrating a legacy UserDefaults value when present.
    ///
    /// 兼容两层旧数据：
    /// 1. 当前 Keychain 键
    /// 2. 旧版 UserDefaults 键（与当前键同名，老版本曾用 UserDefaults 存 key）→ 自动迁到 Keychain
    public func loadMigratingLegacyUserDefaults(forKey key: String) -> String? {
        guard !key.isEmpty else { return nil }

        // 1. 当前 Keychain 键
        if let keychainValue = string(forKey: key)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !keychainValue.isEmpty {
            return keychainValue
        }

        // 2. 旧版 UserDefaults 键（与当前键同名）→ 迁到 Keychain
        if let legacyUserDefaultsValue = UserDefaults.standard.string(forKey: key)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !legacyUserDefaultsValue.isEmpty {
            set(legacyUserDefaultsValue, forKey: key)
            UserDefaults.standard.removeObject(forKey: key)
            return legacyUserDefaultsValue
        }

        return nil
    }

    /// 指数退避：50ms → 100ms → 200ms ...（attempt 为 0-based）。
    /// 单独提为方法以便测试断言退避节奏。
    static func transientRetryDelayNanoseconds(for attempt: Int) -> UInt64 {
        let milliseconds = 50 * Int(pow(2.0, Double(attempt)))
        return UInt64(milliseconds) * 1_000_000
    }
}
