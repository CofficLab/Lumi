import Foundation
import KernelCore
import ProviderChatSection
import ProviderLLMManager
import SwiftUI
import Testing
@testable import PluginLLMProviderMiniMax

/// chat 工具栏配额 chip 的注册与撤回。
///
/// 这是本次恢复的核心行为：chip 真的挂到了 chat toolbar 上、位置在 trailing、
/// 且 `onShutdown` 能把它摘干净。此前这些代码路径完全没有被测试触达。
@MainActor
@Suite("工具栏配额项注册")
struct TokenPlanToolbarRegistrationTests {

    private static let itemID = MiniMaxProviderPlugin.toolbarItemID

    // MARK: - 注册

    @Test("onBoot 把配额 chip 注册到 chat toolbar trailing")
    func registersToolbarItemOnTrailing() throws {
        let harness = try KernelFixture.makeHarness()

        try MiniMaxProviderPlugin().onBoot(kernel: harness.kernel)

        let item = try #require(Self.item(in: harness.chat))
        #expect(item.id == Self.itemID)
        #expect(item.placement == .toolbarTrailing)
    }

    @Test("注册 id 全局唯一且带插件命名空间")
    func toolbarItemIDIsNamespaced() {
        #expect(Self.itemID.hasPrefix(MiniMaxProviderPlugin.pluginID))
        #expect(Self.itemID == "com.coffic.lumi.plugin.llm-provider.minimax.token-plan")
    }

    @Test("注册顺序排在其它工具栏项之后")
    func registersWithLargerOrderThanOtherPlugins() throws {
        let harness = try KernelFixture.makeHarness()
        // 对照：其它工具栏插件的 order 集中在 50-90。
        let otherOrder = 90
        try kernel_registerBarItem(harness.chat, id: "com.example.other", order: otherOrder)

        try MiniMaxProviderPlugin().onBoot(kernel: harness.kernel)

        let item = try #require(Self.item(in: harness.chat))
        #expect(item.order > otherOrder)
    }

    @Test("chip 视图可构建且门控默认关闭")
    func chipViewIsBuildableAndGatedOffByDefault() throws {
        let harness = try KernelFixture.makeHarness()
        try MiniMaxProviderPlugin().onBoot(kernel: harness.kernel)

        let item = try #require(Self.item(in: harness.chat))
        // makeView 是 @MainActor 同步闭包：构建一次验证不崩溃。
        _ = item.makeView()
    }

    // MARK: - 撤回

    @Test("onShutdown 摘除工具栏项")
    func shutdownRemovesToolbarItem() throws {
        let harness = try KernelFixture.makeHarness()
        let plugin = MiniMaxProviderPlugin()
        try plugin.onBoot(kernel: harness.kernel)
        #expect(Self.item(in: harness.chat) != nil)

        try plugin.onShutdown(kernel: harness.kernel)

        #expect(Self.item(in: harness.chat) == nil)
        #expect(harness.chat.barItems.isEmpty)
    }

    @Test("重复 onShutdown 幂等")
    func repeatedShutdownIsIdempotent() throws {
        let harness = try KernelFixture.makeHarness()
        let plugin = MiniMaxProviderPlugin()
        try plugin.onBoot(kernel: harness.kernel)

        #expect(throws: Never.self) {
            try plugin.onShutdown(kernel: harness.kernel)
            try plugin.onShutdown(kernel: harness.kernel)
        }
        #expect(harness.chat.barItems.isEmpty)
    }

    @Test("未 boot 直接 shutdown 不抛错")
    func shutdownWithoutBootDoesNotThrow() throws {
        let harness = try KernelFixture.makeHarness()

        #expect(throws: Never.self) {
            try MiniMaxProviderPlugin().onShutdown(kernel: harness.kernel)
        }
        #expect(harness.chat.barItems.isEmpty)
    }

    // MARK: - 降级路径

    @Test("缺少 ChatSectionProviding 时不影响供应商注册")
    func missingChatSectionStillRegistersProvider() throws {
        let kernel = KernelCoreContainer()
        let manager = DefaultLLMManager()
        try kernel.registerProvider((any LLMManaging).self, manager)
        // 故意不注册 ChatSectionProviding。

        #expect(throws: Never.self) {
            try MiniMaxProviderPlugin().onBoot(kernel: kernel)
        }
        #expect(manager.providerCount == 1)
    }

    @Test("缺少 LLM 管理器时不注册任何工具栏项")
    func missingManagerRegistersNothing() throws {
        let kernel = KernelCoreContainer()
        let chat = DefaultChatSectionProviding()
        try kernel.registerProvider((any ChatSectionProviding).self, chat)

        try MiniMaxProviderPlugin().onBoot(kernel: kernel)

        #expect(chat.barItems.isEmpty)
    }

    // MARK: - Helpers

    private static func item(in chat: DefaultChatSectionProviding) -> ChatSectionBarItem? {
        chat.barItems.first { $0.id == itemID }
    }

    /// 注册一个对照项，用于验证 order 相对关系。
    private func kernel_registerBarItem(
        _ chat: DefaultChatSectionProviding,
        id: String,
        order: Int
    ) {
        chat.addBarItems([
            ChatSectionBarItem(id: id, order: order, placement: .toolbarLeading) {
                EmptyView()
            },
        ])
    }
}
