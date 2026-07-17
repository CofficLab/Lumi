import LumiAppKit
import LumiChatKit
import LumiCoreKit
import LumiUI
import SuperLogKit
import SwiftUI
import os

/// App 的组合根（Composition Root）。
///
/// 职责严格限定为：
/// 1. 按依赖顺序 **实例化** 各服务（`new`）；
/// 2. 把 RootContainer 自己 new 的服务 **注册** 进 LumiCore 服务表。
///
/// 不再包含任何业务算法、启动期接线或运行期事件 fan-out——这些已全部下沉：
/// - LumiCore 的启动 / 工厂 / `configure` / Chat 维度贡献应用 → `LumiCoreService`
/// - 工具执行钩子 / 布局早期恢复 → `PluginService`
/// - 主题同步接线 → `LumiUIService`
/// - 编辑器扩展重装 / 外观同步 → `EditorCoreService`
/// - 菜单栏刷新 → `MenuBarService`
/// - 运行期插件 enable/disable 的广播 → 各服务通过 `NotificationCenter` 自治订阅
@MainActor
final class RootContainer: ObservableObject, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "bootstrap.root-container")
    nonisolated static let emoji = "🗂️"
    nonisolated static let verbose = false

    let lumiCore: LumiCore
    let lumiCoreService: LumiCoreService
    let pluginService: PluginService
    let editorCoreService: EditorCoreService
    let chatSectionCoordinator: ChatSectionCoordinator
    let lumiUIService: LumiUIService
    let menuBarService: MenuBarService

    init() throws {
        // —— 实例化（按依赖顺序）——
        let pluginService = PluginService()
        self.pluginService = pluginService

        // LumiCoreService 内部完成：dataRoot 物化 / ChatService 工厂 / EditorCoreService
        // 创建 / configure 回填 / Chat 维度贡献应用 / 工具贡献编排 / 自注册 / 插件状态订阅。
        let lumiCoreService = try LumiCoreService(provider: pluginService)
        self.lumiCoreService = lumiCoreService
        self.lumiCore = lumiCoreService.lumiCore
        self.editorCoreService = lumiCoreService.editorCoreService

        self.chatSectionCoordinator = ChatSectionCoordinator(
            chatService: lumiCoreService.chatService,
            databaseDirectory: lumiCoreService.coreDatabaseDirectory
        )

        self.lumiUIService = LumiUIService(
            pluginService: pluginService,
            lumiCore: lumiCore,
            editorCoreService: lumiCoreService.editorCoreService
        )
        self.menuBarService = MenuBarService(pluginService: pluginService, lumiCore: lumiCore)

        // —— 注册（仅 RootContainer 自己 new 的对象）——
        // LumiCoreService / ChatService / EditorCoreService 已在 LumiCoreService.init
        // 内自注册；PluginService 的 LumiLLMProviderSettingsContributing 也在那里注册。
        lumiCore.registerService(ChatSectionCoordinator.self, chatSectionCoordinator)
        lumiCore.registerService(LumiThemeServicing.self, lumiUIService)

        if Self.verbose {
            Self.logger.info("\(Self.t)🎉 RootContainer 初始化完成")
        }
    }
}
