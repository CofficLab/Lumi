import Foundation
import KitTestIsolation
import KitTestSupport
import Testing
@testable import PluginMail

// MARK: - 兜底目录守卫

/// `MailPluginRuntime` 兜底目录的守卫用例。
///
/// 两条用例共享 `MailPluginRuntime.injectedFallbackDataDirectory` 这份全局状态，
/// 因此整组串行执行，避免并行时互相覆盖注入值。
@Suite("MailPluginRuntime 兜底目录", .serialized)
struct MailPluginRuntimeTests {

    /// 注入临时目录后，兜底目录必须解析到该目录。
    ///
    /// 这条路径正是 `StorageProviding` 未注册时 `MailPlugin` 走的那条：
    /// 没有注入，测试进程里就会被守卫拒绝并杀掉整个进程。
    @Test("注入目录后 fallbackDataDirectory 返回该目录")
    func usesInjectedDirectory() throws {
        let directory = try TemporaryDirectory.make("mail-runtime-injected")
        defer { directory.remove() }

        MailPluginRuntime.injectedFallbackDataDirectory = directory.url
        defer { MailPluginRuntime.injectedFallbackDataDirectory = nil }

        #expect(MailPluginRuntime.fallbackDataDirectory() == directory.url)
    }

    /// 未注入目录时守卫必须拒绝回退到本机真实数据目录。
    @Test("未注入目录时守卫拒绝回退到真实数据目录")
    func refusesFallbackWithoutInjection() {
        MailPluginRuntime.injectedFallbackDataDirectory = nil
        defer { MailPluginRuntime.injectedFallbackDataDirectory = nil }

        #expect(MailPluginRuntime.injectedFallbackDataDirectory == nil)

        switch IsolatedDirectoryGuard.resolve(
            injected: MailPluginRuntime.injectedFallbackDataDirectory,
            owner: "MailPluginRuntime",
            accessor: "fallbackDataDirectory()",
            fallback: { URL(fileURLWithPath: "/tmp/mail-fallback", isDirectory: true) }
        ) {
        case .resolved:
            Issue.record("测试进程下未注入目录时不应回退到真实数据目录")
        case let .refused(reason):
            #expect(reason.contains("MailPluginRuntime"))
            #expect(reason.contains("fallbackDataDirectory()"))
        }
    }
}
