import Foundation
import KitLLM
import Testing
@testable import PluginLLMProviderSettings

/// 继续下载失败后必须报告错误，而不是静默回到「可重新下载」状态。
///
/// ## 为什么要有这条测试
///
/// 初次下载的路径会在操作结束后检查 `.failed(let message)` 并把错误记录
/// 到对应模型；继续下载的路径却只 `await capability.resumeDownload()`，
/// 结束后不检查状态，也不记录错误。
///
/// 结果是：下载器已经处于 `.failed`，但界面既不显示失败原因，也不再
/// 显示暂停或进度——用户只看到普通「下载」按钮，无法知道继续操作失败了。
///
/// 正确行为：继续下载结束后与初次下载同样检查失败状态并报告错误。
@MainActor
@Suite("模型下载失败报告")
struct ProviderModelDownloadFailureTests {

    /// 记录调用并可编程状态的下载能力替身。
    private final class StubDownloadCapability: ModelDownloadCapability {
        var modelCacheDirectoryURL: URL { URL(fileURLWithPath: "/tmp") }
        private(set) var resumeCallCount = 0
        private(set) var downloadCallCount = 0
        /// 操作结束后 capability 会发布的状态。
        var resultingStatus: LLMModelDownloadStatus = .failed("网络不可用")
        var downloadState: LLMModelDownloadState {
            LLMModelDownloadState(status: resultingStatus)
        }

        func refreshDownloadState() {}
        func setDownloadSpeedLimit(bytesPerSecond: Int?) {}

        func download(modelID: String) async {
            downloadCallCount += 1
        }

        func pauseDownload() {}

        func resumeDownload() async {
            resumeCallCount += 1
        }

        func cancelDownload() {}

        func deleteDownloadedModel(modelID: String) throws {}
    }

    @Test("继续下载失败后报告错误到对应模型")
    func resumeFailureIsReported() async throws {
        let capability = StubDownloadCapability()
        let viewModel = ProviderModelDownloadViewModel()

        await viewModel.resumeDownload(modelID: "mlx-qwen/Qwen3-0.6B-4bit", capability: capability)

        #expect(capability.resumeCallCount == 1, "应调用一次继续下载")
        #expect(
            viewModel.errorModelID == "mlx-qwen/Qwen3-0.6B-4bit",
            "继续下载失败后必须把错误关联到对应模型，实际 \(String(describing: viewModel.errorModelID))"
        )
        #expect(
            viewModel.errorMessage == "网络不可用",
            "继续下载失败后必须保留失败原因，实际 \(String(describing: viewModel.errorMessage))"
        )
    }

    @Test("初次下载失败后报告错误到对应模型")
    func downloadFailureIsReported() async throws {
        let capability = StubDownloadCapability()
        let viewModel = ProviderModelDownloadViewModel()

        await viewModel.startDownload(modelID: "mlx-qwen/Qwen3-0.6B-4bit", capability: capability)

        #expect(capability.downloadCallCount == 1)
        #expect(viewModel.errorModelID == "mlx-qwen/Qwen3-0.6B-4bit")
        #expect(viewModel.errorMessage == "网络不可用")
    }

    @Test("继续下载成功时不报告错误")
    func resumeSuccessDoesNotReportError() async throws {
        let capability = StubDownloadCapability()
        capability.resultingStatus = .completed
        let viewModel = ProviderModelDownloadViewModel()

        await viewModel.resumeDownload(modelID: "mlx-qwen/Qwen3-0.6B-4bit", capability: capability)

        #expect(viewModel.errorModelID == nil, "成功时不应留下错误")
        #expect(viewModel.errorMessage == nil)
    }

    @Test("开始新操作前清除旧错误")
    func newOperationClearsPreviousError() async throws {
        let capability = StubDownloadCapability()
        let viewModel = ProviderModelDownloadViewModel()

        await viewModel.resumeDownload(modelID: "model-a", capability: capability)
        #expect(viewModel.errorModelID == "model-a")

        capability.resultingStatus = .completed
        await viewModel.resumeDownload(modelID: "model-b", capability: capability)

        #expect(viewModel.errorModelID == nil, "新操作应先清除旧错误")
        #expect(viewModel.errorMessage == nil)
    }
}
