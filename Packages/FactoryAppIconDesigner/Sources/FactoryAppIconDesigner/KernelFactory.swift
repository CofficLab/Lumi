import KernelCore
import PluginRootView
import ProviderChatSection
import ProviderConversation
import ProviderStorage
import SwiftUI
import os

/// AppIconDesigner 的内核工厂。
///
/// 负责创建容器、注册专用 Provider、启动专用插件，并把视图组装委托给
/// `ViewFactory`，使主窗口和设置窗口能够共享同一个内核实例。
@MainActor
public enum KernelFactory {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "kernel.factory.app-icon-designer"
    )
    nonisolated static let emoji = "📦"

    public static func makeKernel(
        additionalPlugins: [any SuperPlugin] = []
    ) throws -> KernelCoreContainer {
        try makeKernel(
            providerFactory: DefaultProviderFactory(),
            pluginFactory: DefaultPluginFactory(),
            additionalPlugins: additionalPlugins
        )
    }

    public static func makeKernel(
        providerFactory: any ProviderFactory,
        pluginFactory: any PluginFactory,
        additionalPlugins: [any SuperPlugin] = []
    ) throws -> KernelCoreContainer {
        let kernel = KernelCoreContainer()
        try providerFactory.registerProviders(into: kernel)
        let plugins = [RootViewPlugin(provider: providerFactory.makeRootViewProvider())]
            + pluginFactory.makePlugins()
            + additionalPlugins
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            // 迁移失败不阻断启动：单个插件的历史数据搬不动，最多退回默认配置。
            for plugin in plugins {
                do {
                    try PluginDataMigrationRunner(storage: storage).run(for: [plugin])
                } catch {
                    Self.logger.error(
                        "\(Self.emoji) | KernelFactory | 插件 \(plugin.id, privacy: .public) 数据迁移失败，已跳过并继续启动：\(error.localizedDescription, privacy: .public)"
                    )
                }
            }
        }
        try kernel.start(plugins: plugins)
        if let chat = kernel.resolveProvider((any ChatSectionProviding).self),
           let conversations = kernel.resolveProvider((any ConversationManaging).self) {
            chat.bindConversationSelection(conversations)
        }
        return kernel
    }

    public static func makeMainView() throws -> AnyView {
        try makeMainView(kernel: makeKernel())
    }

    public static func makeMainView(kernel: KernelCoreContainer) throws -> AnyView {
        try makeMainView(kernel: kernel, viewFactory: DefaultViewFactory())
    }

    public static func makeMainView(
        kernel: KernelCoreContainer,
        viewFactory: any ViewFactory
    ) throws -> AnyView {
        try viewFactory.makeMainView(kernel: kernel)
    }

    public static func makeSettingsView() throws -> AnyView {
        try makeSettingsView(kernel: makeKernel())
    }

    public static func makeSettingsView(kernel: KernelCoreContainer) throws -> AnyView {
        try makeSettingsView(kernel: kernel, viewFactory: DefaultViewFactory())
    }

    public static func makeSettingsView(
        kernel: KernelCoreContainer,
        viewFactory: any ViewFactory
    ) throws -> AnyView {
        try viewFactory.makeSettingsView(kernel: kernel)
    }
}
