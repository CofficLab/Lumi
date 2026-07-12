import Foundation
import Security

/// Keychain 读取操作的分类结果。
///
/// 区分四种情况，是修复「钥匙串瞬时不可用被误判为 API Key 未配置」的关键：
/// - `found`：读到数据，正常。
/// - `missing`：项不存在（`errSecItemNotFound`），用户确实未配置。
/// - `transientFailure`：钥匙串瞬时不可用（锁定/鉴权失败/设备锁定），**重试可恢复**。
/// - `unexpected`：其他未预期的状态码，按缺失处理但保留状态码便于诊断。
public enum KeychainReadOutcome: Sendable, Equatable {
    case found(Data)
    case missing
    case transientFailure(OSStatus)
    case unexpected(OSStatus)
}

/// 把 `SecItemCopyMatching` 的原始 `(status, data)` 映射为结构化的读取结果。
///
/// 这是纯函数、无副作用，是整个修复中最该被单元测试覆盖的逻辑。
/// 把它从 `LumiAPIKeyStore` 抽出来，正是为了让「瞬时失败」判定可测、可回归。
public func classifyKeychainReadResult(status: OSStatus, data: Data?) -> KeychainReadOutcome {
    switch status {
    case errSecSuccess:
        guard let data else { return .missing }
        return .found(data)
    case errSecItemNotFound:
        return .missing
    case errSecInteractionNotAllowed, errSecAuthFailed,
         errSecInteractionRequired, errSecDataNotAvailable:
        return .transientFailure(status)
    default:
        return .unexpected(status)
    }
}
