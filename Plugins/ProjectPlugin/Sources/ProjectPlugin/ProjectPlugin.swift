import Foundation
import LumiKernel
import SuperLogKit
import os

/// 项目插件
///
/// 向 LumiKernel 注册 Project 服务。
@MainActor
public final class ProjectPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.project")
    nonisolated public static let emoji = "📁"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.project"
    public let name = "Project Plugin"

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func register(kernel: LumiKernel) throws {
        let projectService = ProjectService()
        kernel.registerProject(projectService)
        if Self.verbose {
            Self.logger.info("\(Self.t)已注册 Project 服务")
        }
    }
}