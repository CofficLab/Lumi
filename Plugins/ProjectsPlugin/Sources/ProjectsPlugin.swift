import Foundation
import LumiCoreKit
import os
import SuperLogKit
import SwiftUI

public enum ProjectsPlugin: LumiPlugin, SuperLog {
    public nonisolated static let emoji = "📂"
    public nonisolated static let verbose: Bool = true

    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.projects")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.projects",
        displayName: LumiPluginLocalization.string("Projects", bundle: .module),
        description: LumiPluginLocalization.string("Adds a project manager control to the title toolbar.", bundle: .module),
        policy: .alwaysOn,
        stage: .beta,
    )

    /// 插件数据存储的子目录名称
    public static let dataDirectoryName = "Projects"

    // MARK: - Lifecycle Managed Instances

    @MainActor
    public static var store: ProjectsStore?

    @MainActor
    public static var syncCoordinator: ProjectsSyncCoordinator?

    @MainActor
    public static var viewModel: ProjectsViewModel?

    @MainActor
    public static func lifecycle(_ event: LumiPluginLifecycle, lumiCore: any LumiCoreAccessing) throws {
        switch event {
        case .didRegister:
            if Self.verbose {
                if ProjectsPlugin.verbose {
                    ProjectsPlugin.logger.info("\(Self.t)生命周期 didRegister：初始化 ProjectsPlugin")
                }
            }

            let directory = lumiCore.storage.pluginDataDirectory(for: dataDirectoryName)

            if Self.verbose {
                if ProjectsPlugin.verbose {
                    ProjectsPlugin.logger.info("\(Self.t)数据目录: \(directory.path)")
                }
            }

            // 初始化 Store
            let storeInstance = ProjectsStore(pluginDirectory: directory)
            Self.store = storeInstance

            if Self.verbose {
                if ProjectsPlugin.verbose {
                    ProjectsPlugin.logger.info("\(Self.t)✅ ProjectsStore 初始化完成")
                }
            }

            // 初始化 ViewModel
            let viewModelInstance = ProjectsViewModel(store: storeInstance)
            Self.viewModel = viewModelInstance

            if Self.verbose {
                if ProjectsPlugin.verbose {
                    ProjectsPlugin.logger.info("\(Self.t)✅ ProjectsViewModel 初始化完成")
                }
            }

            // 初始化 SyncCoordinator 并注入 LumiCore
            let coordinator = ProjectsSyncCoordinator(viewModel: viewModelInstance)
            coordinator.lumiCore = lumiCore
            Self.syncCoordinator = coordinator

            if Self.verbose {
                if ProjectsPlugin.verbose {
                    ProjectsPlugin.logger.info("\(Self.t)✅ ProjectsSyncCoordinator 初始化完成")
                }
            }

        case .willDisable:
            if Self.verbose {
                if ProjectsPlugin.verbose {
                    ProjectsPlugin.logger.info("\(Self.t)生命周期 willDisable：清理 ProjectsPlugin 状态")
                }
            }

            Self.store = nil
            Self.syncCoordinator = nil
            Self.viewModel = nil

            if Self.verbose {
                if ProjectsPlugin.verbose {
                    ProjectsPlugin.logger.info("\(Self.t)✅ 状态已清理")
                }
            }
        default:
            break
        }
    }

    @MainActor
    public static func titleToolbarItems(lumiCore: any LumiCoreAccessing) -> [LumiTitleToolbarItem] {
        if Self.verbose {
            if ProjectsPlugin.verbose {
                ProjectsPlugin.logger.info("\(Self.t)titleToolbarItems 被调用，viewModel 可用=\(Self.viewModel != nil)")
            }
        }

        guard let viewModel else { return [] }
        return [
            LumiTitleToolbarItem(
                id: "\(info.id).toolbar",
                title: "Projects",
                placement: .center
            ) {
                ProjectControlView(viewModel: viewModel)
            },
        ]
    }

    @MainActor
    public static func sendMiddlewares(lumiCore: any LumiCoreAccessing) -> [any LumiSendMiddleware] {
        [ConversationHintMiddleware()]
    }

    @MainActor
    public static func agentTools(lumiCore: any LumiCoreAccessing) throws -> [any LumiAgentTool] {
        if Self.verbose {
            ProjectsPlugin.logger.info("\(Self.t)agentTools 被调用，viewModel 可用=\(Self.viewModel != nil)")
        }

        // Tools access store dynamically via ProjectsPlugin.store inside MainActor.run
        guard Self.viewModel != nil else {
            throw LumiPluginDependencyError.stateNotInitialized("ProjectsViewModel")
        }

        let tools: [any LumiAgentTool] = [
            AddProjectTool(),
            ListProjectsTool(),
            GetCurrentProjectTool(),
        ]

        if Self.verbose {
            Self.logger.info("\(Self.t)✅ agentTools 返回 \(tools.count) 个工具：\(tools.map { $0.name }.joined(separator: ", "))")
        }

        return tools
    }
}
