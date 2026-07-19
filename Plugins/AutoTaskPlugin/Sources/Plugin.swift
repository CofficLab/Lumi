import LumiKernel
import LumiUI
import os
import SuperLogKit
import SwiftUI

/// AutoTask 插件：任务拆解、进度跟踪与 Agent 自动推进。
public enum AutoTaskPlugin: LumiPlugin, SuperLog {

    nonisolated public static let emoji = "📋"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.auto-task",
        displayName: LumiPluginLocalization.string("Auto Task (Deprecated)", bundle: .module),
        description: LumiPluginLocalization.string("Deprecated: Use GoalTaskPlugin instead. Break down complex goals into trackable tasks and drive Agent auto-progress.", bundle: .module),
        order: 90,
        category: .agent,
        policy: .disabled,
        stage: .deprecated,
        iconName: "checklist",
    )

    /// 插件数据存储的子目录名称
    public static let dataDirectoryName = "AutoTask"

    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.auto-task")
    nonisolated(unsafe) public static var configuration: any Configuration = DefaultConfiguration()

    // MARK: - Lifecycle Managed Instances

    /// 由插件生命周期管理的状态管理器实例。
    ///
    /// - `lifecycle(.didRegister)` 时创建并注入数据库目录
    /// - `lifecycle(.willDisable)` 时置空释放
    ///
    /// 调用方应通过此属性访问（而非构造新的 manager），保证单实例。
    @MainActor
    public static var manager: TaskStateManager?

    @MainActor
    public static func lifecycle(_ event: LumiPluginLifecycle, lumiCore: any LumiCoreAccessing) throws {
        switch event {
        case .didRegister:
            // 优先使用 LumiCore 提供的目录；缺失时降级到 tmp。
            let directory = lumiCore.storage.pluginDataDirectory(for: dataDirectoryName)
            Self.manager = try TaskStateManager(databaseRootURL: directory)

        case .appDidLaunch:
            // 已注册则无需重复初始化；未注册时（如单元测试或外部手动初始化）
            // 不在此处兜底，避免出现隐式全局状态。
            break

        case .willDisable:
            Self.manager = nil

        default:
            break
        }
    }

    @MainActor
    public static func sendMiddlewares(lumiCore: any LumiCoreAccessing) -> [any LumiSendMiddleware] {
        guard let manager else {
            Self.logger.warning("\(Self.t)manager 未初始化，返回空中间件列表")
            return []
        }
        return [TaskContextChatMiddleware(manager: manager)]
    }

    @MainActor
    public static func onTurnFinished(
        lumiCore: any LumiCoreAccessing,
        conversationID: UUID,
        reason: LumiTurnEndReason
    ) async {
        await TurnFinishedHook.handle(lumiCore: lumiCore, conversationID: conversationID, reason: reason)
    }

    @MainActor
    public static func agentTools(lumiCore: any LumiCoreAccessing) throws -> [any LumiAgentTool] {
        guard let manager else {
            throw LumiPluginDependencyError.stateNotInitialized("TaskStateManager")
        }
        return [
            CreateTaskTool(manager: manager),
            AppendTaskTool(manager: manager),
            UpdateTaskTool(manager: manager),
            ListTasksTool(manager: manager),
            CheckProgressTool(manager: manager),
        ]
    }

    @MainActor
    public static func chatSectionItems(lumiCore: any LumiCoreAccessing) -> [LumiChatSectionItem] {
        guard lumiCore.layoutComponent.state.chatSectionVisible,
              let coordinator = lumiCore.resolveService((any ChatSectionCoordinator).self)
        else {
            return []
        }

        return [
            LumiChatSectionItem(id: info.id, order: info.order) {
                ChatSectionView(coordinator: coordinator)
            }
        ]
    }

    // MARK: - Bootstrap

    @MainActor
    static func bootstrapFromLumiCoreIfNeeded(lumiCore: any LumiCoreAccessing) {
        guard !didBootstrapFromLumiCore else { return }

        configuration = LumiCoreConfiguration(
            rootURL: lumiCore.storage.pluginDataDirectory(for: dataDirectoryName)
        )
        didBootstrapFromLumiCore = true
    }
}

// MARK: - Private

private nonisolated(unsafe) var didBootstrapFromLumiCore = false

/// 配置协议：解耦插件与 App 侧存储路径。
public protocol Configuration: Sendable {
    /// 插件数据库目录 URL
    func databaseDirectory() -> URL
}

private struct LumiCoreConfiguration: Configuration {
    let rootURL: URL

    func databaseDirectory() -> URL {
        rootURL
    }
}

private struct DefaultConfiguration: Configuration {
    func databaseDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
        return appSupport.appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("db", isDirectory: true)
    }
}

private struct ChatSectionView: View {
    @LumiTheme private var theme
    @ObservedObject var coordinator: ChatSectionCoordinator

    var body: some View {
        SidebarView(
            conversationIdProvider: { coordinator.selectedConversationID },
            backgroundColorProvider: {
                theme.background.opacity(0.94)
            }
        )
    }
}
