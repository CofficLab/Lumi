import KernelCore
import ProviderChatSection
import ProviderConversation
import ProviderStorage

/// ACP headless 专用内核工厂。
///
/// 这是 FactoryLumiACP 自己的装配入口，不依赖 GUI 的 FactoryLumi。
@MainActor
public enum KernelFactory {
    public static func makeKernel(
        providerFactory: any ProviderFactory,
        pluginFactory: any PluginFactory,
        additionalPlugins: [any SuperPlugin] = []
    ) throws -> KernelCoreContainer {
        let kernel = KernelCoreContainer()
        try providerFactory.registerProviders(into: kernel)

        let plugins = pluginFactory.makePlugins() + additionalPlugins
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            try PluginDataMigrationCoordinator(storage: storage).run(for: plugins)
        }
        try kernel.start(plugins: plugins)

        if let chat = kernel.resolveProvider((any ChatSectionProviding).self),
           let conversations = kernel.resolveProvider((any ConversationManaging).self) {
            chat.bindConversationSelection(conversations)
        }
        return kernel
    }
}
