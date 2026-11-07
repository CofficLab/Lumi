import Foundation

// MARK: - Store Tier

/// 订阅档位（商店权益等级）。
///
/// 档位是**有序**的：`pro > none`、`ultimate > pro`。消费方可以直接用
/// 比较运算符表达「至少 Pro」这类规则，而不必枚举所有情况。
///
/// ## 为什么是共享契约
///
/// 「用户现在是什么档位」是跨项目共性问题（容量上限、功能开关、限额提示）。
/// 各项目各写一份枚举，会导致：
/// - 同一个概念在不同项目里名字不同（`SubscriptionTier` / `StoreTier`），
///   迁移时要么逐处改名，要么长期维护别名；
/// - 档位语义漂移：某个项目把「过期」算作有效档位，另一个不算。
///
/// 把档位放进共享契约层，各项目的商店实现只需把自己的商品表映射到
/// 这里定义的档位即可。
public enum StoreTier: Int, Comparable, Sendable, Codable, CaseIterable {
    /// 免费档（无订阅权益）。
    case none = 0
    /// 专业档。
    case pro = 1
    /// 旗舰档。
    case ultimate = 2

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// 是否为免费档。
    public var isFree: Bool { self == .none }

    /// 是否至少为专业档。
    public var isProOrHigher: Bool { self >= .pro }

    /// 是否为旗舰档及以上。
    public var isUltimateOrHigher: Bool { self >= .ultimate }

    /// 档位的默认显示名（英文）。
    ///
    /// 共享契约层只提供**默认英文文案**，各 App 可以覆写为自己的本地化版本
    /// （见各 App 的 `StoreTier+Display` 扩展）。这样消费方（如限额提示）
    /// 在任何项目里都能拿到一个可用的名称，而不必自己判断档位。
    public var defaultDisplayName: String {
        switch self {
        case .none: return "Free version"
        case .pro: return "Pro version"
        case .ultimate: return "Ultimate version"
        }
    }
}

// MARK: - Store Entitlement Snapshot

/// 订阅权益快照：某一时刻的「档位 + 有效期」。
///
/// 这是**值语义**的只读结论，不含任何 StoreKit 类型（`Transaction`、
/// `Product`、`VerificationResult` 一律不出现），因此可以被任何层读取、
/// 缓存、跨进程传递。
///
/// ## 过期即免费
///
/// `effectiveTier` 是**判定权益时唯一该用的属性**：过期订阅等价于免费档，
/// 而不是「曾经买过」。`isExpired` 的判定留出 60 秒宽限，避免续费瞬间
/// 因时钟与商店服务端状态不同步而误判为过期。
public struct StoreEntitlementSnapshot: Sendable, Equatable, Codable {
    /// 原始档位（不经过过期判定）。
    public let tier: StoreTier

    /// 权益到期时间；`nil` 表示没有有效的付费权益。
    public let expiresAt: Date?

    public init(tier: StoreTier, expiresAt: Date?) {
        self.tier = tier
        self.expiresAt = expiresAt
    }

    /// 空权益（免费档）。
    public static let none = StoreEntitlementSnapshot(tier: .none, expiresAt: nil)

    /// 是否已过期。
    ///
    /// - `expiresAt == nil`：视为过期（没有有效期就谈不上有效）。
    /// - 距到期不足 60 秒：视为**未过期**（宽限期）。
    public var isExpired: Bool {
        guard let expiresAt else { return true }
        // 到期时刻已过去超过 60 秒才算过期；不足 60 秒仍在宽限期内。
        return expiresAt.timeIntervalSinceNow < -60
    }

    /// 是否为「未过期的付费档位」。
    ///
    /// 这是消费方最常用的结论：能否使用受限功能。
    public var isProOrHigher: Bool {
        guard tier >= .pro else { return false }
        return !isExpired
    }

    /// 是否**不**满足付费档位条件。
    ///
    /// 取反判断在 UI 里很常见（「免费用户才显示限额提示」），显式提供比
    /// 到处写 `!snapshot.isProOrHigher` 更清晰。
    public var isNotProOrHigher: Bool {
        !isProOrHigher
    }

    /// 生效档位：未过期才按 `tier` 生效，否则回落到免费档。
    public var effectiveTier: StoreTier {
        isProOrHigher ? tier : .none
    }
}
