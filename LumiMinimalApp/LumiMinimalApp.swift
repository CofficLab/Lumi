import FactoryLumi2
import KernelCore
import ProviderActivityBar
import ProviderRailView
import ProviderRootView
import ProviderToolbar
import SwiftUI

/// 最小 App：验证「RootView 提供根布局 → KernelFactory 装配 → App 展示窗口」链路。
@main
struct LumiMinimalApp: App {
    /// 启动即装配内核（全部默认 Provider，含 RootView / Toolbar / ActivityBar / RailView）。
    private let kernel: KernelCoreContainer

    init() {
        // 装配默认 Provider 不应失败；失败即配置错误。
        kernel = try! KernelFactory.makeKernel()

        // 把工具栏、ActivityBar 与 Rail 的视图注入 RootView Provider，
        // 让根布局带顶部工具栏、左侧 ActivityBar 与侧边栏 Rail。
        if let rootView = kernel.resolveProvider((any RootViewProviding).self) {
            if let toolbar = kernel.resolveProvider((any ToolbarProviding).self) {
                rootView.setToolbarView(toolbar.makeToolbarView())
            }
            if let activityBar = kernel.resolveProvider((any ActivityBarProviding).self) {
                rootView.setActivityBarView(activityBar.makeActivityBarView())
            }
            if let rail = kernel.resolveProvider((any RailViewProviding).self) {
                rootView.setRailView(rail.makeRailView())
            }
        }
    }

    var body: some Scene {
        WindowGroup("LumiMinimal", id: "lumi-minimal.main") {
            if let rootView = kernel.resolveProvider((any RootViewProviding).self) {
                rootView.makeRootView()
            } else {
                Text("RootViewProviding not registered")
            }
        }
        .defaultSize(width: 480, height: 320)
    }
}
