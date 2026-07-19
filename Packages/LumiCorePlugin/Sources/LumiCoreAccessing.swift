import Combine
import LumiCoreAgentTool
import LumiCoreLayout
import LumiCoreProject
import LumiCoreStorage
import SwiftUI

// MARK: - LumiCoreAccessing

/// 视图与插件访问 LumiCore 核心状态的协议。
///
/// 该协议暴露**只读**且**频繁使用**的 API，供 SwiftUI 视图（App + 插件）通过
/// `@Environment(\.lumiCore)` 安全获取。它刻意不暴露任何修改内部状态的能力，
/// 以保证视图层无法污染内核状态。
///
/// 运行期的注册与编排（`registerService` 等）请使用
/// `LumiCoreBootstrapping` 协议。
///
/// - Important: 实现必须为 class（`AnyObject`），因为协议内含可变状态；
///
/// 自 LumiCore 迁移到 `final class` 后,`LumiCoreAccessing` 继承 `ObservableObject`,
/// 允许 SwiftUI 视图通过 `@EnvironmentObject` 完整观察内核状态变化。
///   所有访问必须在主线程（`@MainActor`）。
@MainActor
public protocol LumiCoreAccessing: LumiCoreProviding, ObservableObject {
    // MARK: - State

    /// Logo 功能组件。收集插件贡献的 Logo 项并选出最高优先级者。
    var logoComponent: LogoComponent { get }

    /// 布局功能组件。封装 `LumiLayoutState`,转发 objectWillChange。
    /// 注意:本组件不收敛 state 字段——外部可直接读写 `component.state.xxx`
    /// (SwiftUI Binding 惯法天然要求外部能写)。
    var layoutComponent: LayoutComponent { get }

    /// Agent 工具功能组件。per-request 动态注入改造后，暴露 `buildToolSet` 供
    /// `SendPipeline` 在每次发消息时构建本次请求的工具集（按当前 context 收集
    /// 插件工具、内置工具、子 Agent 工具，软去重后返回 per-request `ToolService`）。
    var agentToolComponent: AgentToolComponent { get }

    /// 聊天服务（init 时由 `ChatServiceFactory` 创建并自动注册）。
    /// 实际类型为 `LumiChatServicing`，使用 `any ObservableObject` 避免循环依赖。
    var chatService: any ObservableObject { get }

    /// 编辑器服务（`init(editorFactory:)` 传入工厂时创建；不传则为 nil）。
    var editorService: (any AbstractEditorServicing)? { get }

    // MARK: - Service Registry

    /// 注册一个服务实例，供启动期配置使用。
    func registerService<T>(_ type: T.Type, _ instance: T)

    /// 从注册表解析已注册的服务实例。
    func resolveService<T>(_ type: T.Type) -> T?
}

// MARK: - LumiCoreBootstrapping

/// LumiCore 启动期配置协议。
///
/// 该协议暴露**仅应在 App 启动时调用一次**的 API（注册服务、启动工具服务、boot 等）。
/// 把它从 `LumiCoreAccessing` 独立出来的原因：
///
/// 1. **协议隔离**：视图层不需要也不应该接触这些能力，避免被误调用。
/// 2. **测试友好**：单测时 mock `LumiCoreAccessing` 不需要实现启动期逻辑。
/// 3. **编译期保护**：插件如果不小心调用了 boot 类 API，编译器会直接报错。
///
/// - Important: 仅 `LumiCore` 主类（及其子类）在 App 启动期实现并使用该协议。
@MainActor
public protocol LumiCoreBootstrapping: AnyObject {
    /// ChatService 工厂闭包类型。init 时传入,接收 core 数据库目录。
    /// 工厂创建的 ChatService 的 lumiCore 引用应留空(nil),由调用方在
    /// LumiCore 创建后调 `chatService.configure(lumiCore:)` 回填。
    typealias ChatServiceFactory = @MainActor (URL) throws -> any ObservableObject

    // MARK: - Service Registry

    /// 注册一个服务实例，供运行时解析依赖。
    func registerService<T>(_ type: T.Type, _ instance: T)
}

// MARK: - SwiftUI Environment

/// SwiftUI 环境值：注入 `LumiCoreAccessing` 供视图树访问。
///
/// 默认值为 `nil`，因此未注入时插件视图会得到 `nil` 而非崩溃——可由调用方决定如何
/// 优雅降级（显示占位、跳过功能、抛错等）。这避免了「必须保证环境注入」的硬约束，
/// 让插件在 SwiftUI Preview 等场景下也能安全运行。
public extension EnvironmentValues {
    var lumiCore: LumiCoreAccessing? {
        get { self[LumiCoreEnvironmentKey.self] }
        set { self[LumiCoreEnvironmentKey.self] = newValue }
    }
}

private struct LumiCoreEnvironmentKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: LumiCoreAccessing? = nil
}