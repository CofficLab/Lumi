import Combine
import SwiftUI

// MARK: - 消息渲染器 ViewModel

/// 消息渲染器 ViewModel
///
/// 全局单例，管理所有注册的消息渲染器。
/// 插件可以在 `onRegister()` 中注册自定义渲染器。
///
/// ## 架构说明
///
/// MessageRendererVM 是核心 ViewModel，通过 RootView 注入环境变量。
/// 所有插件视图通过 `@EnvironmentObject` 访问此 VM，而不是直接使用单例。
///
/// ## 使用示例
///
/// ```swift
/// // 在插件中注册渲染器
/// actor MyPlugin: SuperPlugin {
///     nonisolated func onRegister() {
///         Task { @MainActor in
///             // 通过环境变量访问（推荐）
///             messageRendererVM.register(LoadingModelRenderer())
///             
///             // 或使用单例（仅用于插件初始化阶段）
///             MessageRendererVM.shared.register(LoadingModelRenderer())
///         }
///     }
/// }
///
/// // 在视图中使用
/// struct MyView: View {
///     @EnvironmentObject var messageRendererVM: MessageRendererVM
///     
///     var body: some View {
///         if let renderer = messageRendererVM.findRenderer(for: message) {
///             renderer.render(message: message, showRawMessage: $showRawMessage)
///         }
///     }
/// }
/// ```
@MainActor
final class MessageRendererVM: ObservableObject {
    /// 全局单例
    ///
    /// 整个应用共享同一个 MessageRendererVM 实例。
    /// 在插件初始化阶段可以使用此单例注册渲染器。
    static let shared = MessageRendererVM()
    
    /// 已注册的渲染器列表
    ///
    /// 包含所有已注册的渲染器，按优先级降序排序。
    @Published private(set) var renderers: [any SuperMessageRenderer] = []
    
    /// 初始化
    ///
    /// 私有初始化，确保只通过 `shared` 单例访问。
    /// 内置渲染器由 CoreMessageRendererPlugin 注册。
    private init() {
        // 内置渲染器由 CoreMessageRendererPlugin 注册
        // 这里不自动注册，避免职责分散
    }
    
    // MARK: - 注册管理
    
    /// 注册渲染器
    ///
    /// - Parameter renderer: 要注册的渲染器
    ///
    /// 如果已存在相同 ID 的渲染器，会替换原有渲染器。
    /// 注册后会自动按优先级重新排序。
    func register(_ renderer: some SuperMessageRenderer) {
        // 检查是否已存在相同 ID 的渲染器
        if let index = renderers.firstIndex(where: { type(of: $0).id == type(of: renderer).id }) {
            renderers[index] = renderer
        } else {
            renderers.append(renderer)
        }
        
        // 按优先级降序排序
        renderers.sort { type(of: $0).priority > type(of: $1).priority }
    }
    
    /// 批量注册渲染器
    ///
    /// - Parameter renderers: 要注册的渲染器数组
    func register(_ renderers: [any SuperMessageRenderer]) {
        renderers.forEach { register($0) }
    }
    
    /// 注销渲染器
    ///
    /// - Parameter id: 要注销的渲染器 ID
    func unregister(id: String) {
        renderers.removeAll { type(of: $0).id == id }
    }
    
    /// 清空所有渲染器
    func clear() {
        renderers.removeAll()
    }
    
    // MARK: - 查找渲染器
    
    /// 查找匹配的渲染器
    ///
    /// 按优先级顺序查找，返回第一个匹配的渲染器。
    ///
    /// - Parameter message: 要渲染的消息
    /// - Returns: 匹配的渲染器，如果没有则返回 nil
    func findRenderer(for message: ChatMessage) -> (any SuperMessageRenderer)? {
        renderers.first { $0.canRender(message: message) }
    }
}