import FactoryLumi2
import KernelCore
import ProviderWindow
import SwiftUI

/// 最小 App：验证「ProviderWindow 提供根视图 → KernelFactory 装配 → App 展示窗口」链路。
@main
struct LumiMinimalApp: App {
    /// 启动即装配内核（全部默认 Provider，含 WindowProviding）。
    private let kernel: KernelCoreContainer

    init() {
        // 装配默认 Provider 不应失败；失败即配置错误。
        kernel = try! KernelFactory.makeKernel()
    }

    var body: some Scene {
        WindowGroup("LumiMinimal", id: "lumi-minimal.main") {
            if let windowProvider = kernel.resolveProvider((any WindowProviding).self) {
                windowProvider.makeRootView()
            } else {
                Text("WindowProviding not registered")
            }
        }
        .defaultSize(width: 480, height: 320)
    }
}
