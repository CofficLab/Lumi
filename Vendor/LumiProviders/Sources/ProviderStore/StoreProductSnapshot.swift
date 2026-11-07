import Foundation

// MARK: - Store Product Kind

/// 商品类别。
///
/// 与 StoreKit 的商品类型一一对应，但**不引用** StoreKit 类型：共享契约层
/// 必须能在没有 StoreKit 的环境（单元测试、其他平台）下编译。
public enum StoreProductKind: String, Sendable, Codable, CaseIterable {
    /// 消耗品（可重复购买）。
    case consumable
    /// 非消耗品（一次性解锁，永久有效）。
    case nonConsumable
    /// 自动续期订阅。
    case autoRenewable
    /// 非续期订阅（有固定有效期）。
    case nonRenewable
    /// 未知类别。
    case unknown

    /// 是否为订阅类商品（自动续期或非续期）。
    public var isSubscription: Bool {
        self == .autoRenewable || self == .nonRenewable
    }
}

// MARK: - Store Product Snapshot

/// 商品快照：商店商品的**中立**表示。
///
/// 不暴露 `StoreKit.Product`（它是引用类型、不可 `Sendable`、且绑定
/// StoreKit 框架）。快照只保留展示与决策真正需要的字段，因此可以跨层传递、
/// 缓存、放进 `Sendable` 上下文。
///
/// ## 价格是字符串
///
/// `price` 存**本地化后的价格字符串**（如 `¥68.00`）而非 `Decimal`：
/// 展示层直接用它渲染即可，且不必在契约层引入货币格式化规则——各项目的
/// 货币与文案口径不同。
public struct StoreProductSnapshot: Identifiable, Sendable, Equatable, Codable {
    /// 商品 ID（各项目在自己的商品表里用它映射档位）。
    public let id: String

    /// 展示名称。
    public let displayName: String

    /// 本地化价格字符串。
    public let price: String

    /// 商品类别。
    public let kind: StoreProductKind

    /// 该商品购买的档位；不授予任何权益时为 `.none`。
    public let tier: StoreTier

    /// 商品描述。
    public let productDescription: String

    public init(
        id: String,
        displayName: String,
        price: String,
        kind: StoreProductKind,
        tier: StoreTier = .none,
        productDescription: String = ""
    ) {
        self.id = id
        self.displayName = displayName
        self.price = price
        self.kind = kind
        self.tier = tier
        self.productDescription = productDescription
    }

    /// 是否为订阅类商品。
    public var isSubscription: Bool { kind.isSubscription }

    /// 该商品是否授予付费权益。
    ///
    /// 购买面板据此决定展示哪些商品——只展示真正能带来权益的商品，
    /// 避免用户买了却发现「还是免费版」。
    public var grantsEntitlement: Bool { tier > .none }
}
