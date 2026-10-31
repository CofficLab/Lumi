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
/// 判定顺序：
/// 1. 显式白名单（设置界面「允许」，聊天卡片「始终允许」共用）→ 放行；
/// 2. 一次性授权（聊天卡片「允许一次」）→ 消费并放行；
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
    /// - Returns: 判定结果。
    func outcome(
        for bundleIdentifier: String,
        applicationName: String
    ) -> ComputerUseAccessOutcome {
        guard !bundleIdentifier.isEmpty else {
            return .forbidden(reason: pluginLocalization.string("Unknown application."))
        }
        if authorization.isAllowed(bundleIdentifier) {
            return .allowed
        }
        // 一次性授权在检查时即被消费：只对紧接着的这一步操作有效。
        if authorization.consumeOneShot(bundleIdentifier: bundleIdentifier) {
            return .allowed
        }
        return .needsAuthorization(
            applicationName: applicationName,
            bundleIdentifier: bundleIdentifier
        )
    }

    /// 不消费一次性授权的只读判定。
    ///
    /// 用于「是否已有授权」这类展示性查询，避免仅仅查看状态就消耗掉授权。
    func isAuthorizedWithoutConsuming(_ bundleIdentifier: String) -> Bool {
        authorization.isAllowed(bundleIdentifier)
            || authorization.hasValidOneShot(bundleIdentifier: bundleIdentifier)
    }
}
