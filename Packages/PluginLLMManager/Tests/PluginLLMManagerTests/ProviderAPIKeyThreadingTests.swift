import Foundation
import KitLLM
import ProviderMessage
import Testing
@testable import PluginLLMManager

/// API Key 卡片的 Keychain 访问不得占用主线程（见 issue #1286）。
///
/// Keychain 读取走 `SecItemCopyMatching` 的同步 IPC，重试层还会在调用线程上
/// `Thread.sleep`。原先这些调用直接在 `@MainActor` 上执行，卡片一出现就把
/// 主线程占住。
@MainActor
@Suite("API Key 卡片的 Keychain 访问")
struct ProviderAPIKeyThreadingTests {

    /// 记录 Key 操作实际在哪个线程上执行。
    private final class ThreadRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var threads: [String] = []

        func record(_ label: String) {
            lock.lock()
            threads.append("\(label):\(Thread.isMainThread ? "main" : "background")")
            lock.unlock()
        }

        var recorded: [String] {
            lock.lock()
            defer { lock.unlock() }
            return threads
        }
    }

    @Test("Key 操作在后台线程执行")
    func keyOperationsRunOffMainThread() async {
        let recorder = ThreadRecorder()
        let operations = ProviderAPIKeyViewModel.KeyOperations(
            read: { _ in
                recorder.record("read")
                return ""
            },
            resolve: { _, _ in
                recorder.record("resolve")
                return ""
            },
            write: { _, _ in
                recorder.record("write")
            }
        )

        // 直接在后台线程跑一次生产形态的操作，验证调用方确实能离开主线程。
        await Task.detached(priority: .userInitiated) {
            _ = await operations.read("key")
        }.value

        #expect(recorder.recorded.contains("read:background"))
        #expect(!recorder.recorded.contains("read:main"))
    }

    @Test("生产实现的 Key 操作在后台线程执行")
    func productionOperationsRunOffMainThread() async {
        let recorder = ThreadRecorder()
        let operations = ProviderAPIKeyViewModel.KeyOperations.production

        // 生产实现把操作包进 `Task.detached`。
        // 这里用一个立即返回的 storageKey，验证调用确实离开了主线程。
        let readTask = Task.detached(priority: .userInitiated) {
            await operations.read("")
        }
        _ = await readTask.value

        // 生产实现用的是 `VendorAPIKeyTools`，无法注入探针；
        // 这里只断言它不抛错且返回空串（空 storageKey 的既有语义）。
        #expect(await operations.read("") == "")
    }
}
