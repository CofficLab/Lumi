import Foundation
import LumiKernel
import os
import SuperLogKit

/// 布局服务实现
@MainActor
public final class LayoutService: LayoutProviding, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.layout.service")
    nonisolated public static let emoji = "📐"
    nonisolated static let verbose = false

    /// 布局状态（用于持久化）
    @Published public var state: LayoutStateInfo

    /// 原始布局状态（用于视图绑定）
    public let layoutState: LayoutState

    public init(initialState: LayoutStateInfo = LayoutStateInfo()) {
        self.state = initialState
        self.layoutState = LayoutState()

        if Self.verbose {
            Self.logger.info("LayoutService initialized")
        }
    }

    public func updateLayout(_ update: (inout LayoutStateInfo) -> Void) {
        if Self.verbose {
            Self.logger.info("updateLayout called")
        }
        update(&state)
        if Self.verbose {
            Self.logger.info("updateLayout completed")
        }
    }
}
