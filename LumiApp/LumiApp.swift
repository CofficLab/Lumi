import FactoryLumi
import LumiFactory
import SwiftUI

/// Lumi 的入口：只剩「清单 + 共享壳」。
///
/// 内核装配、窗口场景、状态栏、外部路径、设置深链、启动失败页全部由
/// `LumiFactory` 按 `LumiAssembly.makeManifest()` 解释；本类型必须保留
/// `@NSApplicationDelegateAdaptor`——SwiftUI 不会安装嵌套 App 结构体上的代理，
/// 那正是 Wakey 状态栏 / 设置窗回归的根因。
@main
struct LumiApp: App {
    @NSApplicationDelegateAdaptor(HostAppDelegate.self) private var appDelegate
    @StateObject private var bootstrapper: KernelBootstrapper

    init() {
        // 必须在窗口恢复之前禁用状态恢复，否则设置窗会在启动时自己冒出来。
        HostAppDelegate.prepareForLaunch()
        let bootstrapper = KernelBootstrapper(manifest: LumiAssembly.makeManifest())
        _bootstrapper = StateObject(wrappedValue: bootstrapper)
        appDelegate.bootstrapper = bootstrapper
    }

    var body: some Scene {
        HostMacScenes(bootstrapper: bootstrapper)
    }
}
