import Combine
import Foundation
import KitLLM

/// View state for a provider's model download panel.
@MainActor
public final class ProviderModelDownloadViewModel: ObservableObject {
    @Published public private(set) var downloadState: LLMModelDownloadState
    /// 最近一次下载/删除失败的模型 id（`nil` 表示无错误）。
    @Published public private(set) var errorModelID: String?
    /// 最近一次下载/删除失败的错误信息。
    @Published public private(set) var errorMessage: String?

    public init(initialState: LLMModelDownloadState = .init()) {
        downloadState = initialState
    }

    func apply(_ state: LLMModelDownloadState) {
        guard downloadState != state else { return }
        downloadState = state
    }

    /// 清除当前错误状态（开始新操作前调用）。
    func clearError() {
        errorModelID = nil
        errorMessage = nil
    }

    /// 记录一次下载/删除错误。
    func reportError(modelID: String, message: String) {
        errorModelID = modelID
        errorMessage = message
    }

    // MARK: - 下载操作

    /// 开始下载模型；结束后把失败原因记录到对应模型。
    ///
    /// 下载失败若不落到 `errorModelID` / `errorMessage`，界面就会把一次
    /// 失败静默呈现成「可重新下载」的普通状态，用户看不到任何原因。
    func startDownload(modelID: String, capability: any ModelDownloadCapability) async {
        clearError()
        await capability.download(modelID: modelID)
        capability.refreshDownloadState()
        reportFailureIfNeeded(modelID: modelID, capability: capability)
    }

    /// 继续下载模型；结束后把失败原因记录到对应模型。
    ///
    /// 与 ``startDownload(modelID:capability:)`` 走同一套失败处理：继续
    /// 下载同样可能失败（网络断开、文件校验不通过等），不能只恢复按钮而
    /// 不给用户任何提示。
    func resumeDownload(modelID: String, capability: any ModelDownloadCapability) async {
        clearError()
        await capability.resumeDownload()
        capability.refreshDownloadState()
        reportFailureIfNeeded(modelID: modelID, capability: capability)
    }

    /// 下载状态为 `.failed` 时把失败原因记录到对应模型。
    ///
    /// 状态取自 capability（下载器的权威快照），而不是 ViewModel 自己的
    /// 副本：副本靠 observer 异步同步，操作刚结束时可能还是旧值。
    private func reportFailureIfNeeded(modelID: String, capability: any ModelDownloadCapability) {
        guard case let .failed(message) = capability.downloadState.status else { return }
        reportError(modelID: modelID, message: message)
    }
}
