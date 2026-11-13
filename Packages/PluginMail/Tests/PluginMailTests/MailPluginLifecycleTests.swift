import Foundation
import KernelCore
import KitTestSupport
import Testing
@testable import PluginMail

/// 回归 #137：内核启动失败回滚（KernelCore.rollbackStartup）会对「注册过但从未
/// boot」的插件调用 `onShutdown`。
///
/// 旧实现里 `onShutdown` 直接触碰 lazy `sessionManager`，连带初始化 `accountStore`
/// 并解析 `dataDirectory`；此时 `storageProvider` 仍为 nil，于是走兜底目录——测试进程
/// 里被 `IsolatedDirectoryGuard` 直接 fatalError（signal 5），整个 FactoryLumi 测试
/// 进程被杀掉；生产上则会把数据写到版本化根目录之外。修复用 `didBoot` 守卫区分两种
/// 情况：没 boot 过直接返回，绝不触碰任何 lazy 属性（见 commit 354c76817）。
///
/// 本用例在单元层锁定该守卫：注入一个**尚不存在**的兜底目录，未 boot 即 shutdown 后，
/// 该目录绝不能被创建——因为 `MailAccountStore.init` 会 eagerly `createDirectory`，
/// 目录出现即证明 lazy 服务被错误初始化。注入目录使守卫可解析，从而把「进程崩溃」
/// 转化为确定性的文件存在断言（不依赖 fire-and-forget Task 的崩溃时机）。
@Suite("MailPlugin 生命周期", .serialized)
@MainActor
struct MailPluginLifecycleTests {

    @Test("未 boot 即 onShutdown 不初始化 lazy 服务（不创建数据目录）")
    func shutdownWithoutBootDoesNotInitializeLazyServices() async throws {
        let root = try TemporaryDirectory.make("mail-shutdown-no-boot")
        defer { root.remove() }
        // 兜底目录指向一个尚不存在的子目录：accountStore 一旦初始化就会创建它。
        let dataDirectory = root.url.appendingPathComponent("plugin-data", isDirectory: true)
        MailPluginRuntime.injectedFallbackDataDirectory = dataDirectory
        defer { MailPluginRuntime.injectedFallbackDataDirectory = nil }

        let kernel = KernelCoreContainer()
        let plugin = MailPlugin()

        // 未 boot 直接 shutdown：didBoot 守卫必须直接返回，不调度任何触碰 lazy 服务的 Task。
        try plugin.onShutdown(kernel: kernel)

        // 给 fire-and-forget Task 运行的机会：守卫缺失时它会初始化 sessionManager →
        // accountStore，进而 createDirectory(dataDirectory)。
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(!FileManager.default.fileExists(atPath: dataDirectory.path))
    }
}