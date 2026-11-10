import Foundation

/// IMAP UID 的协议边界与共享校验。
///
/// RFC 3501 规定 UID 是 1...2^32-1 的非零 32 位无符号整数，MailCore 的
/// 操作接口也只接受 `UInt32`。所有从 `UInt64` 收窄到 `UInt32` 的位置都必须
/// 先经过这里，避免 `UInt32(_:)` 在越界输入上触发 trap。
public enum MailUID {
    /// 协议允许的最大 UID。
    public static let maximum: UInt64 = UInt64(UInt32.max)

    /// 校验并收窄到 IMAP 的 32 位 UID。
    /// - Parameter uid: 待校验的 UID（0 与超过 `UInt32.max` 的值都非法）。
    /// - Returns: 合法时返回 `UInt32`；非法时返回 nil。
    public static func validated(_ uid: UInt64) -> UInt32? {
        guard uid >= 1, uid <= maximum else { return nil }
        return UInt32(uid)
    }
}
