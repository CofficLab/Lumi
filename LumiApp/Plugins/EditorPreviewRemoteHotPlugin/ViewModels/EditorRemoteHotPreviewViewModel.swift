import AppKit
import Combine
import Foundation
import LumiPreviewKit

@MainActor
final class EditorRemoteHotPreviewViewModel: ObservableObject {
    private static let sharedService = EditorRemoteHotPreviewService()

    let service: EditorRemoteHotPreviewService
    private var cancellables: Set<AnyCancellable> = []

    var hostState: EditorRemoteHotPreviewHostState { service.hostState }
    var lastFrameSummary: String { service.lastFrameSummary }
    var previews: [LumiPreviewPackage.PreviewDiscovery] { service.previews }
    var renderImage: NSImage? { service.renderImage }
    var renderMessage: String? { service.renderMessage }
    var diagnostics: String? { service.diagnostics }
    var performanceSummary: String? { service.performanceSummary }
    var transportSummary: String { service.transportSummary }
    var failureMessage: String? { service.failureMessage }
    var updatePhase: EditorRemoteHotPreviewUpdatePhase { service.updatePhase }
    var livePreviewInfo: LumiPreviewPackage.LivePreviewInfo { service.livePreviewInfo }
    var isLiveLoading: Bool { service.isLiveLoading }

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

    var canStartLive: Bool {
        hostState == .connected && !isLiveLoading && livePreviewInfo.state != .running
    }

    var canStopLive: Bool {
        !isLiveLoading && (livePreviewInfo.state == .running || livePreviewInfo.state == .launching)
    }

    init(service: EditorRemoteHotPreviewService = EditorRemoteHotPreviewViewModel.sharedService) {
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

    func startLivePreview() {
        service.startLivePreview(reason: "toolbar live preview button")
    }

    func stopLivePreview() {
        service.stopLivePreview(reason: "toolbar stop live preview button")
    }
}
