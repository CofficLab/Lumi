import Foundation
import KernelCore
import ProviderChatSection
import ProviderCommand
import Testing
@testable import PluginChatScreenshot

// MARK: - 插件生命周期

@Suite("Chat Screenshot 插件生命周期")
@MainActor
struct ChatScreenshotPluginLifecycleTests {

    @Test("插件元数据保持稳定")
    func pluginMetadataIsStable() {
        let plugin = ChatScreenshotPlugin()

        #expect(plugin.id == "com.coffic.lumi.plugin.chat-screenshot")
        #expect(plugin.order == 81)
        #expect(plugin.metadata.name == "Chat Screenshot")
        #expect(plugin.metadata.category == .chat)
        #expect(plugin.metadata.policy == .required)
        #expect(plugin.name.isEmpty == false)
    }

    @Test("启动时注册聊天分区按钮与命令组")
    func bootRegistersBarItemAndCommandGroup() throws {
        let kernel = KernelCoreContainer()
        let chat = DefaultChatSectionProviding()
        let commands = DefaultCommandProviding()
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        try kernel.registerProvider((any CommandProviding).self, commands)

        let plugin = ChatScreenshotPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(chat.barItems.map(\.id) == ["\(plugin.id).button"])
        #expect(chat.barItems.first?.order == 81)
        #expect(chat.barItems.first?.placement == .actionLeading)

        #expect(commands.allCommandGroups.map(\.id) == ["\(plugin.id).commands"])
        #expect(commands.allCommandGroups.first?.items.map(\.id) == ["\(plugin.id).capture"])
    }

    @Test("缺少聊天分区 Provider 时启动不抛错")
    func bootWithoutChatSectionProviderIsNoop() throws {
        let kernel = KernelCoreContainer()
        let commands = DefaultCommandProviding()
        try kernel.registerProvider((any CommandProviding).self, commands)

        let plugin = ChatScreenshotPlugin()
        try plugin.onBoot(kernel: kernel)

        // 实现里 ChatSectionProviding 缺失时直接早退，
        // 因此按钮与命令组都不会登记（命令组登记在早退点之后）。
        #expect(commands.allCommandGroups.isEmpty)
    }

    @Test("缺少任何 Provider 时启动不抛错")
    func bootWithoutProvidersIsNoop() throws {
        let kernel = KernelCoreContainer()

        try ChatScreenshotPlugin().onBoot(kernel: kernel)
    }

    @Test("关闭时移除按钮与命令组")
    func shutdownRemovesContributions() throws {
        let kernel = KernelCoreContainer()
        let chat = DefaultChatSectionProviding()
        let commands = DefaultCommandProviding()
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        try kernel.registerProvider((any CommandProviding).self, commands)

        let plugin = ChatScreenshotPlugin()
        try plugin.onBoot(kernel: kernel)
        try plugin.onShutdown(kernel: kernel)

        #expect(chat.barItems.isEmpty)
        #expect(commands.allCommandGroups.isEmpty)
    }

    @Test("关闭时缺少 Provider 也不抛错")
    func shutdownWithoutProvidersIsNoop() throws {
        let kernel = KernelCoreContainer()

        try ChatScreenshotPlugin().onShutdown(kernel: kernel)
    }
}
