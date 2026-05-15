import AppKit
import Combine
import Foundation
import LumiPreviewKit

@MainActor
final class EditorRemoteHotPreviewViewModel: ObservableObject {
    private static let sharedService = EditorPreviewService()

    let service: EditorPreviewService
    private var cancellables: Set<AnyCancellable> = []

    var hostState: EditorRemoteHotPreviewHostState { service.hostState }
    var lastFrameSummary: String { service.lastFrameSummary }
    var previews: [LumiPreviewFacade.PreviewDiscovery] { service.previews }
    var renderImage: NSImage? { service.renderImage }
    var renderMessage: String? { service.renderMessage }
    var diagnostics: String? { service.diagnostics }
    var performanceSummary: String? { service.performanceSummary }
    var transportSummary: String { service.transportSummary }
    var failureMessage: String? { service.failureMessage }
    var updatePhase: EditorRemoteHotPreviewUpdatePhase { service.updatePhase }
    var diagnosticSummary: String { service.diagnosticSummary }
    var livePreviewInfo: LumiPreviewFacade.LivePreviewInfo { service.livePreviewInfo }
    var isLiveLoading: Bool { service.isLiveLoading }
    var effectiveDisplayMode: LumiPreviewFacade.PreviewDisplayMode { service.effectiveDisplayMode }
    var preferredDisplayMode: LumiPreviewFacade.PreviewDisplayMode { service.preferredDisplayMode }
    var modeStatusMessage: String? { service.modeStatusMessage }
    var isShowingStaleFrame: Bool { service.isShowingStaleFrame }
    var isMarkdownMode: Bool { service.isMarkdownMode }
    var markdownSource: String? { service.markdownSource }
    var isImageMode: Bool { service.isImageMode }
    var imageFileURL: URL? { service.imageFileURL }
    var canSwitchToLive: Bool { service.canSwitchToLive }
    var canSwitchToImage: Bool { service.canSwitchToImage }
    var liveUnavailableReason: String? { service.liveUnavailableReason }
    var projectPreviewIndexSummary: String { service.projectPreviewIndexSummary }
    var prewarmSummary: String { service.prewarmSummary }

    var selectedPreviewID: String? {
        get { service.selectedPreviewID }
        set { service.selectPreview(id: newValue) }
    }

    var canStart: Bool {
        hostState == .idle || hostState == .failed
    }

    var canStop: Bool {
        hostState != .idle
    }

    init(service: EditorPreviewService = EditorRemoteHotPreviewViewModel.sharedService) {
        self.service = service
        service.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
    }

    func update(sourceText: String?, fileURL: URL?, projectRootPath: String?, reloadPolicy: EditorPreviewService.UpdateReloadPolicy = .reloadOnFingerprintChange) {
        service.update(sourceText: sourceText, fileURL: fileURL, projectRootPath: projectRootPath, reloadPolicy: reloadPolicy)
    }

    func viewDidAppear() {
        service.detailViewDidAppear()
    }

    func startHost() {
        service.start(reason: "toolbar start button")
    }

    func renderFrame() {
        service.reload(reason: "toolbar reload button")
    }

    func scheduleRenderFrame(reason: String) {
        service.scheduleReload(reason: reason)
    }

    func stopHost() {
        service.stop(reason: "toolbar stop button")
    }

    func switchToLive() {
        service.switchToLive()
    }

    func switchToImage() {
        service.switchToImage()
    }

    func viewDidDisappear() {
        service.detailViewDidDisappear()
    }

    func liveCanvasDidAppear() {
        service.liveCanvasDidAppear()
    }

    func liveCanvasDidDisappear() {
        service.liveCanvasDidDisappear()
    }

    func liveCanvasFrameUnavailable() {
        service.liveCanvasFrameUnavailable()
    }

    func updateLiveCanvasRect(_ rect: CGRect, scale: CGFloat) {
        service.updateLiveCanvasRect(rect, scale: scale)
    }

    func previewWindowDidBecomeActive() {
        service.previewWindowDidBecomeActive()
    }

    func previewWindowDidBecomeInactive() {
        service.previewWindowDidBecomeInactive()
    }

    func previewWindowVisibilityDidChange(_ isVisible: Bool) {
        service.previewWindowVisibilityDidChange(isVisible)
    }

    func previewAppDidBecomeActive() {
        service.previewAppDidBecomeActive()
    }

    func previewAppDidResignActive() {
        service.previewAppDidResignActive()
    }

    func previewWindowDidReceiveInteraction() {
        service.previewWindowDidReceiveInteraction()
    }

    func previewWindowDidMiniaturize() {
        service.previewWindowDidMiniaturize()
    }

    func previewWindowDidDeminiaturize() {
        service.previewWindowDidDeminiaturize()
    }
}
