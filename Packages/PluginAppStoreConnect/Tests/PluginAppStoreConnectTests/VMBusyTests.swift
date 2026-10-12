import Foundation
import Testing
@testable import PluginAppStoreConnect

/// `runBusy` 的可重入行为。
///
/// 切换 App 会把版本列表、本地化、构建与提交状态串进同一次用户动作，
/// 这些请求各自调用 `runBusy`。如果内层调用重置 `isBusy`，外层已经显示的
/// 遮罩会被中途关掉，表现为一次动作里 loading 反复出现。
@Suite(.serialized)
struct VMBusyTests {

    /// 使用临时目录，避免测试写入真实的插件数据目录。
    @MainActor
    private func makeViewModel() -> VM {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VMBusyTests-\(UUID().uuidString)", isDirectory: true)
        return VM(localStore: AppStoreConnectPluginLocalStore(pluginDirectory: directory))
    }

    /// 等待遮罩出现。
    ///
    /// 遮罩带 500ms 防抖延时，且并行运行测试时主 actor 的调度可能被拖慢，
    /// 因此用轮询代替固定 sleep。
    @MainActor
    private func waitUntilBusy(
        _ viewModel: VM,
        timeout: Duration = .seconds(5)
    ) async -> Bool {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            if viewModel.isBusy { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return viewModel.isBusy
    }

    @Test("nested runBusy keeps one continuous loading overlay")
    @MainActor
    func nestedRunBusyIsReentrant() async {
        let viewModel = makeViewModel()

        var isBusyAtInnerStart: Bool?
        var isBusyAfterInnerFinished: Bool?
        var countDuringInner: Int?

        await viewModel.runBusy {
            // 先确保外层遮罩已经显示，再验证内层不会把它关掉。
            #expect(await waitUntilBusy(viewModel))
            let isBusyBeforeInner = viewModel.isBusy

            await viewModel.runBusy {
                isBusyAtInnerStart = viewModel.isBusy
                countDuringInner = viewModel.busyOperationCount
                try? await Task.sleep(for: VM.loadingOverlayDelay + .milliseconds(150))
                // 内层运行期间遮罩必须持续显示。
                #expect(viewModel.isBusy)
            }

            isBusyAfterInnerFinished = viewModel.isBusy
            #expect(isBusyBeforeInner)
        }

        // 内层既不能关掉遮罩，也不能在结束时提前收尾。
        #expect(isBusyAtInnerStart == true)
        #expect(isBusyAfterInnerFinished == true)
        #expect(countDuringInner == 2)

        // 所有操作结束后遮罩关闭，计数归零。
        #expect(!viewModel.isBusy)
        #expect(viewModel.busyOperationCount == 0)
    }

    @Test("a fast operation never shows the overlay")
    @MainActor
    func fastOperationSkipsOverlay() async {
        let viewModel = makeViewModel()

        await viewModel.runBusy {}

        #expect(!viewModel.isBusy)
        #expect(viewModel.busyOperationCount == 0)
    }

    @Test("a slow operation shows and then hides the overlay")
    @MainActor
    func slowOperationShowsOverlay() async {
        let viewModel = makeViewModel()

        await viewModel.runBusy {
            #expect(await waitUntilBusy(viewModel))
        }

        #expect(!viewModel.isBusy)
        #expect(viewModel.busyOperationCount == 0)
    }
}
