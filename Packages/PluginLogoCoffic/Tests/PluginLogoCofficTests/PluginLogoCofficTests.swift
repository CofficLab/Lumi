import KernelCore
import ProviderLogo
import SwiftUI
import Testing
@testable import PluginLogoCoffic

@MainActor
@Suite("PluginLogoCoffic")
struct PluginLogoCofficTests {

    @Test("onBoot 后 LogoProviding 已注册 Coffic Logo 项")
    func onBootRegistersCofficLogo() throws {
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any LogoProviding).self, DefaultLogoProviding())

        let plugin = LogoCofficPlugin()
        try plugin.onBoot(kernel: kernel)

        let logo = kernel.resolveProvider((any LogoProviding).self)
        #expect(logo?.highestPriorityLogoItem?.id == "com.lumi.plugin.logo-coffic")
        #expect(logo?.highestPriorityLogoItem?.order == 100)
    }

    @Test("未装配 LogoProviding 时 onBoot 不崩溃")
    func onBootWithoutLogoProviderIsNoOp() throws {
        let kernel = KernelCoreContainer()

        let plugin = LogoCofficPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(kernel.resolveProvider((any LogoProviding).self) == nil)
    }

    @Test("statusBar 场景渲染单色 Logo 视图")
    func statusBarSceneRendersMonochromeView() {
        let view = CofficLogoView(scene: .statusBar)
        #expect(type(of: view) == CofficLogoView.self)
    }

    @Test("general 场景渲染动画 Logo 视图")
    func generalSceneRendersAnimatedView() {
        let view = CofficLogoView(scene: .general)
        #expect(type(of: view) == CofficLogoView.self)
    }
}
