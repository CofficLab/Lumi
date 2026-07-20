import Combine
import Foundation
import LumiCoreAgentTool
import LumiCoreLayout
import LumiCoreProject
import LumiCoreStorage
import LumiCoreLLMProvider
import LumiCoreMessage
import SwiftUI

// MARK: - LumiCoreProviding

/// LumiCore 服务协议
///
/// 把"核心业务状态"（Storage / Project / Layout / Logo / AgentTool / ChatService / EditorService）
/// 暴露给 LumiKernel 使用。LumiCore 是 LumiCoreProviding 的标准实现。
///
/// - Important: 实现必须为 class（`AnyObject`）,因为协议内含可变状态。
///   所有访问必须在主线程（`@MainActor`）。
@MainActor
public protocol LumiCoreProviding: AnyObject, ObservableObject {
    // MARK: - State

    /// 存储功能组件
    var storage: StorageComponent { get }

    /// 项目功能组件
    var projectComponent: ProjectComponent { get }

    /// 布局功能组件
    var layoutComponent: LayoutComponent { get }

    /// Logo 功能组件
    var logoComponent: LogoComponent { get }

    /// Agent 工具功能组件
    var agentToolComponent: AgentToolComponent { get }

    /// 聊天服务
    var chatService: any ObservableObject { get }

    /// 编辑器服务
    var editorService: (any AbstractEditorServicing)? { get }

    // MARK: - Layout Convenience

    var showsPanelChrome: Bool { get }

    // MARK: - Service Registry

    /// 注册一个服务实例
    func registerService<T>(_ type: T.Type, _ instance: T)

    /// 从注册表解析已注册的服务实例
    func resolveService<T>(_ type: T.Type) -> T?
}

public extension LumiCoreProviding {
    /// 默认从布局组件读取 Panel Chrome 显示状态
    var showsPanelChrome: Bool {
        layoutComponent.state.showsPanelChrome
    }

    /// 兼容旧代码访问 `context.lumiCore`：对自身协议来说就是 self
    var lumiCore: (any LumiCoreProviding)? {
        self
    }

    /// 兼容旧代码的 `resolve(_:)`,转发到 `resolveService(_:)`
    func resolve<T>(_ type: T.Type = T.self) -> T? {
        resolveService(type)
    }
}

// MARK: - LumiCoreBootstrapping

/// LumiCore 启动期配置协议
///
/// 仅应在 App 启动时调用一次。
@MainActor
public protocol LumiCoreBootstrapping: AnyObject {
    typealias ChatServiceFactory = @MainActor (URL) throws -> any ObservableObject

    // MARK: - Service Registry

    func registerService<T>(_ type: T.Type, _ instance: T)
}

// MARK: - AbstractEditorServicing

/// 编辑器服务抽象接口
///
/// 由 LumiCore 持有具体的 EditorService 实例,通过此协议向上提供访问。
@MainActor
public protocol AbstractEditorServicing: AnyObject {
}

// MARK: - SwiftUI Environment

public extension EnvironmentValues {
    /// SwiftUI 环境值：注入 `LumiCoreProviding` 供视图树访问
    var lumiCore: LumiCoreProviding? {
        get { self[LumiCoreEnvironmentKey.self] }
        set { self[LumiCoreEnvironmentKey.self] = newValue }
    }
}

private struct LumiCoreEnvironmentKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: LumiCoreProviding? = nil
}

// MARK: - Plugin Context

/// 插件上下文
///
/// 在新版 LumiKernel 体系下,插件通过 `LumiPluginContext` 访问运行时信息。
/// - `lumiCore` 提供 LumiCore 服务入口(由调用方注入,弱化插件对具体实现的耦合);
/// - `dependencies` 携带 per-request 的依赖注入容器,包含 ChatService / ToolService 等
///   旧版插件注册路径上需要的服务;插件通过 `dependencies.resolve(_:)` 取出。
@MainActor
public struct LumiPluginContext {
    public let activeSectionID: String
    public let activeSectionTitle: String
    public let chatSection: LumiChatSectionLayout
    public let showsRail: Bool
    public let showsPanelChrome: Bool
    public let isChatSectionVisible: Bool
    public let dependencies: LumiPluginDependencies
    public let lumiCore: (any LumiCoreProviding)?

    /// 当前打开的项目（若存在）。等价于 `lumiCore?.projectComponent.currentProject`。
    public var currentProject: ProjectEntry? {
        lumiCore?.projectComponent.currentProject
    }

