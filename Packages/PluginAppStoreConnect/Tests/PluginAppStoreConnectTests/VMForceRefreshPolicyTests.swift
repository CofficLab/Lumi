import Foundation
import Testing
@testable import PluginAppStoreConnect

/// 回归覆盖 issue #437：并发的 force refresh 操作各自保存/还原共享的
/// `client.fetchPolicy`。先结束者提前还原策略（窗口内的请求仍可读缓存），
/// 后结束者把 `networkOnly` 永久留在 client 上。
///
/// 修复后按窗口计数：首个操作记住原策略并切到 networkOnly，最后一个
/// 操作恢复原策略。
@Suite(.serialized)
struct VMForceRefreshPolicyTests {

    @MainActor
    private func makeViewModel() -> VM {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VMForceRefreshPolicyTests-\(UUID().uuidString)", isDirectory: true)
        // VM 构造会带出 ConnectAPICache，测试进程里必须先注入隔离目录。
        AppStoreConnectPluginRuntimeBridge.pluginSubdirectory = directory
        return VM(localStore: AppStoreConnectPluginLocalStore(pluginDirectory: directory))
    }

    @MainActor
    @Test("重叠的 force refresh：先结束者不得提前还原策略，最后恢复 cacheFirst")
    func overlappingForceRefreshKeepsPolicyAcrossWindow() async throws {
        let vm = makeViewModel()
        vm.client.fetchPolicy = .cacheFirst

        var contA: CheckedContinuation<Void, Never>?
        var contB: CheckedContinuation<Void, Never>?

        let taskA = Task { @MainActor in
            await vm.runBusy(forceRefresh: true) {
                await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                    contA = c
                }
            }
        }
        while contA == nil {
            try await Task.sleep(nanoseconds: 5_000_000)
        }

        let taskB = Task { @MainActor in
            await vm.runBusy(forceRefresh: true) {
                await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                    contB = c
                }
            }
        }
        while contB == nil {
            try await Task.sleep(nanoseconds: 5_000_000)
        }

        // 窗口内两个操作都在跑：策略必须是 networkOnly。
        #expect(vm.busyOperationCount == 2)
        #expect(vm.client.fetchPolicy == .networkOnly)

        // A 先结束：B 仍在跑，策略不得提前还原。
        contA?.resume()
        await taskA.value
        #expect(vm.busyOperationCount == 1)
        #expect(vm.client.fetchPolicy == .networkOnly)

        // B 后结束：窗口关闭，恢复原始 cacheFirst（而不是 B 当时保存的
        // networkOnly）。
        contB?.resume()
        await taskB.value
        #expect(vm.busyOperationCount == 0)
        #expect(vm.client.fetchPolicy == .cacheFirst)
    }
}
