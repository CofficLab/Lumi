import Foundation
import LumiKernel
import SuperLogKit
import SwiftUI
import os

/// ViewContainer 插件
///
/// 提供 ViewContainerProviding 服务的默认实现。
/// 负责管理所有插件的 ViewContainer 注册、排序、查询和激活状态。
@MainActor
public final class ViewContainerPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.viewcontainer")
    nonisolated public static let emoji = "🗂️"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.viewcontainer"
    public let name = "ViewContainer Plugin"
    public let order = 10
public static let policy: LumiPluginPolicy = .disabled  // 核心插件，优先注册

    // MARK: - State

    private var viewContainerService: DefaultViewContainerProviding?

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func onReady(kernel: LumiKernel) throws {
        // 1. 注册 ViewContainerService（内核服务）
        let viewContainerServiceInstance = DefaultViewContainerProviding()
        kernel.registerViewContainerService(viewContainerServiceInstance)
        self.viewContainerService = viewContainerServiceInstance

        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 ViewContainer 插件到内核")
        }
    }

    public func boot(kernel: LumiKernel) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)ViewContainer 插件启动完成")
        }
    }
}
