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
}
