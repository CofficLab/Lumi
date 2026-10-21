import Foundation
import KernelCore
import NetworkExtension
import ProviderContentView
import ProviderDocsView
import ProviderRootView
import Testing
@testable import NettoPlugin

// MARK: - 插件生命周期

@Suite("Netto 插件生命周期")
@MainActor
struct NettoPluginLifecycleTests {

    @Test("注册时写入关于与说明书文档条目")
    func registerAddsDocsEntries() throws {
        let kernel = KernelCoreContainer()
        let docs = DefaultDocsViewProviding()
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = NettoPlugin()
        try plugin.onRegister(kernel: kernel)

        #expect(docs.aboutEntries.map(\.id) == [plugin.id])
        #expect(docs.manualEntries.map(\.id) == [plugin.id])
        #expect(docs.aboutEntries.first?.name == "Netto Firewall")
    }

    @Test("缺少文档 Provider 时注册不抛错")
    func registerWithoutDocsProviderIsNoop() throws {
        let kernel = KernelCoreContainer()

        try NettoPlugin().onRegister(kernel: kernel)
    }

    @Test("启动后隐藏内容头部并设置内容视图")
    func bootHidesHeaderAndSetsContent() throws {
        let kernel = KernelCoreContainer()
        let content = DefaultContentViewProviding()
        let rootView = DefaultRootViewProviding()
        try kernel.registerProvider((any ContentViewProviding).self, content)
        try kernel.registerProvider((any RootViewProviding).self, rootView)

        let plugin = NettoPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(rootView.isContentHeaderViewHidden)
    }

    @Test("缺少根视图 Provider 时启动不抛错")
    func bootWithoutRootViewProviderIsNoop() throws {
        let kernel = KernelCoreContainer()

        try NettoPlugin().onBoot(kernel: kernel)
    }

    @Test("关闭时恢复内容头部并清空内容视图")
    func shutdownRestoresChrome() throws {
        let kernel = KernelCoreContainer()
        let content = DefaultContentViewProviding()
        let rootView = DefaultRootViewProviding()
        try kernel.registerProvider((any ContentViewProviding).self, content)
        try kernel.registerProvider((any RootViewProviding).self, rootView)

        let plugin = NettoPlugin()
        try plugin.onBoot(kernel: kernel)
        try plugin.onShutdown(kernel: kernel)

        #expect(rootView.isContentHeaderViewHidden == false)
    }

    @Test("注销时移除文档条目")
    func unregisterRemovesDocsEntries() throws {
        let kernel = KernelCoreContainer()
        let docs = DefaultDocsViewProviding()
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = NettoPlugin()
        try plugin.onRegister(kernel: kernel)
        try plugin.onUnregister(kernel: kernel)

        #expect(docs.aboutEntries.isEmpty)
        #expect(docs.manualEntries.isEmpty)
    }

    @Test("插件元数据保持稳定")
    func pluginMetadataIsStable() {
        let plugin = NettoPlugin()

        #expect(plugin.id == "com.coffic.lumi.plugin.netto")
        #expect(plugin.order == 99)
        #expect(plugin.metadata.name == "Netto Firewall Plugin")
        #expect(plugin.metadata.policy == .disabled)
    }
}

// MARK: - 连接提示文案

@Suite("Netto 连接提示")
struct NettoConnectionPromptTests {

    @Test("提示文案包含应用标识与访问目标")
    func messageContainsAppAndEndpoint() {
        let message = FirewallService.connectionPromptMessage(
            appId: "com.example.app",
            hostname: "example.com",
            port: "443",
            direction: .outbound
        )

        #expect(message.contains("com.example.app"))
        #expect(message.contains("example.com:443"))
    }

    @Test("端口为空时只展示主机名")
    func omitsEmptyPort() {
        let message = FirewallService.connectionPromptMessage(
            appId: "com.example.app",
            hostname: "example.com",
            port: "",
            direction: .outbound
        )

        #expect(message.contains("example.com"))
        #expect(message.contains("example.com:") == false)
    }

    @Test("不同方向给出不同提示")
    func directionsDiffer() {
        let outbound = FirewallService.connectionPromptMessage(
            appId: "com.example.app",
            hostname: "example.com",
            port: "443",
            direction: .outbound
        )
        let inbound = FirewallService.connectionPromptMessage(
            appId: "com.example.app",
            hostname: "example.com",
            port: "443",
            direction: .inbound
        )
        let any = FirewallService.connectionPromptMessage(
            appId: "com.example.app",
            hostname: "example.com",
            port: "443",
            direction: .any
        )

        #expect(outbound != inbound)
        #expect(outbound != any)
        #expect(inbound != any)
    }
}

// MARK: - IPC

@Suite("Netto IPC")
struct NettoIPCTests {

    @Test("Provider 侧的注册回调直接返回成功")
    func providerRegisterSucceeds() {
        let connection = IPCConnection()

        var result: Bool?
        connection.register { result = $0 }

        #expect(result == true)
    }

    @Test("缺少 Mach 服务名时不会创建监听器")
    func startListenerWithoutMachServiceName() {
        let connection = IPCConnection()

        connection.startListener()

        #expect(connection.listener == nil)
    }

    @Test("初始状态没有活动连接")
    func hasNoCurrentConnection() {
        let connection = IPCConnection()

        #expect(connection.currentConnection == nil)
    }

    @Test("扩展日志与审批请求不会抛错")
    func extensionHooksAreSafe() {
        let service = FirewallService()

        service.needApproval()
        service.extensionLog("hello")
    }
}
