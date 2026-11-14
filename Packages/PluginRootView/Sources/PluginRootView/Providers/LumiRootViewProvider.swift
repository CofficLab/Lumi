import LumiLoggingKit
import os
import WorkbenchRootView

/// Lumi 的根视图 provider：工作台外壳本身来自共享包 `WorkbenchRootView`，
/// 这里只注入 Lumi 的日志子系统与品牌信息。
@MainActor
public final class LumiRootViewProvider: WorkbenchRootViewProviding, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.provider-root-view", category: "ProviderRootView")
    nonisolated public static let emoji = "🏠"
    nonisolated static let verbose = false

    public init() {
        super.init(
            layout: .standard,
            loggerSubsystem: "com.coffic.lumi.provider-root-view"
        )
        if Self.verbose {
            Self.logger.info("\(self.t)DefaultRootViewProviding initialized")
        }
    }
}

/// Compatibility name for existing Lumi factories and tests.
public typealias DefaultRootViewProvider = LumiRootViewProvider
