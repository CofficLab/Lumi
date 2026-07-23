import Foundation
import LumiKernel
import SuperLogKit
import os

/// Projects 插件
///
/// 向 LumiKernel 注册项目管理相关的功能：
/// - ProjectService：项目状态管理服务
/// - TitleToolbarItem：标题栏项目控制视图
/// - AgentTools：list_projects, add_project, get_current_project
/// - SendMiddleware：ConversationHintMiddleware
@MainActor
public final class ProjectsPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.projects")
    nonisolated public static let emoji = "📂"
    nonisolated static let verbose = false

    // MARK: - LumiPlugin

    public let id = "com.coffic.lumi.plugin.projects"
    public let name = "Projects Plugin"
    public let order = 20
    public static let policy: LumiPluginPolicy = .disabled  // 核心插件

    // MARK: - Initialization

    public init() {}

    // MARK: - LumiPlugin

    public func onReady(kernel: LumiKernel) throws {
        try ProjectsOnReadyHook(pluginID: id).execute(kernel)
    }

    public func boot(kernel: LumiKernel) async throws {
        try await ProjectsOnBootHook().execute(kernel)
    }
}
