import FactoryLumi2
import KernelCore
import ProviderRootView
import ProviderToolbar
import SwiftUI

/// 最小 App：验证「RootView 提供根布局 → KernelFactory 装配 → App 展示窗口」链路。
@main
struct LumiMinimalApp: App {
    /// 启动即装配内核（全部默认 Provider，含 RootViewProviding 与 ToolbarProviding）。
    private let kernel: KernelCoreContainer

    init() {
        // 装配默认 Provider 不应失败；失败即配置错误。
        kernel = try! KernelFactory.makeKernel()

        // 把工具栏 Provider 的视图注入 RootView Provider，让根布局带工具栏。
        if let toolbar = kernel.resolveProvider((any ToolbarProviding).self),
           let rootView = kernel.resolveProvider((any RootViewProviding).self) {
            rootView.setToolbarView(toolbar.makeToolbarView())
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