    /// 从 dependencies 取出已注册的服务
    public func resolve<T>(_ type: T.Type = T.self) -> T? {
        dependencies.resolve(type)
    }

    public init(
        activeSectionID: String = "main",
        activeSectionTitle: String = "Main",
        chatSection: LumiChatSectionLayout = .none,
        showsRail: Bool = false,
        showsPanelChrome: Bool = false,
        isChatSectionVisible: Bool? = nil,
        dependencies: LumiPluginDependencies = LumiPluginDependencies(),
        lumiCore: (any LumiCoreProviding)? = nil
    ) {
        self.activeSectionID = activeSectionID
        self.activeSectionTitle = activeSectionTitle
        self.chatSection = chatSection
        self.showsRail = showsRail
        self.showsPanelChrome = showsPanelChrome
        self.isChatSectionVisible = isChatSectionVisible ?? chatSection.isVisible
        self.dependencies = dependencies
        self.lumiCore = lumiCore
    }

    /// 拷贝并追加依赖,返回新 context
    public func withAdditionalDependencies(
        _ configure: (inout LumiPluginDependencies) -> Void
    ) -> LumiPluginContext {
        var dependencies = self.dependencies
        configure(&dependencies)
        return LumiPluginContext(
            activeSectionID: activeSectionID,
            activeSectionTitle: activeSectionTitle,
            chatSection: chatSection,
            showsRail: showsRail,
            showsPanelChrome: showsPanelChrome,
            isChatSectionVisible: isChatSectionVisible,
            dependencies: dependencies,
            lumiCore: lumiCore
        )
    }
}

// MARK: - Plugin Info

/// 插件元信息
@MainActor
public struct LumiPluginInfo: Sendable {
    public let id: String
    public let displayName: String
    public let description: String
    public let order: Int
    public let category: LumiPluginCategory
    public let policy: LumiPluginPolicy
    public let stage: LumiPluginStage
    public let iconName: String

    public init(
        id: String,
        displayName: String,
        description: String = "",
        order: Int = 100,
        category: LumiPluginCategory = .general,
        policy: LumiPluginPolicy = .optOut,
        stage: LumiPluginStage = .beta,
        iconName: String = "puzzlepiece.extension"
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.order = order
        self.category = category
        self.policy = policy
        self.stage = stage
        self.iconName = iconName
    }
}

/// 插件分类
public enum LumiPluginCategory: String, Sendable, Codable, CaseIterable {
    case core
    case theme
    case llmProvider
    case editor
    case conversation
    case tool
    case general
    case menu
    case status
}

/// 插件开发阶段
public enum LumiPluginStage: String, Sendable, Codable {
    case alpha
    case beta
    case stable
    case deprecated
}

// MARK: - Plugin Eligibility

/// 插件启用资格（用于运行期动态启用/禁用）
public struct LumiPluginEligibility: Sendable, Equatable {
    public let canEnable: Bool
    public let canDisable: Bool
    public let reason: String?

    public init(canEnable: Bool, canDisable: Bool, reason: String? = nil) {
        self.canEnable = canEnable
        self.canDisable = canDisable
        self.reason = reason
    }

    public static let enabled = LumiPluginEligibility(canEnable: true, canDisable: true)
    public static let alwaysOn = LumiPluginEligibility(canEnable: true, canDisable: false, reason: "Core plugin")
    public static let alwaysOff = LumiPluginEligibility(canEnable: false, canDisable: true, reason: "Disabled")
}

// MARK: - Workaround typealiases
//
// LumiCoreKit 中 LumiKernel.LumiCoreProviding 会被 Swift 解析为
// LumiKernelContainer class 的成员 (因为 LumiKernel 既是 module 也是 class),
// 导致 "is not a member type of class LumiKernel.LumiKernel"。
// 通过 _LumiCoreProviding 等下划线前缀别名,让 LumiCoreKit 用 module-level 引用。
public typealias _LumiCoreProviding = LumiCoreProviding
public typealias _AbstractEditorServicing = AbstractEditorServicing

// MARK: - 兼容 typealias

/// 旧版 `LumiCoreAccessing` 的兼容别名
///
/// 新版 LumiKernel 体系直接使用 `LumiCoreProviding`。保留 `LumiCoreAccessing` 是
/// 为了让历史 API 表面继续可用,无需重写所有调用方。
public typealias LumiCoreAccessing = LumiCoreProviding
