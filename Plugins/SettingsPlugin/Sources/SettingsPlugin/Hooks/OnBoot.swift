import Foundation
import LumiKernel
import SuperLogKit
import os

/// Settings 插件 OnBoot 阶段钩子
///
/// 负责 boot 阶段的 Settings 服务注册,确保在 onReady 之前内核已持有 SettingsProviding。
@MainActor
public struct SettingsOnBootHook {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.settings")
    nonisolated static let verbose = true

    public init() {}

    /// 执行 boot
    public func execute(_ kernel: LumiKernel) async throws {
        // 1. 注册 SettingsService（内核服务）
        let settingsServiceInstance = DefaultSettingsProviding()
        try kernel.registerSettingsService(settingsServiceInstance)
    }
}
