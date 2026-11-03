import Foundation

/// 应用访问授权的三态判定结果。
enum ComputerUseAccessOutcome: Equatable {
    /// 已授权，可以继续操作。
    case allowed

    /// 未授权，但可以向用户申请授权。调用方应挂起回合并展示授权卡片。
    case needsAuthorization(applicationName: String, bundleIdentifier: String)

    /// 命中了明确禁止的场景，不可申请授权。
    case forbidden(reason: String)
}

/// 统一的授权判定器。
///
/// 这是「某个应用现在能不能被操作」的唯一判定入口。所有执行路径
/// （截图、AX 读、AX 写、原生输入）都必须经过它，避免各处自行判断导致
/// 授权语义不一致。
///
/// ## 判定顺序
///
/// 1. **A3（自主会话）** → 直接放行。用户已经通过选择模式表达过充分授权，
///    再弹卡片会让自主模式名存实亡。
/// 2. **会话内访问授权**（A2 会话里用户点过「允许」）→ 放行。
/// 3. 否则 → 需要用户授权。
///
/// - Note: 不做 actor 隔离。存储本身是线程安全的，而执行路径既有
///   MainActor 的也有非隔离的，隔离会让非隔离调用点无法使用这个判定器。
struct ComputerUseAccessChecker: Sendable {
    let authorization: ComputerUseAuthorizationStore

    init(authorization: ComputerUseAuthorizationStore = .shared) {
        self.authorization = authorization
    }

    /// 判断目标应用当前是否可访问。
    ///
    /// - Parameters:
    ///   - bundleIdentifier: 目标应用。
    ///   - applicationName: 目标应用显示名，用于卡片展示。
    ///   - context: 本次操作的会话上下文（会话 ID 与自动化等级）。
    /// - Returns: 判定结果。
    func outcome(
        for bundleIdentifier: String,
        applicationName: String,
        context: ComputerUseAccessContext
    ) -> ComputerUseAccessOutcome {
        guard !bundleIdentifier.isEmpty else {
            return .forbidden(reason: pluginLocalization.string("Unknown application."))
        }
        // A3 免打扰：自主会话里用户已充分授权，不再产生任何授权卡片。
        if context.allowsUnattendedAccess {
            return .allowed
        }
        // A2：会话内授权一次即可，后续访问不再打扰。
        if authorization.hasSessionAccess(
            bundleIdentifier: bundleIdentifier,
            conversationID: context.conversationID
        ) {
            return .allowed
        }
        return .needsAuthorization(
            applicationName: applicationName,
            bundleIdentifier: bundleIdentifier
        )
    }

    /// 是否已获授权（不消费任何状态）。
    ///
    /// 用于「是否已有授权」这类展示性查询。
    func isAuthorizedWithoutConsuming(
        _ bundleIdentifier: String,
        context: ComputerUseAccessContext
    ) -> Bool {
        if context.allowsUnattendedAccess { return true }
        return authorization.hasSessionAccess(
            bundleIdentifier: bundleIdentifier,
            conversationID: context.conversationID
        )
    }
}
