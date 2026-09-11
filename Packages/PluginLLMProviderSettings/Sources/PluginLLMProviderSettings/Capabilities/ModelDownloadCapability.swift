import Foundation
import KitLLM

/// 模型下载能力：供应商下载面板需要的最小操作集合。
///
/// 由 `ProviderSettingsCapability` 按供应商提供，View 不再直接持有
/// `LLMModelDownloadProviding` 实例。
@MainActor
protocol ModelDownloadCapability: AnyObject {
    var modelCacheDirectoryURL: URL { get }

    func refreshDownloadState()
    func setDownloadSpeedLimit(bytesPerSecond: Int?)
    func download(modelID: String) async
    func pauseDownload()
    func resumeDownload() async
    func cancelDownload()
    func deleteDownloadedModel(modelID: String) throws
}

/// 将 `LLMModelDownloadProviding` 收窄为下载面板能力。
@MainActor
final class ModelDownloadCapabilityAdapter: ModelDownloadCapability {
    private let downloader: any LLMModelDownloadProviding

    init(downloader: any LLMModelDownloadProviding) {
        self.downloader = downloader
    }

    var modelCacheDirectoryURL: URL {
        downloader.modelCacheDirectoryURL
    }

    func refreshDownloadState() {
        downloader.refreshDownloadState()
    }

    func setDownloadSpeedLimit(bytesPerSecond: Int?) {
        downloader.setDownloadSpeedLimit(bytesPerSecond: bytesPerSecond)
    }

    func download(modelID: String) async {
        await downloader.download(modelID: modelID)
    }

    func pauseDownload() {
        downloader.pauseDownload()
    }

    func resumeDownload() async {
        await downloader.resumeDownload()
    }

    func cancelDownload() {
        downloader.cancelDownload()
    }

    func deleteDownloadedModel(modelID: String) throws {
        try downloader.deleteDownloadedModel(modelID: modelID)
    }
}
