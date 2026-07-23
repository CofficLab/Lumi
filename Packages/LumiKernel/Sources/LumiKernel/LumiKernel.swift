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
        registerService(ToolManaging.self, pluginManager)
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
    ///
    /// 1. Call pluginManager.onBoot() to orchestrate plugin lifecycle
    /// 2. Check if all required services are registered
    /// - Throws: If required services are missing
    public func startup() async throws {
        // 1. 插件系统On Boot
        try await pluginManager.onBoot(kernel: self)

        // 2. 服务校验
        var missingServices: [String] = []

        if storage == nil { missingServices.append("Storage") }
        if project == nil { missingServices.append("Project") }
        if layout == nil { missingServices.append("Layout") }
        if viewContainer == nil { missingServices.append("ViewContainer") }
        if command == nil { missingServices.append("Command") }
        if menuBar == nil { missingServices.append("MenuBar") }
        if toolbarProvider == nil { missingServices.append("TitleToolbar") }
        if sendMiddleware == nil { missingServices.append("SendMiddleware") }
        if messageSend == nil { missingServices.append("MessageSend") }
        if llmProvider == nil { missingServices.append("LLMProvider") }
        if agentTurnRunner == nil { missingServices.append("AgentTurnRunner") }
        if chatSection == nil { missingServices.append("ChatSection") }
        if editor == nil { missingServices.append("Editor") }
        if toolManager == nil { missingServices.append("AgentTool") }
        if panel == nil { missingServices.append("Panel") }
        if statusBar == nil { missingServices.append("StatusBar") }
        if settings == nil { missingServices.append("Settings") }
        if logo == nil { missingServices.append("Logo") }
        if theme == nil { missingServices.append("Theme") }
        if messageRendererManager == nil { missingServices.append("MessageRendererManager") }
        if workspaceState == nil { missingServices.append("WorkspaceState") }

        if !missingServices.isEmpty {
            throw LumiKernelError.missingRequiredServices(missingServices)
        }
        
        // 3. 插件系统On Ready
        try await pluginManager.onReady(kernel: self)
    }
}

/// 兼容旧代码: 用 LumiKernel 实例化时,使用 LumiKernelContainer。
public typealias LumiKernel = LumiKernelContainer
