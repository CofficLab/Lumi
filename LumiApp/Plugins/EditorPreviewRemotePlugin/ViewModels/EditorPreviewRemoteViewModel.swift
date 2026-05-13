import Combine
import Foundation
import LumiPreviewKit
import AppKit

@MainActor
final class EditorPreviewRemoteViewModel: ObservableObject {
    private static let sharedService = EditorPreviewRemoteService()

    let service: EditorPreviewRemoteService
    private var cancellables: Set<AnyCancellable> = []

    var hostState: EditorPreviewRemoteHostState {
        service.hostState
    }

    var lastFrameSummary: String {
        service.lastFrameSummary
    }

    var previews: [LumiPreviewPackage.PreviewDiscovery] {
        service.previews
    }

    var selectedPreviewID: String? {
        get { service.selectedPreviewID }
        set { service.selectPreview(id: newValue) }
    }

    var renderImage: NSImage? {
        service.renderImage
    }

    var renderSurfaceFrame: LumiPreviewPackage.PreviewSurfaceFrame? {
        service.renderSurfaceFrame
    }

    var renderMessage: String? {
        service.renderMessage
    }

    var diagnostics: String? {
        service.diagnostics
    }

    var performanceSummary: String? {
        service.performanceSummary
    }

    var livePreviewInfo: LumiPreviewPackage.LivePreviewInfo {
        service.livePreviewInfo
    }

    var isLiveLoading: Bool {
        service.isLiveLoading
    }

    var staleLivePreviewMessage: String? {
        service.staleLivePreviewMessage
    }

    var updatePhase: EditorPreviewRemoteUpdatePhase {
        service.updatePhase
    }

    var failureMessage: String? {
        service.failureMessage
    }

    var diagnosticSummary: String {
        service.diagnosticSummary
    }

    var canStart: Bool {
        hostState == .idle || hostState == .failed
    }

    var canStop: Bool {
        hostState != .idle
    }

    init(service: EditorPreviewRemoteService = EditorPreviewRemoteViewModel.sharedService) {
        self.service = service
        service.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func update(sourceText: String?, fileURL: URL?) {
        service.update(sourceText: sourceText, fileURL: fileURL)
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
}
