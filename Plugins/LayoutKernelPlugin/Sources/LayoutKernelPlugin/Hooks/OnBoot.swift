import Foundation
import LumiKernel
import os
import SuperLogKit

/// LayoutKernel 插件 OnBoot 阶段钩子
///
/// 负责 boot 阶段的核心 Layout 服务注册,确保在 onReady 之前内核已持有 LayoutProviding。
/// 同时从磁盘恢复布局状态到内存。
@MainActor
public struct LayoutKernelOnBootHook: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.layout")
    nonisolated static let verbose = true

    public init() {}

    /// 执行 boot
    public func execute(_ kernel: LumiKernel) async throws {
        let store = LayoutStore(pluginDirectory: kernel.storage?.pluginDataDirectory(for: "LayoutKernel"))
        let manager = LayoutManager(store: store)

        // 从磁盘恢复布局状态
        if let info = store.loadLayoutInfo() {
            if Self.verbose {
                Self.logger.info("\(Self.t)恢复布局: activeViewContainerID=\(info.activeViewContainerID ?? "nil")")
            }
            if let containerID = info.activeViewContainerID {
                manager.layoutState.activeViewContainerID = containerID
            }
            manager.layoutState.isChatVisible = info.chatSectionVisible
            manager.layoutState.isRailVisible = info.railVisible
            manager.layoutState.isContentVisible = info.contentVisible
            manager.layoutState.isPanelVisible = info.panelVisible
            manager.layoutState.isPanelBottomVisible = info.panelBottomVisible
            // 恢复每个容器上次的 rail/bottom tab 选中（不发送通知，静默灌入内存）。
            for (containerID, railTabID) in info.activeRailTabIDs {
                manager.layoutState.restoreActiveRailTabID(railTabID, for: containerID)
            }
            for (containerID, bottomTabID) in info.activeBottomTabIDs {
                manager.layoutState.restoreActiveBottomTabID(bottomTabID, for: containerID)
            }
            // 恢复每个容器用户手动调整过的可见性覆盖。
            manager.layoutState.restoreVisibilityOverrides(info.visibilityOverrides)
        } else {
            if Self.verbose {
                Self.logger.info("\(Self.t)无已保存布局，使用默认值")
            }
        }

        kernel.registerLayout(manager)

        if Self.verbose {
            Self.logger.info("\(Self.t)Layout service registered successfully")
        }
    }
}
