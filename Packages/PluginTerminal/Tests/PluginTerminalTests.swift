import Testing
import KernelCore
import ProviderActivityBar
import ProviderChatSection
import ProviderRailView
import PluginRootView
import ProviderRootView
import SwiftUI
@testable import TerminalPlugin

@Test func packageLoads() async throws {
    #expect(Bool(true))
}

@MainActor
@Test func v2PluginRegistersStableTerminalEntry() throws {
    let kernel = KernelCoreContainer()
    let activityBar = DefaultActivityBarProviding()
    try kernel.registerProvider((any ActivityBarProviding).self, activityBar)

    let plugin = TerminalPlugin()
    try plugin.onBoot(kernel: kernel)

    #expect(plugin.id == "com.coffic.lumi.plugin.terminal")
    #expect(activityBar.items.map(\.id) == ["com.coffic.lumi.plugin.terminal.entry"])
}

@MainActor
@Test func activatingPluginHidesChatSectionAndDeactivatingRestoresIt() throws {
    let kernel = KernelCoreContainer()
    let activityBar = DefaultActivityBarProviding()
    let chat = DefaultChatSectionProviding()
    let railView = DefaultRailViewProviding()
    let rootView = PluginRootView.DefaultRootViewProvider()

    railView.addTabs([
        RailTabItem(id: "test.rail", category: .general, title: "Test", systemImage: "circle") {
            Text("Test")
        },
    ])
    rootView.setRailView(railView.makeRailView())
    rootView.setRailViewVisible(railView.hasVisibleTabs)

    try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
    try kernel.registerProvider((any ChatSectionProviding).self, chat)
    try kernel.registerProvider((any RailViewProviding).self, railView)
    try kernel.registerProvider((any RootViewProviding).self, rootView)

    let plugin = TerminalPlugin()
    try plugin.onBoot(kernel: kernel)

    #expect(activityBar.activeItemID == "\(plugin.id).entry")
    #expect(!chat.isVisible)
    #expect(!rootView.isRailViewVisible)
    #expect(rootView.isContentHeaderViewHidden)

    activityBar.activateItem(id: nil)

    #expect(chat.isVisible)
    #expect(rootView.isRailViewVisible)
    #expect(rootView.isContentHeaderViewHidden == false)
}

/// 回归 #498：终端项目路径的首尾空白是合法文件名字符。
/// 裁剪后会以错误目录启动会话；保留原字节才在用户指定的目录启动。
/// 空白-only / 空 / nil 仍须回退为 nil（保留原有空值语义）。
@MainActor
@Test func terminalPreservesLeadingTrailingWhitespaceInProjectPath() throws {
    let spaced = "/tmp/lumi-terminal-\(UUID().uuidString) "
    let view = TerminalMainView(projectPath: spaced)
    #expect(view.currentProjectPathForTerminal == spaced)

    #expect(TerminalMainView(projectPath: "   ").currentProjectPathForTerminal == nil)
    #expect(TerminalMainView(projectPath: "").currentProjectPathForTerminal == nil)
    #expect(TerminalMainView(projectPath: nil).currentProjectPathForTerminal == nil)
}
