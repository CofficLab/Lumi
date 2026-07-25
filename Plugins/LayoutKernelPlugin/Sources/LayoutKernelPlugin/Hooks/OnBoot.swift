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
        let manager = LayoutManager()

        // 从磁盘恢复布局状态
        if let info = store.loadLayoutInfo() {
            if Self.verbose {
                Self.logger.info("\(Self.t)恢复布局: activeSectionID=\(info.activeSectionID), chatSectionVisible=\(info.chatSectionVisible)")
            }
            manager.layoutState.activeSectionID = info.activeSectionID
            manager.layoutState.activeSectionTitle = info.activeSectionTitle
            manager.layoutState.isChatVisible = info.chatSectionVisible
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
