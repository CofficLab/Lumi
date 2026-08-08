import Foundation
import LumiKernel
import os
import SuperLogKit

/// LayoutKernel 插件 OnBoot 阶段钩子
///
/// 负责 boot 阶段的核心工作区服务注册,确保在 onReady 之前内核已持有 WorkspaceProviding。
/// 同时从磁盘恢复布局状态到内存。
@MainActor
public struct LayoutKernelOnBootHook: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.layout")
    nonisolated static let verbose = false

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
                manager.activeViewContainerID = containerID
            }
            manager.isChatVisible = info.chatSectionVisible
            manager.isRailVisible = info.railVisible
            manager.isPanelBottomVisible = info.panelBottomVisible
            // 恢复每个容器上次的 rail/bottom tab 选中（不发送通知，静默灌入内存）。
            for (containerID, railTabID) in info.activeRailTabIDs {
                manager.restoreActiveRailTabID(railTabID, for: containerID)
            }
            for (containerID, bottomTabID) in info.activeBottomTabIDs {
                manager.restoreActiveBottomTabID(bottomTabID, for: containerID)
            }
            // 恢复每个容器用户手动调整过的可见性覆盖。
            manager.restoreVisibilityOverrides(info.visibilityOverrides)
            // 恢复每个容器的 split 尺寸到内核内存，UI 激活容器后按 ID 读取。
            for (containerID, position) in info.railDividers {
                manager.restoreRailDivider(position, for: containerID)
            }
            for (key, position) in info.chatSectionDividers {
                let parts = key.split(separator: ".", maxSplits: 1).map(String.init)
                guard parts.count == 2,
                      let layout = LumiChatSectionLayout.from(persistenceKeySuffix: parts[1])
                else { continue }
                manager.restoreChatSectionDivider(position, for: parts[0], layout: layout)
            }
            for (containerID, position) in info.bottomPanelDividers {
                manager.restoreBottomPanelDivider(position, for: containerID)
            }
        } else {
            if Self.verbose {
                Self.logger.info("\(Self.t)无已保存布局，使用默认值")
            }
        }

        try kernel.registerWorkspace(manager)

        if Self.verbose {
            Self.logger.info("\(Self.t)Workspace service registered successfully")
        }
    }
}
