import Combine
import Foundation
import LumiUI
import SwiftUI

/// Lumi lightweight core
///
/// Architecture principle: Kernel 只持有各类能力（Provider），不进行能力转发。
/// 错误示例: kernel.getMessageList() — 这会让 Kernel 无限膨胀
/// 正确示例: kernel.messageManager.getMessageList() — 能力委托给具体 Provider
///
/// Only holds protocol types, does not depend on concrete implementations.
/// All concrete implementations are injected via plugins.
@MainActor
public final class LumiKernelContainer: ObservableObject {
    // MARK: - Service Registry

    /// Service registry
    private var services: [ObjectIdentifier: Any] = [:]

    /// Service change subscriptions
    private var serviceSubscriptions: [ObjectIdentifier: AnyCancellable] = [:]

    /// 内置插件管理器（直接持有，不使用服务注册表）
    public let pluginManager: BuiltinPluginManager

    // MARK: - Initialization

    public init() {
        // 初始化内置插件管理器（先创建，再设置 kernel 引用）
        self.pluginManager = BuiltinPluginManager()
        self.pluginManager.kernel = self
        // 注册其他服务
        registerService(UIThemeProviding.self, pluginManager)
    }

    // MARK: - Generic Service Registry

    /// Register service implementation
    public func registerService<T>(_ type: T.Type, _ instance: T) {
        services[ObjectIdentifier(type)] = instance

        // Forward objectWillChange from ObservableObject services
        subscribeToObjectWillChange(observable: instance, key: ObjectIdentifier(type))
    }

    /// Helper to subscribe to ObservableObject's objectWillChange
    private func subscribeToObjectWillChange<T>(observable: T, key: ObjectIdentifier) {
        guard let observableObject = observable as? any ObservableObject else { return }

        // Force cast to ObservableObjectPublisher which is the concrete type
        let publisher = observableObject.objectWillChange as! ObservableObjectPublisher
        serviceSubscriptions[key] = publisher
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.objectWillChange.send()
            }
    }

    /// Resolve service implementation
    public func resolveService<T>(_ type: T.Type = T.self) -> T? {
        services[ObjectIdentifier(type)] as? T
    }

    /// Unregister service
    public func unregisterService<T>(_ type: T.Type) {
        let key = ObjectIdentifier(type)
        services.removeValue(forKey: key)
        serviceSubscriptions.removeValue(forKey: key)
    }

    // MARK: - Startup & Validation

    /// Startup kernel and perform self-check
    public func startup() async throws {
        // 1. 插件系统 On Boot — 阶段 1:注册内核服务与 UI 贡献
        try await pluginManager.onBoot(kernel: self)

        // 2. 服务校验 — 必需的内核服务必须在 OnBoot 阶段注册完毕
        guard storage != nil,
              project != nil,
              layoutManager != nil,
              command != nil,
              sharedUI != nil,
              messageSender != nil,
              llmProvider != nil,
              agentTurnRunner != nil,
              editorProvider != nil,
              toolManager != nil,
              settings != nil,
              logo != nil,
              theme != nil,
              messageRendererManager != nil else {
            let missingServices = [
                storage == nil ? "Storage" : nil,
                project == nil ? "Project" : nil,
                layoutManager == nil ? "Layout" : nil,
                command == nil ? "Command" : nil,
                sharedUI == nil ? "SharedUI" : nil,
                messageSender == nil ? "MessageSend" : nil,
                llmProvider == nil ? "LLMProvider" : nil,
                agentTurnRunner == nil ? "AgentTurnRunner" : nil,
                editorProvider == nil ? "Editor" : nil,
                toolManager == nil ? "AgentTool" : nil,
                settings == nil ? "Settings" : nil,
                logo == nil ? "Logo" : nil,
                theme == nil ? "Theme" : nil,
                messageRendererManager == nil ? "MessageRendererManager" : nil,
            ].compactMap { $0 }
            throw LumiKernelError.missingRequiredServices(missingServices)
        }

        // 3. 插件系统 On Ready — 阶段 2:依赖服务的异步初始化
        try await pluginManager.onReady(kernel: self)

        // 4. 收集所有插件贡献的 LLM Provider,并注册到内核 LLMProviderManaging
        //    — 在 onReady 之后执行,确保 `kernel.llmProvider` 服务可用,
        //    且各插件的 `llmProviders(kernel:)` 可以在完整内核上运行。
        try pluginManager.registerLLMProviders(in: self)

        // 5. 收集所有插件贡献的 Agent 工具,并注册到内核 ToolManaging
        //    — 在 onReady 之后执行,确保 `kernel.toolManager` 服务可用,
        //    且各插件的 `agentTools(kernel:)` 可以在完整内核上运行。
        try pluginManager.registerAgentTools(in: self)

        // 6. 同步当前激活容器的可见性状态
        //    — 从 LayoutProviding 获取 activeViewContainerID,
        //    — 再从 LayoutProviding 获取该容器的 rail/chat/content/panel 可见性,
        //    — 最后更新到 LayoutProviding 的状态中。
        if let containerID = layoutManager?.layoutState.activeViewContainerID,
           let container = layoutManager?.viewContainer(id: containerID) {
            layoutManager?.applyVisibility(
                rail: container.isRailVisible,
                chat: container.isChatVisible,
                content: container.isContentVisible,
                panel: container.isPanelVisible
            )
        }
    }
}

/// 兼容旧代码: 用 LumiKernel 实例化时,使用 LumiKernelContainer。
public typealias LumiKernel = LumiKernelContainer
