import Foundation
import KernelCore
import KitTestIsolation
import ProviderStorage
import Testing
@testable import DisplayControlPlugin

/// 运行时目录守卫的测试。
///
/// `DisplayControlRuntime.settingsDirectory()` 在测试进程里未注入即拒绝
/// （`fatalError`，直接终止整个测试进程），因此这里既不能依赖生产回退目录，
/// 也不能让注入状态在用例之间互相污染。
///
/// 所有涉及注入状态的用例都标注 `@MainActor` 且不同步挂起：MainActor 是串行
/// 执行器，这些用例因此不会并发读写同一份进程级注入状态。
@Suite("Display control 运行时目录", .serialized)
@MainActor
struct DisplayControlRuntimeTests {

    @Test("注入目录后 settingsDirectory 返回该目录")
    func usesInjectedDirectory() {
        let directory = DisplayControlTestDoubles.makeTemporaryDirectory("runtime-injected")
        DisplayControlRuntime.configure(settingsDirectory: directory)
        defer { DisplayControlRuntime.reset() }

        #expect(DisplayControlRuntime.settingsDirectory() == directory)
    }

    @Test("重置后清空注入目录，不再回退到真实数据目录")
    func resetClearsInjectedDirectory() {
        let directory = DisplayControlTestDoubles.makeTemporaryDirectory("runtime-reset")
        DisplayControlRuntime.configure(settingsDirectory: directory)
        DisplayControlRuntime.reset()

        #expect(DisplayControlRuntime.injectedSettingsDirectory == nil)

        // 重置之后不得再回退到本机真实数据目录：测试进程里这条路径必须被拒绝。
        switch IsolatedDirectoryGuard.resolve(
            injected: DisplayControlRuntime.injectedSettingsDirectory,
            owner: "DisplayControlRuntime",
            accessor: "settingsDirectory()",
            fallback: { URL(fileURLWithPath: "/tmp/display-control-fallback", isDirectory: true) }
        ) {
        case .resolved:
            Issue.record("测试进程下未注入目录时不应回退到真实数据目录")
        case let .refused(reason):
            #expect(reason.contains("DisplayControlRuntime"))
            #expect(reason.contains("settingsDirectory()"))
        }
    }

    @Test("启动时把存储目录注入运行时配置")
    func bootInjectsStorageDirectory() throws {
        let root = DisplayControlTestDoubles.makeTemporaryDirectory("runtime-boot")
        let kernel = KernelCoreContainer()
        try kernel.registerProvider(
            (any StorageProviding).self,
            DisplayControlTestDoubles.StubStorageProvider(root: root)
        )

        try DisplayControlPlugin().onBoot(kernel: kernel)
        defer { DisplayControlRuntime.reset() }

        #expect(
            DisplayControlRuntime.settingsDirectory()
                == root.appendingPathComponent("com.coffic.lumi.plugin.display-control", isDirectory: true)
        )
    }
}
