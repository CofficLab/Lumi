import Foundation
import Testing
@testable import DisplayControlPlugin

/// 显示器列表变化同步回归（#459）。
///
/// 此前 DisplayControlObserver 订阅 `objectWillChange`（`willSet` 阶段发出），
/// 同步执行 `viewModel.apply(service)` 时读到的仍是写入前的旧数组，导致
/// ViewModel 每轮刷新拿到上一轮的显示器列表。修复后改为订阅
/// `displaysDidChange`（`displays` 写入完成后由 `didSet` 发出）。
///
/// `DisplayService.shared` 持有的 LocalStore 单例在初始化时会访问
/// `DisplayControlRuntime.settingsDirectory()`，测试进程必须先注入目录。
@Suite("DisplayControl Observer 同步", .serialized)
@MainActor
struct DisplayControlObserverSyncTests {

    @Test("displays 写入后 ViewModel 立即同步新列表，不再滞后一轮（**回归 #459**）")
    func observerPropagatesDisplaysImmediatelyAfterWrite() {
        let directory = DisplayControlTestDoubles.makeTemporaryDirectory("observer-sync")
        DisplayControlRuntime.configure(settingsDirectory: directory)
        defer {
            DisplayControlRuntime.reset()
            try? FileManager.default.removeItem(at: directory)
        }

        let service = DisplayService.shared
        defer { service.setDisplaysForTesting([]) }

        let first = ControlledDisplay(
            id: 1,
            storageID: "sync-a",
            name: "Sync A",
            isBuiltIn: false,
            supportsBrightness: true,
            supportsVolume: false,
            supportsContrast: false,
            brightness: 50,
            volume: 40,
            contrast: 75
        )
        let second = ControlledDisplay(
            id: 2,
            storageID: "sync-b",
            name: "Sync B",
            isBuiltIn: true,
            supportsBrightness: true,
            supportsVolume: true,
            supportsContrast: false,
            brightness: 60,
            volume: 30,
            contrast: 70
        )

        service.setDisplaysForTesting([first])
        let viewModel = DisplayControlViewModel(service: service)
        let observer = DisplayControlObserver(viewModel: viewModel, service: service)
        defer { observer.cancel() }
        #expect(viewModel.displays.map(\.id) == [first.id])

        // 模拟下一轮刷新结果：写入新列表后，ViewModel 必须同步拿到新列表
        // （didSet → displaysDidChange → sink → apply 全链路同步，无需等待）。
        service.setDisplaysForTesting([first, second])
        #expect(viewModel.displays.map(\.id) == [first.id, second.id])
    }
}
