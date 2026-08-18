import KernelCore
import ProviderLogo
import SwiftUI
import Testing
@testable import PluginLogoSmartLight

@MainActor
@Suite("PluginLogoSmartLight")
struct PluginLogoSmartLightTests {

    @Test("onBoot 后 LogoProviding 已注册 Smart Light Logo 项")
    func onBootRegistersSmartLightLogo() throws {
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any LogoProviding).self, DefaultLogoProviding())

        let plugin = LogoSmartLightPlugin()
        try plugin.onBoot(kernel: kernel)

        let logo = kernel.resolveProvider((any LogoProviding).self)
        #expect(logo?.highestPriorityLogoItem?.id == "com.lumi.plugin.logo-smart-light")
        #expect(logo?.highestPriorityLogoItem?.order == 200)
    }

    @Test("未装配 LogoProviding 时 onBoot 不崩溃")
    func onBootWithoutLogoProviderIsNoOp() throws {
        let kernel = KernelCoreContainer()

        let plugin = LogoSmartLightPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(kernel.resolveProvider((any LogoProviding).self) == nil)
    }

    @Test("statusBar 场景渲染单色 Logo 视图")
    func statusBarSceneRendersMonochromeView() {
        let view = SmartLightLogoView(scene: .statusBar)
        #expect(type(of: view) == SmartLightLogoView.self)
    }

    @Test("general 场景渲染动画 Logo 视图")
    func generalSceneRendersAnimatedView() {
        let view = SmartLightLogoView(scene: .general)
        #expect(type(of: view) == SmartLightLogoView.self)
    }
}
