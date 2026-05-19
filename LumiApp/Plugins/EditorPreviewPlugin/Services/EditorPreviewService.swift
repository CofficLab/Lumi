import AppKit
import MagicKit
import Foundation
import LumiPreviewKit
import StringCatalogKit

@MainActor
final class EditorPreviewService: ObservableObject, SuperLog {
    enum UpdateReloadPolicy {
        case scanOnly
        case reloadOnFingerprintChange
    }

    private static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "tiff", "tif", "bmp", "webp",
        "svg", "icns", "ico", "heic", "heif"
    ]
    private static let markdownExtensions: Set<String> = ["md", "markdown"]
    private static let stringCatalogExtensions: Set<String> = ["xcstrings"]
    private static let maxBackgroundPrewarmCount = 4
    private static let minimumEditorIdleIntervalBeforePrewarm: TimeInterval = 1.5
    private static let maximumPrewarmResourceDeferral: TimeInterval = 4.0
    private static let hostIdleShutdownDelay: TimeInterval = 600
    private static let previewHistoryStorageKey = "EditorRemoteHotPreview.ProjectHistory"

    private enum PrewarmResourceAction: Equatable {
        case run
        case `defer`
        case skip
    }

    private enum PrewarmPriority: Int {
        case indexedProject = 0
        case currentFile = 1
    }

    private struct PrewarmResourceDecision {
        let action: PrewarmResourceAction
        let summary: String
    }

    private struct ProjectPreviewHistory: Codable {
        var recentFilePaths: [String] = []
        var successfulFilePaths: [String] = []
        var previewStartCountsByFilePath: [String: Int] = [:]
        var failedPrewarmFingerprints: [String] = []
    }

    nonisolated static let emoji = "⚡"
    @Published private(set) var hostState: EditorRemoteHotPreviewHostState = .idle
    @Published private(set) var lastFrame: EditorRemoteHotPreviewFrame?
    @Published private(set) var previews: [LumiPreviewFacade.PreviewDiscovery] = []
    @Published var selectedPreviewID: String?
    @Published private(set) var renderImage: NSImage?
    @Published private(set) var renderMessage: String?
    @Published private(set) var diagnostics: String?
    @Published private(set) var performanceSummary: String?
    @Published private(set) var transportSummary = "-"
    @Published private(set) var failureMessage: String?
    @Published private(set) var updatePhase: EditorRemoteHotPreviewUpdatePhase = .idle
    @Published private(set) var lastFrameSummary = String(localized: "No Frame", table: "EditorPreview")
    @Published private(set) var diagnosticSummary = "host: idle | live: available | frame: 0, 0, 0 x 0"
    @Published private(set) var livePreviewInfo = LumiPreviewFacade.LivePreviewInfo()
    @Published private(set) var isLiveLoading = false
    @Published private(set) var preferredDisplayMode: LumiPreviewFacade.PreviewDisplayMode = .live
    @Published private(set) var effectiveDisplayMode: LumiPreviewFacade.PreviewDisplayMode = .image
    @Published private(set) var modeStatusMessage: String?
    @Published private(set) var isShowingStaleFrame = false
    @Published private(set) var isMarkdownMode = false
    @Published private(set) var markdownSource: String?
    @Published private(set) var isImageMode = false
    @Published private(set) var imageFileURL: URL?
    @Published private(set) var isStringCatalogMode = false
    @Published private(set) var stringCatalog: StringCatalog?
    @Published private(set) var projectPreviewIndexSummary = "index: idle"
    @Published private(set) var prewarmSummary = "prewarm: idle"
    @Published private(set) var prewarmStatsSummary = "prewarm stats: 0/0"
    @Published private(set) var prewarmResourceSummary = "prewarm resources: ready"
    @Published private(set) var startupTimingSummary = "startup: idle"
    @Published private(set) var hostLifecycleSummary = "host lifecycle: cold"
    @Published private(set) var prewarmCandidateSummary = "prewarm candidates: idle"

    private let scanner = LumiPreviewFacade.PreviewScanner()
    private let imageLoader = LumiPreviewFacade.ImageFileLoader()
    private let liveCanvasService = LumiPreviewFacade.LiveCanvasService(displayMode: .live)
    private let projectPreviewIndexService = LumiPreviewFacade.ProjectPreviewIndexService()
    private var previewSession: LumiPreviewFacade.HotPreviewSession?
    private var previewEngine: LumiPreviewFacade.HotPreviewEngine?
    private var commandTask: Task<Void, Never>?
    private var scheduledRefreshTask: Task<Void, Never>?
    private var scheduledPrewarmTask: Task<Void, Never>?
    private var scheduledHostIdleShutdownTask: Task<Void, Never>?
    private var isExecutingCommand = false
    private var pendingReloadReason: String?
    private var activeFileURL: URL?
    private var activeSourceText: String?
    private var activeFileGeneration = 0
    private var lastRenderedPreviewFingerprint: String?
    private var lastPrewarmedPreviewFingerprint: String?
    private var scheduledPrewarmFingerprint: String?
    private var scheduledPrewarmPriority: PrewarmPriority?
    private var prewarmedPreviewFingerprints: Set<String> = []
    private var scheduledPrewarmFingerprints: Set<String> = []
    private var activeProjectHistoryKey: String?
    private var recentPreviewFilePaths: [String] = []
    private var successfulPreviewFilePaths: [String] = []
    private var previewStartCountsByFilePath: [String: Int] = [:]
    private var failedPrewarmFingerprints: Set<String> = []
    private var prewarmAttemptCount = 0
    private var prewarmSuccessCount = 0
    private var prewarmFailureCount = 0
    private var prewarmCachedEntryCount = 0
    private var previewStartCount = 0
    private var prewarmHitCount = 0
    private var totalSuccessfulPrewarmDuration: TimeInterval = 0
    private var lastSourceUpdateAt: Date?
    private var shouldRestorePreferredLiveMode = true
    private var isDetailViewVisible = false
    private var isPreviewWindowVisible = false
    private var isLivePreviewShown = false

    init() {
        EditorPreviewStorage.installIfNeeded()
        bindLiveCanvasService()
        bindProjectPreviewIndexService()
        warmupHostIfPossible()
        refreshDiagnosticSummary()
    }

    deinit {
        commandTask?.cancel()
        scheduledRefreshTask?.cancel()
        scheduledPrewarmTask?.cancel()
        scheduledHostIdleShutdownTask?.cancel()
        let engine = previewEngine
        Task {
            await engine?.shutdownHosts()
        }
    }

    func update(
        sourceText: String?,
        fileURL: URL?,
        projectRootPath: String?,
        reloadPolicy: UpdateReloadPolicy = .reloadOnFingerprintChange
    ) {
        let activeFileChanged = !Self.sameFile(activeFileURL, fileURL)
        if activeFileChanged {
            activeFileGeneration &+= 1
            clearPreviewForActiveFileChange()
        }

        activeSourceText = sourceText
        activeFileURL = fileURL
        updateProjectHistoryContext(projectRootPath: projectRootPath, fileURL: fileURL)
        projectPreviewIndexService.prepareIndex(projectRootPath: projectRootPath, currentFileURL: fileURL)

        if let fileURL,
           Self.imageExtensions.contains(fileURL.pathExtension.lowercased()) {
            teardownPreviewSessionForExternalModeChange()
            isMarkdownMode = false
            markdownSource = nil
            isImageMode = true
            imageFileURL = fileURL
            isStringCatalogMode = false
            stringCatalog = nil
            previews = []
            selectedPreviewID = nil
            renderImage = nil
            hostState = .idle
            updatePhase = .idle
            failureMessage = nil
            renderMessage = nil
            diagnostics = nil
            performanceSummary = nil
            transportSummary = "-"
            livePreviewInfo = LumiPreviewFacade.LivePreviewInfo()
            effectiveDisplayMode = .image
            isShowingStaleFrame = false
            modeStatusMessage = nil
            lastFrame = nil
            lastFrameSummary = String(localized: "No Frame", table: "EditorPreview")
            refreshDiagnosticSummary()
            return
        }

        isImageMode = false
        imageFileURL = nil

        if let sourceText,
           let fileURL,
           Self.markdownExtensions.contains(fileURL.pathExtension.lowercased()) {
            teardownPreviewSessionForExternalModeChange()
            isMarkdownMode = true
            markdownSource = sourceText
            isImageMode = false
            imageFileURL = nil
            isStringCatalogMode = false
            stringCatalog = nil
            previews = []
            selectedPreviewID = nil
            renderImage = nil
            hostState = .idle
            updatePhase = .idle
            failureMessage = nil
            renderMessage = nil
            diagnostics = nil
            performanceSummary = nil
            transportSummary = "-"
            livePreviewInfo = LumiPreviewFacade.LivePreviewInfo()
            effectiveDisplayMode = .image
            isShowingStaleFrame = false
            modeStatusMessage = nil
            lastFrame = nil
            lastFrameSummary = String(localized: "No Frame", table: "EditorPreview")
            refreshDiagnosticSummary()
            return
        }

        isMarkdownMode = false
        markdownSource = nil

        if let sourceText,
           let fileURL,
           Self.stringCatalogExtensions.contains(fileURL.pathExtension.lowercased()) {
            teardownPreviewSessionForExternalModeChange()
            isMarkdownMode = false
            markdownSource = nil
            isImageMode = false
            imageFileURL = nil
            isStringCatalogMode = true
            do {
                stringCatalog = try StringCatalogParser.parse(sourceText)
                failureMessage = nil
            } catch {
                stringCatalog = nil
                failureMessage = String(
                    format: String(localized: "Failed to load string catalog: %@", table: "EditorPreview"),
                    error.localizedDescription
                )
            }
            previews = []
            selectedPreviewID = nil
            renderImage = nil
            hostState = .idle
            updatePhase = .idle
            renderMessage = nil
            diagnostics = nil
            performanceSummary = nil
            transportSummary = "-"
            livePreviewInfo = LumiPreviewFacade.LivePreviewInfo()
            effectiveDisplayMode = .image
            isShowingStaleFrame = false
            modeStatusMessage = nil
            lastFrame = nil
            lastFrameSummary = String(localized: "No Frame", table: "EditorPreview")
            refreshDiagnosticSummary()
            return
        }

        isStringCatalogMode = false
        stringCatalog = nil

        guard let sourceText, let fileURL, fileURL.pathExtension == "swift" else {
            previews = []
            selectedPreviewID = nil
            clearPreviewForUnavailableSource()
            return
        }

        let nextPreviews = sourceText.contains("#Preview")
            ? scanner.scan(fileURL: fileURL, sourceText: sourceText)
            : []
        projectPreviewIndexService.refreshCurrentFile(fileURL: fileURL, sourceText: sourceText, previews: nextPreviews)
        previews = nextPreviews
        lastSourceUpdateAt = Date()
        if !nextPreviews.isEmpty {
            touchRecentPreviewFile(fileURL)
        }

        guard reloadPolicy == .reloadOnFingerprintChange else {
            if selectedPreviewID == nil || !nextPreviews.contains(where: { $0.id == selectedPreviewID }) {
                selectedPreviewID = nextPreviews.first?.id
            }
            refreshDiagnosticSummary()
            return
        }

        if let selectedPreviewID,
           nextPreviews.contains(where: { $0.id == selectedPreviewID }) {
            if previewSession != nil,
               let selectedPreview,
               previewFingerprint(for: selectedPreview) != lastRenderedPreviewFingerprint {
                scheduleReload(reason: "selected hot preview fingerprint changed after source scan")
            } else if previewSession == nil {
                scheduleCurrentFilePrewarm(preferredPreviewID: selectedPreviewID, previews: nextPreviews)
            }
            return
        }

        selectedPreviewID = nextPreviews.first?.id
        if nextPreviews.isEmpty {
            clearPreviewForUnavailableSource()
        } else if previewSession != nil {
            reload(reason: "selected hot preview changed after source scan")
        } else {
            scheduleCurrentFilePrewarm(preferredPreviewID: selectedPreviewID, previews: nextPreviews)
        }
    }

    func selectPreview(id: String?) {
        guard selectedPreviewID != id else { return }
        selectedPreviewID = id
        guard id != nil else {
            stop(reason: "hot preview selection cleared")
            return
        }
        if previewSession != nil {
            reload(reason: "hot preview selection changed")
        } else {
            start(reason: "hot preview selection changed")
        }
    }

    func start(reason: String) {
        run(.start(reason: reason))
    }

    func reload(reason: String) {
        guard previewSession != nil else {
            start(reason: reason)
            return
        }
        guard needsReload else {
            updatePhase = .idle
            return
        }
        guard !isExecutingCommand else {
            pendingReloadReason = reason
            updatePhase = .waitingToRefresh
            return
        }
        run(.reload(reason: reason))
    }

    func scheduleReload(reason: String) {
        guard previewSession != nil else {
            start(reason: reason)
            return
        }
        guard needsReload else {
            updatePhase = .idle
            return
        }

        scheduledRefreshTask?.cancel()
        updatePhase = .waitingToRefresh
        scheduledRefreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            self?.reload(reason: "scheduled hot preview refresh: \(reason)")
        }
    }

    func stop(reason: String) {
        run(.stop(reason: reason))
    }

    func showExternalModeFailure(_ message: String) {
        failureMessage = message
        refreshDiagnosticSummary()
    }

    var canSwitchToLive: Bool {
        guard previewSession != nil, hostState == .connected else { return false }
        switch livePreviewInfo.state {
        case .available, .running, .stopped:
            return true
        case .failed, .launching, .unavailable:
            return false
        }
    }

    var canSwitchToImage: Bool {
        preferredDisplayMode == .live
    }

    var liveUnavailableReason: String? {
        guard previewSession != nil else {
            return String(localized: "Start a preview first", table: "EditorPreview")
        }
        switch livePreviewInfo.state {
        case .unavailable:
            return String(localized: "Live requires a real SwiftUI view entry", table: "EditorPreview")
        case .failed:
            return livePreviewInfo.unavailableReason
                ?? String(localized: "Live preview failed", table: "EditorPreview")
        case .launching:
            return String(localized: "Live preview is starting", table: "EditorPreview")
        case .available, .running:
            return nil
        case .stopped:
            return String(localized: "Live preview stopped", table: "EditorPreview")
        }
    }

    func switchToLive() {
        preferredDisplayMode = .live
        liveCanvasService.updateDisplayMode(.live)
        shouldRestorePreferredLiveMode = true
        syncModeStatusMessage()
        refreshDiagnosticSummary()
        Task { [weak self] in
            await self?.restoreOrStartLivePreviewAfterModeSwitch()
        }
    }

    func switchToImage() {
        preferredDisplayMode = .image
        liveCanvasService.updateDisplayMode(.image)
        syncModeStatusMessage()
        refreshDiagnosticSummary()
        Task { [weak self] in
            await self?.switchToImageMode()
        }
    }

    func detailViewDidDisappear() {
        isDetailViewVisible = false
        isPreviewWindowVisible = false
        liveCanvasService.canvasDidDisappear()
        Task { [weak self] in
            await self?.hideLivePreviewIfNeeded(reason: "hot preview panel disappeared")
        }
        refreshDiagnosticSummary()
    }

    func detailViewDidAppear() {
        isDetailViewVisible = true
        Task { [weak self] in
            await self?.restoreLivePreviewIfNeeded(reason: "hot preview panel appeared")
        }
        refreshDiagnosticSummary()
    }

    func liveCanvasDidAppear() {
        liveCanvasService.canvasDidAppear()
        Task { [weak self] in
            await self?.restoreLivePreviewIfNeeded(reason: "hot live canvas appeared")
        }
        refreshDiagnosticSummary()
    }

    func liveCanvasDidDisappear() {
        liveCanvasService.canvasDidDisappear()
        refreshDiagnosticSummary()
    }

    func liveCanvasFrameUnavailable() {
        liveCanvasService.canvasFrameUnavailable()
        refreshDiagnosticSummary()
    }

    func updateLiveCanvasRect(_ rect: CGRect, scale: CGFloat) {
        liveCanvasService.updateLiveCanvasRect(rect, scale: scale)
        refreshDiagnosticSummary()
    }

    func previewWindowDidBecomeActive() {
        isPreviewWindowVisible = true
        Task { [weak self] in
            await self?.restoreLivePreviewIfNeeded(reason: "preview window became active")
            await self?.showLivePreviewIfNeeded(reason: "preview window became active", forceOrderFront: true)
        }
    }

    func previewWindowDidBecomeInactive() {
        refreshDiagnosticSummary()
    }

    func previewWindowVisibilityDidChange(_ isVisible: Bool) {
        isPreviewWindowVisible = isVisible
        if isVisible {
            Task { [weak self] in
                await self?.restoreLivePreviewIfNeeded(reason: "preview window became visible")
                await self?.showLivePreviewIfNeeded(reason: "preview window became visible", forceOrderFront: true)
            }
        } else {
            liveCanvasService.cancelPendingFrameSync()
            Task { [weak self] in
                await self?.hideLivePreviewIfNeeded(reason: "preview window became hidden")
            }
        }
        refreshDiagnosticSummary()
    }

    func previewAppDidBecomeActive() {
        liveCanvasService.appDidBecomeActive()
        Task { [weak self] in
            await self?.restoreLivePreviewIfNeeded(reason: "preview app became active")
            await self?.showLivePreviewIfNeeded(reason: "preview app became active", forceOrderFront: true)
        }
    }

    func previewAppDidResignActive() {
        liveCanvasService.appDidResignActive()
        Task { [weak self] in
            await self?.hideLivePreviewIfNeeded(reason: "preview app resigned active")
        }
        refreshDiagnosticSummary()
    }

    func previewWindowDidReceiveInteraction() {
        isPreviewWindowVisible = true
        Task { [weak self] in
            await self?.restoreLivePreviewIfNeeded(reason: "preview window received interaction")
            await self?.showLivePreviewIfNeeded(reason: "preview window received interaction", forceOrderFront: true)
        }
    }

    func previewWindowDidMiniaturize() {
        Task { [weak self] in
            await self?.hideLivePreviewIfNeeded(reason: "preview window miniaturized")
        }
    }

    func previewWindowDidDeminiaturize() {
        Task { [weak self] in
            await self?.restoreLivePreviewIfNeeded(reason: "preview window deminiaturized")
        }
    }

    private func startLivePreview(reason: String) {
        let generation = activeFileGeneration
        Task { [weak self] in
            await self?.startLivePreviewSession(reason: reason, generation: generation)
        }
    }

    private func stopLivePreview(reason: String) {
        Task { [weak self] in
            await self?.stopLivePreviewSession(reason: reason)
        }
    }

    private func run(_ command: EditorRemoteHotPreviewCommand) {
        if case .reload = command, isExecutingCommand {
            if case let .reload(reason) = command {
                pendingReloadReason = reason
                updatePhase = .waitingToRefresh
            }
            return
        }

        let generation = activeFileGeneration
        commandTask?.cancel()
        commandTask = Task { [weak self] in
            guard let self else { return }
            await execute(command, generation: generation)
        }
    }

    private func execute(_ command: EditorRemoteHotPreviewCommand, generation: Int) async {
        guard isCurrentFileGeneration(generation) else { return }
        isExecutingCommand = true
        defer {
            isExecutingCommand = false
            runPendingReloadIfNeeded()
        }

        switch command {
        case let .start(reason):
            await startSession(reason: reason, generation: generation)
        case let .reload(reason):
            await reloadSession(reason: reason, generation: generation)
        case let .stop(reason):
            await stopSession(reason: reason, generation: generation)
        }
    }

    private func runPendingReloadIfNeeded() {
        guard let reason = pendingReloadReason,
              previewSession != nil,
              !isExecutingCommand else {
            return
        }
        pendingReloadReason = nil
        run(.reload(reason: reason))
    }

    private func startSession(reason: String, generation: Int) async {
        guard isCurrentFileGeneration(generation) else { return }
        if EditorRemoteHotPreviewPlugin.verbose {
                    EditorRemoteHotPreviewPlugin.logger.info("\(self.t)Starting hot preview: \(reason, privacy: .public)")
        }
        scheduledHostIdleShutdownTask?.cancel()
        scheduledHostIdleShutdownTask = nil
        scheduledRefreshTask?.cancel()
        scheduledRefreshTask = nil
        scheduledPrewarmTask?.cancel()
        scheduledPrewarmTask = nil
        scheduledPrewarmFingerprint = nil
        scheduledPrewarmPriority = nil
        scheduledPrewarmFingerprints = []
        liveCanvasService.cancelPendingFrameSync()

        guard let selectedPreview else {
            resetRenderState()
            lastFrameSummary = String(localized: "No Preview", table: "EditorPreview")
            return
        }
        let selectedFingerprint = previewFingerprint(for: selectedPreview)
        recordPreviewStart(fingerprint: selectedFingerprint, fileURL: selectedPreview.sourceFileURL)

        guard let hostExecutableURL = LumiPreviewFacade.HotPreviewHostExecutableResolver.resolve() else {
            handle(.failed(message: String(localized: "Hot preview host executable was not found.", table: "EditorPreview")))
            return
        }
        if let previousSession = previewSession, let previousEngine = previewEngine {
            try? await previousEngine.stopLivePreview(previousSession)
            await previousEngine.stopPreview(previousSession)
        }
        isLivePreviewShown = false

        if isSelectedPreviewAlreadyRendered(selectedPreview) {
            preserveCurrentFrameForRestart(message: String(localized: "Rebuilding hot preview. Showing the previous frame.", table: "EditorPreview"))
        } else {
            clearRenderedFrameForPreviewChange()
        }
        hostState = .launching
        updatePhase = .refreshing
        failureMessage = nil
        renderMessage = nil
        diagnostics = nil
        performanceSummary = nil
        transportSummary = "-"
        lastFrame = nil
        lastFrameSummary = String(localized: "Waiting for Host", table: "EditorPreview")

        let engine = previewEngine ?? LumiPreviewFacade.HotPreviewEngine(hostExecutableURL: hostExecutableURL)
        previewEngine = engine
        hostLifecycleSummary = "host lifecycle: acquired"

        do {
            let session = try await engine.startPreview(selectedPreview)
            guard !Task.isCancelled, isCurrentFileGeneration(generation) else {
                await engine.stopPreview(session)
                return
            }
            previewSession = session
            await syncPreviewState(from: session)
            lastRenderedPreviewFingerprint = selectedFingerprint
            recordSuccessfulPreviewFile(selectedPreview.sourceFileURL)
            handle(.frameRendered(makeFrame()))
            if preferredDisplayMode == .live, shouldRestorePreferredLiveMode {
                await startLivePreviewSession(reason: "restoring preferred live mode after start", generation: generation)
            }
            updatePhase = .idle
        } catch let error as LumiPreviewFacade.PreviewError {
            guard isCurrentFileGeneration(generation) else { return }
            handle(.failed(message: EditorPreviewFormatter.message(for: error)))
        } catch {
            guard isCurrentFileGeneration(generation) else { return }
            handle(.failed(message: error.localizedDescription))
        }
    }

    private func reloadSession(reason: String, generation: Int) async {
        guard isCurrentFileGeneration(generation) else { return }
        scheduledRefreshTask?.cancel()
        scheduledRefreshTask = nil
        scheduledPrewarmTask?.cancel()
        scheduledPrewarmTask = nil
        scheduledPrewarmFingerprint = nil
        scheduledPrewarmPriority = nil
        scheduledPrewarmFingerprints = []
        liveCanvasService.cancelPendingFrameSync()
        guard let previewSession, let previewEngine else {
            if EditorRemoteHotPreviewPlugin.verbose {
                            EditorRemoteHotPreviewPlugin.logger.debug(
                                "\(self.t)Skipping hot preview reload without a session: \(reason, privacy: .public)"
                            )
            }
            return
        }

        if EditorRemoteHotPreviewPlugin.verbose {
                    EditorRemoteHotPreviewPlugin.logger.info("\(self.t)Reloading hot preview: \(reason, privacy: .public)")
        }
        hostState = .rendering
        updatePhase = .refreshing
        failureMessage = nil
        lastFrameSummary = String(localized: "Frame Pending", table: "EditorPreview")
        let isReloadingRenderedPreview = selectedPreview.map(isSelectedPreviewAlreadyRendered) ?? false
        if !isReloadingRenderedPreview {
            clearRenderedFrameForPreviewChange()
        }

        do {
            if let selectedPreview {
                await previewSession.updateDiscovery(selectedPreview)
            }
            try await previewEngine.refreshPreview(previewSession)
            guard !Task.isCancelled, isCurrentFileGeneration(generation) else { return }
            await syncPreviewState(from: previewSession)
            if let selectedPreview {
                lastRenderedPreviewFingerprint = previewFingerprint(for: selectedPreview)
            }
            if livePreviewInfo.state == .running || livePreviewInfo.state == .launching {
                await syncLiveFrameFromEngine(reason: "hot preview reload finished")
                await capturePreviewFrameIfNeeded(
                    reason: "hot preview reload finished",
                    preferFreshImage: true,
                    generation: generation
                )
            }
            handle(.frameRendered(makeFrame()))
            if preferredDisplayMode == .live,
               shouldRestorePreferredLiveMode,
               livePreviewInfo.state != .running,
               livePreviewInfo.state != .launching {
                await startLivePreviewSession(reason: "restoring preferred live mode after reload", generation: generation)
            }
            updatePhase = .idle
        } catch let error as LumiPreviewFacade.PreviewError {
            guard isCurrentFileGeneration(generation) else { return }
            await handleRefreshFailure(EditorPreviewFormatter.message(for: error))
        } catch {
            guard isCurrentFileGeneration(generation) else { return }
            await handleRefreshFailure(error.localizedDescription)
        }
    }

    private func stopSession(reason: String, generation: Int) async {
        scheduledRefreshTask?.cancel()
        scheduledRefreshTask = nil
        scheduledPrewarmTask?.cancel()
        scheduledPrewarmTask = nil
        scheduledPrewarmFingerprint = nil
        scheduledPrewarmPriority = nil
        scheduledPrewarmFingerprints = []
        liveCanvasService.cancelPendingFrameSync()
        pendingReloadReason = nil
        updatePhase = .idle
        guard let session = previewSession, let engine = previewEngine else {
            handle(.sessionStopped(reason: reason))
            return
        }

        if EditorRemoteHotPreviewPlugin.verbose {
                    EditorRemoteHotPreviewPlugin.logger.info("\(self.t)Stopping hot preview: \(reason, privacy: .public)")
        }
        try? await engine.stopLivePreview(session)
        await engine.stopPreview(session)
        guard !Task.isCancelled, isCurrentFileGeneration(generation) else { return }
        isLivePreviewShown = false
        handle(.sessionStopped(reason: reason))
        scheduleHostIdleShutdown(reason: reason)
    }

    private func handle(_ event: EditorRemoteHotPreviewEvent) {
        switch event {
        case let .frameRendered(frame):
            lastFrame = frame
            hostState = .connected
            lastFrameSummary = frame.summary
        case let .sessionStopped(reason):
            if EditorRemoteHotPreviewPlugin.verbose {
                            EditorRemoteHotPreviewPlugin.logger.info("\(self.t)Hot preview stopped: \(reason, privacy: .public)")
            }
            resetRenderState()
        case let .failed(message):
            if EditorRemoteHotPreviewPlugin.verbose {
                            EditorRemoteHotPreviewPlugin.logger.error("\(self.t)Hot preview failed: \(message, privacy: .public)")
            }
            clearRenderedFrameForPreviewChange()
            hostState = .failed
            failureMessage = message
            renderMessage = message
            isLiveLoading = false
            updatePhase = .idle
            lastFrameSummary = message
        }
        refreshDiagnosticSummary()
    }

    private var selectedPreview: LumiPreviewFacade.PreviewDiscovery? {
        if let selectedPreviewID,
           let selected = previews.first(where: { $0.id == selectedPreviewID }) {
            return selected
        }
        return previews.first
    }

    private func handleRefreshFailure(_ message: String) async {
        clearRenderedFrameForPreviewChange()
        handle(.failed(message: message))

        if preferredDisplayMode == .live,
           (livePreviewInfo.state == .running || livePreviewInfo.state == .launching) {
            await degradeLiveModeAfterRefreshFailure(message)
        }

        refreshDiagnosticSummary()
    }

    private func syncPreviewState(from session: LumiPreviewFacade.HotPreviewSession) async {
        if let response = await session.lastHotRenderResponse {
            applyRenderResponse(response)
        }

        performanceSummary = EditorPreviewFormatter.performanceSummary(for: await session.performanceMetrics)
        let startupTimings = await session.startupTimings
        startupTimingSummary = Self.startupTimingSummary(for: startupTimings)
        logStartupTimings(startupTimings)
        livePreviewInfo = await session.livePreviewInfo
        effectiveDisplayMode = resolvedEffectiveDisplayMode(
            preferredMode: preferredDisplayMode,
            liveInfo: livePreviewInfo,
            fallbackMode: await session.displayMode
        )

        switch await session.state {
        case .running:
            hostState = .connected
        case .failed(let error):
            clearRenderedFrameForPreviewChange()
            hostState = .failed
            failureMessage = EditorPreviewFormatter.message(for: error)
        case .planning, .compiling, .launching:
            hostState = .launching
        case .stopped:
            hostState = .idle
        }

        syncModeStatusMessage()
        refreshDiagnosticSummary()
    }

    private func applyRenderResponse(_ response: LumiPreviewFacade.HotRenderResponse) {
        let previousImage = renderImage
        if !response.success {
            clearRenderedFrameForPreviewChange()
            renderMessage = response.message
            failureMessage = response.message
            diagnostics = response.diagnostics
            transportSummary = response.preferredTransport.rawValue
            syncModeStatusMessage()
            refreshDiagnosticSummary()
            return
        }

        if let sharedMemoryTag = response.sharedMemoryTag,
           let frameWidth = response.frameSize?.width ?? response.frameWidth,
           let frameHeight = response.frameSize?.height ?? response.frameHeight,
           let bytesPerRow = response.bytesPerRow,
           let image = imageLoader.loadSharedMemoryImage(
                tag: sharedMemoryTag,
                width: frameWidth,
                height: frameHeight,
                bytesPerRow: bytesPerRow
           ) {
            renderImage = image
            transportSummary = "sharedMemory"
            isShowingStaleFrame = false
        } else if let imageFilePath = response.imageFilePath,
           let image = imageLoader.loadImage(at: URL(fileURLWithPath: imageFilePath)) {
            renderImage = image
            transportSummary = "file"
            isShowingStaleFrame = false
        } else if let base64 = response.previewImagePNGBase64,
                  let data = Data(base64Encoded: base64),
                  let image = NSImage(data: data) {
            renderImage = image
            transportSummary = "base64"
            isShowingStaleFrame = false
        } else {
            renderImage = previousImage
            transportSummary = response.preferredTransport.rawValue
            isShowingStaleFrame = previousImage != nil
        }

        renderMessage = response.message
        diagnostics = response.diagnostics
        syncModeStatusMessage()
        refreshDiagnosticSummary()
    }

    private func makeFrame() -> EditorRemoteHotPreviewFrame {
        let imageSize = renderImage?.size ?? CGSize(width: 900, height: 560)
        return EditorRemoteHotPreviewFrame(
            frameID: UInt64(Date().timeIntervalSince1970 * 1_000),
            size: imageSize,
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            renderedAt: Date()
        )
    }

    private func resetRenderState() {
        previewSession = nil
        lastFrame = nil
        renderImage = nil
        renderMessage = nil
        diagnostics = nil
        performanceSummary = nil
        transportSummary = "-"
        failureMessage = nil
        lastRenderedPreviewFingerprint = nil
        lastPrewarmedPreviewFingerprint = nil
        scheduledPrewarmFingerprint = nil
        scheduledPrewarmPriority = nil
        prewarmedPreviewFingerprints = []
        scheduledPrewarmFingerprints = []
        livePreviewInfo = LumiPreviewFacade.LivePreviewInfo()
        isLiveLoading = false
        isLivePreviewShown = false
        effectiveDisplayMode = .image
        updatePhase = .idle
        hostState = .idle
        isShowingStaleFrame = false
        modeStatusMessage = nil
        prewarmSummary = "prewarm: idle"
        prewarmCandidateSummary = "prewarm candidates: idle"
        startupTimingSummary = "startup: idle"
        hostLifecycleSummary = previewEngine == nil ? "host lifecycle: cold" : "host lifecycle: idle"
        lastFrameSummary = String(localized: "No Frame", table: "EditorPreview")
        refreshDiagnosticSummary()
    }

    private func clearPreviewForActiveFileChange() {
        commandTask?.cancel()
        commandTask = nil
        scheduledRefreshTask?.cancel()
        scheduledRefreshTask = nil
        scheduledPrewarmTask?.cancel()
        scheduledPrewarmTask = nil
        scheduledPrewarmFingerprint = nil
        scheduledPrewarmPriority = nil
        scheduledPrewarmFingerprints = []
        pendingReloadReason = nil
        liveCanvasService.cancelPendingFrameSync()

        let oldSession = previewSession
        let oldEngine = previewEngine
        previews = []
        selectedPreviewID = nil
        resetRenderState()

        guard let oldSession, let oldEngine else {
            return
        }

        Task { [weak self] in
            try? await oldEngine.stopLivePreview(oldSession)
            await oldEngine.stopPreview(oldSession)
            await MainActor.run {
                guard self?.previewSession == nil else { return }
                self?.scheduleHostIdleShutdown(reason: "active file changed")
            }
        }
    }

    private func clearPreviewForUnavailableSource() {
        commandTask?.cancel()
        commandTask = nil
        scheduledRefreshTask?.cancel()
        scheduledRefreshTask = nil
        scheduledPrewarmTask?.cancel()
        scheduledPrewarmTask = nil
        scheduledPrewarmFingerprint = nil
        scheduledPrewarmPriority = nil
        scheduledPrewarmFingerprints = []
        pendingReloadReason = nil
        liveCanvasService.cancelPendingFrameSync()
        teardownPreviewSessionForExternalModeChange()
        resetRenderState()
    }

    private func teardownPreviewSessionForExternalModeChange() {
        guard let session = previewSession, let engine = previewEngine else {
            previewSession = nil
            scheduleHostIdleShutdown(reason: "no active preview session")
            return
        }

        previewSession = nil
        Task { [weak self] in
            try? await engine.stopLivePreview(session)
            await engine.stopPreview(session)
            await MainActor.run {
                self?.scheduleHostIdleShutdown(reason: "preview session became unavailable")
            }
        }
    }

    private func resolvedEffectiveDisplayMode(
        preferredMode: LumiPreviewFacade.PreviewDisplayMode,
        liveInfo: LumiPreviewFacade.LivePreviewInfo,
        fallbackMode: LumiPreviewFacade.PreviewDisplayMode
    ) -> LumiPreviewFacade.PreviewDisplayMode {
        guard preferredMode == .live else {
            return fallbackMode
        }

        switch liveInfo.state {
        case .available, .launching, .running, .failed:
            return .live
        case .stopped, .unavailable:
            return .image
        }
    }

    private func warmupHostIfPossible() {
        guard let hostExecutableURL = LumiPreviewFacade.HotPreviewHostExecutableResolver.resolve() else {
            hostLifecycleSummary = "host lifecycle: cold"
            return
        }

        scheduledHostIdleShutdownTask?.cancel()
        scheduledHostIdleShutdownTask = nil
        if previewEngine == nil {
            previewEngine = LumiPreviewFacade.HotPreviewEngine(hostExecutableURL: hostExecutableURL)
        }
        hostLifecycleSummary = "host lifecycle: warming"
        refreshDiagnosticSummary()

        Task { [weak self] in
            _ = LumiPreviewFacade.ImageFileLoader.removeExpiredFrames()
            _ = LumiPreviewFacade.SharedMemoryFrameChannel.removeExpiredFrames()
            do {
                try await self?.previewEngine?.warmupHost()
                await MainActor.run {
                    self?.hostLifecycleSummary = "host lifecycle: idle"
                    self?.refreshDiagnosticSummary()
                }
            } catch {
                if EditorRemoteHotPreviewPlugin.verbose {
                                    EditorRemoteHotPreviewPlugin.logger.debug(
                                        "\(Self.t)Hot preview warmup skipped: \(error.localizedDescription, privacy: .public)"
                                    )
                }
                await MainActor.run {
                    self?.hostLifecycleSummary = "host lifecycle: cold"
                    self?.refreshDiagnosticSummary()
                }
            }
        }
    }

    private func scheduleHostIdleShutdown(reason: String) {
        scheduledHostIdleShutdownTask?.cancel()
        guard previewSession == nil, let engine = previewEngine else {
            return
        }

        hostLifecycleSummary = "host lifecycle: idle"
        refreshDiagnosticSummary()
        scheduledHostIdleShutdownTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.hostIdleShutdownDelay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await engine.shutdownHosts()
            await MainActor.run {
                guard self?.previewSession == nil else { return }
                self?.previewEngine = nil
                self?.hostLifecycleSummary = "host lifecycle: recycled"
                self?.scheduledHostIdleShutdownTask = nil
                self?.refreshDiagnosticSummary()
                if EditorRemoteHotPreviewPlugin.verbose {
                                    EditorRemoteHotPreviewPlugin.logger.info(
                                        "\(Self.t)Recycled idle hot preview host after \(reason, privacy: .public)"
                                    )
                }
            }
        }
    }

    private func schedulePrewarm(for preview: LumiPreviewFacade.PreviewDiscovery, reason: String) {
        schedulePrewarmBatch(for: [preview], reason: reason, priority: .currentFile)
    }

    private func scheduleCurrentFilePrewarm(preferredPreviewID: String?, previews: [LumiPreviewFacade.PreviewDiscovery]) {
        guard previewSession == nil else { return }
        let orderedPreviews = orderedPrewarmPreviews(preferredPreviewID: preferredPreviewID, previews: previews)
        prewarmCandidateSummary = "prewarm candidates: current file"
        schedulePrewarmBatch(
            for: Array(orderedPreviews.prefix(Self.maxBackgroundPrewarmCount)),
            reason: "current file preview candidates",
            priority: .currentFile
        )
    }

    private func schedulePrewarmBatch(
        for previews: [LumiPreviewFacade.PreviewDiscovery],
        reason: String,
        priority: PrewarmPriority
    ) {
        guard previewSession == nil else { return }
        if let scheduledPrewarmTask,
           scheduledPrewarmTask.isCancelled == false,
           let scheduledPrewarmPriority,
           scheduledPrewarmPriority.rawValue > priority.rawValue {
            return
        }

        let candidates = previews
            .map { (preview: $0, fingerprint: previewFingerprint(for: $0)) }
            .filter { candidate in
                candidate.fingerprint != lastPrewarmedPreviewFingerprint &&
                !prewarmedPreviewFingerprints.contains(candidate.fingerprint) &&
                candidate.fingerprint != scheduledPrewarmFingerprint &&
                !scheduledPrewarmFingerprints.contains(candidate.fingerprint) &&
                !failedPrewarmFingerprints.contains(candidate.fingerprint)
            }

        guard !candidates.isEmpty else { return }

        scheduledPrewarmTask?.cancel()
        let fingerprints = Set(candidates.map(\.fingerprint))
        scheduledPrewarmFingerprint = candidates.first?.fingerprint
        scheduledPrewarmPriority = priority
        scheduledPrewarmFingerprints = fingerprints
        prewarmSummary = candidates.count == 1 ? "prewarm: queued" : "prewarm: queued \(candidates.count)"
        refreshDiagnosticSummary()

        scheduledPrewarmTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            guard await self?.waitForPrewarmOpportunity() == true else {
                self?.finishScheduledPrewarmBatch()
                return
            }
            await self?.prewarmBatch(candidates: candidates, reason: reason)
            self?.finishScheduledPrewarmBatch()
        }
    }

    private func scheduleIndexedPrewarmCandidate() {
        guard previewSession == nil else { return }
        let previews = projectPreviewIndexService.prewarmCandidates(
            preferredFileURL: activeFileURL,
            limit: Self.maxBackgroundPrewarmCount * 3
        )
        guard !previews.isEmpty else {
            return
        }
        let orderedPreviews = orderedProjectPrewarmPreviews(previews)
        prewarmCandidateSummary = projectPrewarmCandidateSummary(for: orderedPreviews)
        schedulePrewarmBatch(
            for: Array(orderedPreviews.prefix(Self.maxBackgroundPrewarmCount)),
            reason: "project preview index candidates",
            priority: .indexedProject
        )
    }

    private func orderedPrewarmPreviews(
        preferredPreviewID: String?,
        previews: [LumiPreviewFacade.PreviewDiscovery]
    ) -> [LumiPreviewFacade.PreviewDiscovery] {
        guard let preferredPreviewID,
              let preferred = previews.first(where: { $0.id == preferredPreviewID }) else {
            return previews
        }
        return [preferred] + previews.filter { $0.id != preferredPreviewID }
    }

    private func orderedProjectPrewarmPreviews(
        _ previews: [LumiPreviewFacade.PreviewDiscovery]
    ) -> [LumiPreviewFacade.PreviewDiscovery] {
        scoredProjectPrewarmPreviews(previews).map(\.preview)
    }

    private func scoredProjectPrewarmPreviews(
        _ previews: [LumiPreviewFacade.PreviewDiscovery]
    ) -> [LumiPreviewFacade.ProjectPreviewPrewarmRanker.RankedPreview] {
        LumiPreviewFacade.ProjectPreviewPrewarmRanker().rank(
            previews,
            context: LumiPreviewFacade.ProjectPreviewPrewarmRanker.Context(
                activeFileURL: activeFileURL,
                recentFilePaths: recentPreviewFilePaths,
                successfulFilePaths: successfulPreviewFilePaths,
                previewStartCountsByFilePath: previewStartCountsByFilePath
            )
        )
    }

    private func projectPrewarmCandidateSummary(
        for previews: [LumiPreviewFacade.PreviewDiscovery]
    ) -> String {
        let scored = scoredProjectPrewarmPreviews(Array(previews.prefix(Self.maxBackgroundPrewarmCount)))
        guard !scored.isEmpty else {
            return "prewarm candidates: none"
        }

        let parts = scored.prefix(Self.maxBackgroundPrewarmCount).map { candidate in
            let fileName = candidate.preview.sourceFileURL.lastPathComponent
            let reasons = candidate.reasons.joined(separator: "+")
            return "\(fileName) score:\(candidate.score) \(reasons)"
        }
        return "prewarm candidates: " + parts.joined(separator: ", ")
    }

    private func touchRecentPreviewFile(_ fileURL: URL) {
        let path = fileURL.standardizedFileURL.path
        recentPreviewFilePaths.removeAll { $0 == path }
        recentPreviewFilePaths.insert(path, at: 0)
        if recentPreviewFilePaths.count > 12 {
            recentPreviewFilePaths.removeLast(recentPreviewFilePaths.count - 12)
        }
        persistProjectPreviewHistory()
    }

    private func recordSuccessfulPreviewFile(_ fileURL: URL) {
        let path = fileURL.standardizedFileURL.path
        successfulPreviewFilePaths.removeAll { $0 == path }
        successfulPreviewFilePaths.insert(path, at: 0)
        if successfulPreviewFilePaths.count > 12 {
            successfulPreviewFilePaths.removeLast(successfulPreviewFilePaths.count - 12)
        }
        persistProjectPreviewHistory()
    }

    private func incrementPreviewStartCount(for fileURL: URL) {
        let path = fileURL.standardizedFileURL.path
        previewStartCountsByFilePath[path, default: 0] += 1
        persistProjectPreviewHistory()
    }

    private func recordPrewarmFailure(fingerprint: String) {
        failedPrewarmFingerprints.insert(fingerprint)
        persistProjectPreviewHistory()
    }

    private func clearPrewarmFailure(fingerprint: String) {
        guard failedPrewarmFingerprints.remove(fingerprint) != nil else { return }
        persistProjectPreviewHistory()
    }

    private func updateProjectHistoryContext(projectRootPath: String?, fileURL: URL?) {
        let nextKey: String?
        if let projectRootPath, !projectRootPath.isEmpty {
            nextKey = URL(fileURLWithPath: projectRootPath, isDirectory: true).standardizedFileURL.path
        } else {
            nextKey = fileURL?.deletingLastPathComponent().standardizedFileURL.path
        }

        guard activeProjectHistoryKey != nextKey else {
            return
        }

        persistProjectPreviewHistory()
        activeProjectHistoryKey = nextKey
        loadProjectPreviewHistory()
    }

    private func loadProjectPreviewHistory() {
        guard let activeProjectHistoryKey else {
            recentPreviewFilePaths = []
            successfulPreviewFilePaths = []
            previewStartCountsByFilePath = [:]
            failedPrewarmFingerprints = []
            return
        }

        let storage = Self.loadProjectPreviewHistoryStorage()
        let history = storage[activeProjectHistoryKey] ?? ProjectPreviewHistory()
        recentPreviewFilePaths = history.recentFilePaths
        successfulPreviewFilePaths = history.successfulFilePaths
        previewStartCountsByFilePath = history.previewStartCountsByFilePath
        failedPrewarmFingerprints = Set(history.failedPrewarmFingerprints)
    }

    private func persistProjectPreviewHistory() {
        guard let activeProjectHistoryKey else { return }

        var storage = Self.loadProjectPreviewHistoryStorage()
        storage[activeProjectHistoryKey] = ProjectPreviewHistory(
            recentFilePaths: Array(recentPreviewFilePaths.prefix(12)),
            successfulFilePaths: Array(successfulPreviewFilePaths.prefix(12)),
            previewStartCountsByFilePath: previewStartCountsByFilePath,
            failedPrewarmFingerprints: Array(failedPrewarmFingerprints.prefix(64))
        )
        Self.saveProjectPreviewHistoryStorage(storage)
    }

    private static func loadProjectPreviewHistoryStorage() -> [String: ProjectPreviewHistory] {
        let fileURL = EditorPreviewStorage.projectPreviewHistoryURL
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([String: ProjectPreviewHistory].self, from: data) {
            return decoded
        }

        guard let legacyData = UserDefaults.standard.data(forKey: previewHistoryStorageKey),
              let legacy = try? JSONDecoder().decode([String: ProjectPreviewHistory].self, from: legacyData) else {
            return [:]
        }

        saveProjectPreviewHistoryStorage(legacy)
        UserDefaults.standard.removeObject(forKey: previewHistoryStorageKey)
        return legacy
    }

    private static func saveProjectPreviewHistoryStorage(_ storage: [String: ProjectPreviewHistory]) {
        guard let data = try? JSONEncoder().encode(storage) else { return }
        let fileURL = EditorPreviewStorage.projectPreviewHistoryURL
        try? data.write(to: fileURL, options: .atomic)
    }

    private func waitForPrewarmOpportunity() async -> Bool {
        let startedAt = Date()
        while !Task.isCancelled {
            let decision = prewarmResourceDecision()
            prewarmResourceSummary = decision.summary
            refreshDiagnosticSummary()

            switch decision.action {
            case .run:
                return true
            case .skip:
                return false
            case .defer:
                guard Date().timeIntervalSince(startedAt) < Self.maximumPrewarmResourceDeferral else {
                    prewarmResourceSummary = "prewarm resources: deferred"
                    refreshDiagnosticSummary()
                    return false
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
        return false
    }

    private func prewarmResourceDecision() -> PrewarmResourceDecision {
        let processInfo = ProcessInfo.processInfo
        if processInfo.isLowPowerModeEnabled {
            return PrewarmResourceDecision(action: .skip, summary: "prewarm resources: low power")
        }

        switch processInfo.thermalState {
        case .serious, .critical:
            return PrewarmResourceDecision(action: .skip, summary: "prewarm resources: thermal \(thermalStateDescription(processInfo.thermalState))")
        case .fair:
            return PrewarmResourceDecision(action: .defer, summary: "prewarm resources: thermal fair")
        case .nominal:
            break
        @unknown default:
            break
        }

        if let lastSourceUpdateAt {
            let idleDuration = Date().timeIntervalSince(lastSourceUpdateAt)
            if idleDuration < Self.minimumEditorIdleIntervalBeforePrewarm {
                return PrewarmResourceDecision(action: .defer, summary: "prewarm resources: editing")
            }
        }

        return PrewarmResourceDecision(action: .run, summary: "prewarm resources: ready")
    }

    private func thermalStateDescription(_ thermalState: ProcessInfo.ThermalState) -> String {
        switch thermalState {
        case .nominal:
            return "nominal"
        case .fair:
            return "fair"
        case .serious:
            return "serious"
        case .critical:
            return "critical"
        @unknown default:
            return "unknown"
        }
    }

    private func prewarm(
        preview: LumiPreviewFacade.PreviewDiscovery,
        fingerprint: String,
        reason: String
    ) async {
        await prewarmBatch(candidates: [(preview: preview, fingerprint: fingerprint)], reason: reason)
    }

    private func prewarmBatch(
        candidates: [(preview: LumiPreviewFacade.PreviewDiscovery, fingerprint: String)],
        reason: String
    ) async {
        guard previewSession == nil, !candidates.isEmpty else { return }
        guard prewarmResourceDecision().action == .run else { return }
        let startedAt = Date()
        prewarmAttemptCount += candidates.count
        refreshPrewarmStatsSummary()
        guard let hostExecutableURL = LumiPreviewFacade.HotPreviewHostExecutableResolver.resolve() else {
            prewarmSummary = "prewarm: host missing"
            for _ in candidates {
                recordPrewarmResult(success: false, duration: Date().timeIntervalSince(startedAt))
            }
            scheduledPrewarmFingerprint = nil
            scheduledPrewarmPriority = nil
            candidates.forEach { scheduledPrewarmFingerprints.remove($0.fingerprint) }
            refreshDiagnosticSummary()
            return
        }

        let engine = previewEngine ?? LumiPreviewFacade.HotPreviewEngine(hostExecutableURL: hostExecutableURL)
        previewEngine = engine
        prewarmSummary = candidates.count == 1 ? "prewarm: building" : "prewarm: building \(candidates.count)"
        refreshDiagnosticSummary()

        let results = await engine.prewarmPreviewEntries(candidates.map(\.preview))
        guard !Task.isCancelled else { return }

        let duration = Date().timeIntervalSince(startedAt)
        let fingerprintByID = Dictionary(uniqueKeysWithValues: candidates.map { ($0.preview.id, $0.fingerprint) })
        var successfulCount = 0
        var failedCount = 0
        var cachedCount = 0
        for result in results {
            if result.succeeded {
                successfulCount += 1
                if result.usedCachedEntry {
                    cachedCount += 1
                }
                if let fingerprint = fingerprintByID[result.discoveryID] {
                    lastPrewarmedPreviewFingerprint = fingerprint
                    prewarmedPreviewFingerprints.insert(fingerprint)
                    clearPrewarmFailure(fingerprint: fingerprint)
                }
                if let preview = candidates.first(where: { $0.preview.id == result.discoveryID })?.preview {
                    recordSuccessfulPreviewFile(preview.sourceFileURL)
                }
                recordPrewarmResult(
                    success: true,
                    usedCachedEntry: result.usedCachedEntry,
                    duration: duration / Double(max(results.count, 1))
                )
            } else {
                failedCount += 1
                recordPrewarmResult(
                    success: false,
                    usedCachedEntry: false,
                    duration: duration / Double(max(results.count, 1))
                )
                if let fingerprint = fingerprintByID[result.discoveryID] {
                    recordPrewarmFailure(fingerprint: fingerprint)
                }
                if let errorDescription = result.errorDescription {
                    if EditorRemoteHotPreviewPlugin.verbose {
                                            EditorRemoteHotPreviewPlugin.logger.debug(
                                                "\(self.t)Hot preview prewarm failed: \(errorDescription, privacy: .public)"
                                            )
                    }
                }
            }
        }

        for candidate in candidates {
            scheduledPrewarmFingerprints.remove(candidate.fingerprint)
        }
        scheduledPrewarmFingerprint = scheduledPrewarmFingerprints.first
        if scheduledPrewarmFingerprints.isEmpty {
            scheduledPrewarmTask = nil
            scheduledPrewarmPriority = nil
        }
        if failedCount == 0 {
            prewarmSummary = cachedCount > 0 ? "prewarm: ready cached \(cachedCount)/\(results.count)" : "prewarm: ready"
        } else if successfulCount == 0 {
            prewarmSummary = "prewarm: failed"
        } else {
            prewarmSummary = "prewarm: partial \(successfulCount)/\(results.count)"
        }
        if EditorRemoteHotPreviewPlugin.verbose {
                    EditorRemoteHotPreviewPlugin.logger.info(
                        "\(self.t)Prewarmed hot preview entries: \(successfulCount, privacy: .public)/\(results.count, privacy: .public), cached \(cachedCount, privacy: .public) \(reason, privacy: .public)"
                    )
        }
        refreshDiagnosticSummary()
    }

    private func recordPrewarmResult(success: Bool, usedCachedEntry: Bool = false, duration: TimeInterval) {
        if success {
            prewarmSuccessCount += 1
            if usedCachedEntry {
                prewarmCachedEntryCount += 1
            }
            totalSuccessfulPrewarmDuration += duration
        } else {
            prewarmFailureCount += 1
        }
        refreshPrewarmStatsSummary()
    }

    private func recordPreviewStart(fingerprint: String, fileURL: URL) {
        previewStartCount += 1
        incrementPreviewStartCount(for: fileURL)
        if prewarmedPreviewFingerprints.contains(fingerprint) {
            prewarmHitCount += 1
        }
        refreshPrewarmStatsSummary()
    }

    private func refreshPrewarmStatsSummary() {
        let averageDuration: TimeInterval
        if prewarmSuccessCount > 0 {
            averageDuration = totalSuccessfulPrewarmDuration / Double(prewarmSuccessCount)
        } else {
            averageDuration = 0
        }
        prewarmStatsSummary = String(
            format: "prewarm stats: %d/%d ok, %d cached, %d failed, %d hits/%d starts, %.2fs avg",
            prewarmSuccessCount,
            prewarmAttemptCount,
            prewarmCachedEntryCount,
            prewarmFailureCount,
            prewarmHitCount,
            previewStartCount,
            averageDuration
        )
    }

    private static func startupTimingSummary(
        for timings: [LumiPreviewFacade.HotPreviewStartupTiming]
    ) -> String {
        guard !timings.isEmpty else {
            return "startup: idle"
        }

        let parts = timings.map { timing in
            let detail = timing.detail.map { " \($0)" } ?? ""
            return "\(timing.stage) \(formatTimingDuration(timing.duration))\(detail)"
        }
        return "startup: " + parts.joined(separator: ", ") + startupBottleneckSummary(for: timings)
    }

    private static func startupBottleneckSummary(
        for timings: [LumiPreviewFacade.HotPreviewStartupTiming]
    ) -> String {
        let measuredTimings = timings.filter { timing in
            !timing.stage.hasPrefix("total ") && timing.duration > 0
        }
        guard let slowest = measuredTimings.max(by: { $0.duration < $1.duration }) else {
            return " | bottleneck: none"
        }

        let totalDuration = timings
            .filter { $0.stage.hasPrefix("total ") }
            .map(\.duration)
            .max() ?? measuredTimings.reduce(0) { $0 + $1.duration }
        let percentage = totalDuration > 0 ? Int(((slowest.duration / totalDuration) * 100).rounded()) : 0
        return " | bottleneck: \(bottleneckCategory(for: slowest.stage)) \(formatTimingDuration(slowest.duration)) \(percentage)%"
    }

    private static func bottleneckCategory(for stage: String) -> String {
        switch stage {
        case "syntax preflight":
            return "syntax"
        case "build planning", "build":
            return "build"
        case "entry cache lookup", "entry generation":
            return "entry"
        case "host acquire":
            return "host startup"
        case "host entry load":
            return "host load"
        case "live start", "live window sync":
            return "live sync"
        default:
            return stage
        }
    }

    private static func formatTimingDuration(_ duration: TimeInterval) -> String {
        if duration < 0.001 {
            return "0ms"
        }
        if duration < 1 {
            return "\(Int((duration * 1_000).rounded()))ms"
        }
        return String(format: "%.2fs", duration)
    }

    private func logStartupTimings(_ timings: [LumiPreviewFacade.HotPreviewStartupTiming]) {
        guard !timings.isEmpty else { return }
        let timingSummary = Self.startupTimingSummary(for: timings)
        let previewID = selectedPreview?.id ?? "-"
        let filePath = activeFileURL?.path ?? "-"
        if EditorRemoteHotPreviewPlugin.verbose {
                    EditorRemoteHotPreviewPlugin.logger.info(
                        "\(self.t)Hot preview startup timings preview=\(previewID, privacy: .public) file=\(filePath, privacy: .public) \(timingSummary, privacy: .public)"
                    )
        }
    }

    private func finishScheduledPrewarmBatch() {
        scheduledPrewarmFingerprint = nil
        scheduledPrewarmPriority = nil
        scheduledPrewarmFingerprints = []
        scheduledPrewarmTask = nil
        refreshDiagnosticSummary()
    }

    private var needsReload: Bool {
        guard let selectedPreview else {
            return false
        }
        return previewFingerprint(for: selectedPreview) != lastRenderedPreviewFingerprint
    }

    private func isCurrentFileGeneration(_ generation: Int) -> Bool {
        generation == activeFileGeneration
    }

    private static func sameFile(_ lhs: URL?, _ rhs: URL?) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case let (.some(lhs), .some(rhs)):
            return lhs.standardizedFileURL.path == rhs.standardizedFileURL.path
        default:
            return false
        }
    }

    private func previewFingerprint(for preview: LumiPreviewFacade.PreviewDiscovery) -> String {
        [
            preview.id,
            preview.title,
            preview.primaryTypeName ?? "",
            "\(preview.lineNumber)",
            "\(preview.endLineNumber)",
            preview.bodySource ?? ""
        ].joined(separator: "\u{1F}")
    }

    private func startLivePreviewSession(reason: String, generation: Int? = nil) async {
        let generation = generation ?? activeFileGeneration
        guard isCurrentFileGeneration(generation) else { return }
        guard let session = previewSession, let engine = previewEngine else { return }
        if EditorRemoteHotPreviewPlugin.verbose {
                    EditorRemoteHotPreviewPlugin.logger.info("\(self.t)Starting hot live preview: \(reason, privacy: .public)")
        }
        effectiveDisplayMode = .live
        isLiveLoading = true
        livePreviewInfo = LumiPreviewFacade.LivePreviewInfo(state: .launching)
        modeStatusMessage = String(localized: "Starting live preview.", table: "EditorPreview")
        refreshDiagnosticSummary()

        do {
            try await engine.startLivePreview(session)
            guard isCurrentFileGeneration(generation) else { return }
            isLivePreviewShown = false
            await syncLiveFrameFromEngine(reason: "hot live preview started")
            await showLivePreviewIfNeeded(reason: "hot live preview started")
            await capturePreviewFrameIfNeeded(reason: "hot live preview started", generation: generation)
            await syncPreviewState(from: session)
            isLiveLoading = false
            syncModeStatusMessage()
            refreshDiagnosticSummary()
        } catch let error as LumiPreviewFacade.PreviewError {
            guard isCurrentFileGeneration(generation) else { return }
            livePreviewInfo = LumiPreviewFacade.LivePreviewInfo(
                state: .failed,
                unavailableReason: EditorPreviewFormatter.message(for: error)
            )
            effectiveDisplayMode = .image
            shouldRestorePreferredLiveMode = false
            isLiveLoading = false
            syncModeStatusMessage()
            refreshDiagnosticSummary()
        } catch {
            guard isCurrentFileGeneration(generation) else { return }
            livePreviewInfo = LumiPreviewFacade.LivePreviewInfo(
                state: .failed,
                unavailableReason: error.localizedDescription
            )
            effectiveDisplayMode = .image
            shouldRestorePreferredLiveMode = false
            isLiveLoading = false
            syncModeStatusMessage()
            refreshDiagnosticSummary()
        }
    }

    private func stopLivePreviewSession(reason: String) async {
        guard let session = previewSession, let engine = previewEngine else { return }
        if EditorRemoteHotPreviewPlugin.verbose {
                    EditorRemoteHotPreviewPlugin.logger.info("\(self.t)Stopping hot live preview: \(reason, privacy: .public)")
        }
        do {
            try await engine.stopLivePreview(session)
            isLivePreviewShown = false
            effectiveDisplayMode = .image
            await syncPreviewState(from: session)
        } catch let error as LumiPreviewFacade.PreviewError {
            livePreviewInfo = LumiPreviewFacade.LivePreviewInfo(
                state: .failed,
                unavailableReason: EditorPreviewFormatter.message(for: error)
            )
            effectiveDisplayMode = .image
            syncModeStatusMessage()
        } catch {
            livePreviewInfo = LumiPreviewFacade.LivePreviewInfo(
                state: .failed,
                unavailableReason: error.localizedDescription
            )
            effectiveDisplayMode = .image
            syncModeStatusMessage()
        }
        refreshDiagnosticSummary()
    }

    private func restoreLivePreviewIfNeeded(reason: String) async {
        guard isDetailViewVisible,
              isPreviewWindowVisible,
              preferredDisplayMode == .live,
              shouldRestorePreferredLiveMode,
              let session = previewSession,
              previewEngine != nil else {
            return
        }

        switch livePreviewInfo.state {
        case .available, .stopped:
            if EditorRemoteHotPreviewPlugin.verbose {
                            EditorRemoteHotPreviewPlugin.logger.info(
                                "\(self.t)Restoring hot live preview: \(reason, privacy: .public)"
                            )
            }
            await syncLiveFrameFromEngine(reason: reason)
            await showLivePreviewIfNeeded(reason: reason)
            await capturePreviewFrameIfNeeded(reason: reason)
            await syncPreviewState(from: session)
        case .running, .launching:
            await syncLiveFrameFromEngine(reason: reason)
            await showLivePreviewIfNeeded(reason: reason)
            await capturePreviewFrameIfNeeded(reason: reason)
            await syncPreviewState(from: session)
        case .failed, .unavailable:
            break
        }
    }

    private func hideLivePreviewIfNeeded(reason: String) async {
        guard let session = previewSession,
              let engine = previewEngine,
              livePreviewInfo.state == .running || livePreviewInfo.state == .launching || isLivePreviewShown else {
            return
        }

        if EditorRemoteHotPreviewPlugin.verbose {
                    EditorRemoteHotPreviewPlugin.logger.info("\(self.t)Hiding hot live preview: \(reason, privacy: .public)")
        }
        do {
            try await engine.hideLivePreview(session)
            isLivePreviewShown = false
            await syncPreviewState(from: session)
        } catch {
            if EditorRemoteHotPreviewPlugin.verbose {
                            EditorRemoteHotPreviewPlugin.logger.debug(
                                "\(self.t)Failed to hide hot live preview: \(error.localizedDescription, privacy: .public)"
                            )
            }
        }
        refreshDiagnosticSummary()
    }

    private func bindLiveCanvasService() {
        liveCanvasService.onSyncLiveFrameFromEngine = { [weak self] reason in
            await self?.syncLiveFrameFromEngine(reason: reason)
        }
        liveCanvasService.onShowLivePreview = { [weak self] reason in
            await self?.showLivePreviewIfNeeded(reason: reason)
        }
        liveCanvasService.onHideLivePreview = { [weak self] reason in
            await self?.hideLivePreviewIfNeeded(reason: reason)
        }
    }

    private func showLivePreviewIfNeeded(reason: String, forceOrderFront: Bool = false) async {
        guard isDetailViewVisible,
              isPreviewWindowVisible,
              NSApp.isActive,
              preferredDisplayMode == .live,
              shouldRestorePreferredLiveMode,
              liveCanvasService.canSyncFrame,
              let session = previewSession,
              let engine = previewEngine else {
            return
        }
        guard forceOrderFront || !isLivePreviewShown else {
            if EditorRemoteHotPreviewPlugin.verbose {
                            EditorRemoteHotPreviewPlugin.logger.debug(
                                "\(self.t)Skipping hot live preview show because it is already shown: \(reason, privacy: .public)"
                            )
            }
            return
        }

        if EditorRemoteHotPreviewPlugin.verbose {
                    EditorRemoteHotPreviewPlugin.logger.info("\(self.t)Showing hot live preview: \(reason, privacy: .public)")
        }
        do {
            try await engine.showLivePreview(session)
            isLivePreviewShown = true
            await syncPreviewState(from: session)
        } catch {
            if EditorRemoteHotPreviewPlugin.verbose {
                            EditorRemoteHotPreviewPlugin.logger.debug(
                                "\(self.t)Failed to show hot live preview: \(error.localizedDescription, privacy: .public)"
                            )
            }
        }
    }

    private func bindProjectPreviewIndexService() {
        projectPreviewIndexService.onSnapshotChanged = { [weak self] snapshot in
            guard let self else { return }
            if let snapshot {
                projectPreviewIndexSummary = "index: \(snapshot.previewCount) previews / \(snapshot.scannedFileCount) files"
            } else {
                projectPreviewIndexSummary = "index: idle"
            }
            refreshDiagnosticSummary()
            if snapshot != nil {
                scheduleIndexedPrewarmCandidate()
            }
        }
    }

    private func syncLiveFrameFromEngine(reason: String) async {
        guard liveCanvasService.canSyncFrame,
              preferredDisplayMode == .live,
              let session = previewSession,
              let engine = previewEngine else {
            return
        }

        let rect = liveCanvasService.canvasRect
        if EditorRemoteHotPreviewPlugin.verbose {
                    EditorRemoteHotPreviewPlugin.logger.info("\(self.t)Syncing hot live preview frame: \(reason, privacy: .public)")
        }

        do {
            try await engine.updateLiveFrame(
                session,
                x: Double(rect.origin.x),
                y: Double(rect.origin.y),
                width: Double(rect.width),
                height: Double(rect.height),
                scale: Double(liveCanvasService.canvasScale)
            )
        } catch {
            if EditorRemoteHotPreviewPlugin.verbose {
                            EditorRemoteHotPreviewPlugin.logger.debug(
                                "\(self.t)Failed to sync hot live preview frame: \(error.localizedDescription, privacy: .public)"
                            )
            }
        }

        refreshDiagnosticSummary()
    }

    private func restoreOrStartLivePreviewAfterModeSwitch() async {
        if previewSession == nil {
            start(reason: "switched display mode to live")
            return
        }

        switch livePreviewInfo.state {
        case .running, .launching, .available, .stopped:
            await restoreLivePreviewIfNeeded(reason: "switched display mode to live")
        case .failed, .unavailable:
            await startLivePreviewSession(reason: "switched display mode to live")
        }
    }

    private func switchToImageMode() async {
        if renderImage == nil,
           let session = previewSession,
           let engine = previewEngine {
            do {
                let response = try await engine.capturePreviewFrame(session)
                applyRenderResponse(response)
            } catch {
                if EditorRemoteHotPreviewPlugin.verbose {
                                    EditorRemoteHotPreviewPlugin.logger.debug(
                                        "\(self.t)Failed to capture fallback image while switching to image mode: \(error.localizedDescription, privacy: .public)"
                                    )
                }
            }
        }

        effectiveDisplayMode = .image
        await hideLivePreviewIfNeeded(reason: "switched display mode to image")
        syncModeStatusMessage()
        refreshDiagnosticSummary()
    }

    private func capturePreviewFrameIfNeeded(
        reason: String,
        preferFreshImage: Bool = false,
        generation: Int? = nil
    ) async {
        let generation = generation ?? activeFileGeneration
        guard isCurrentFileGeneration(generation) else { return }
        guard let session = previewSession,
              let engine = previewEngine else {
            return
        }

        if !preferFreshImage, renderImage != nil {
            return
        }

        if EditorRemoteHotPreviewPlugin.verbose {
                    EditorRemoteHotPreviewPlugin.logger.debug(
                        "\(self.t)Capturing hot preview frame: \(reason, privacy: .public)"
                    )
        }

        do {
            let response = try await engine.capturePreviewFrame(session)
            guard isCurrentFileGeneration(generation) else { return }
            applyRenderResponse(response)
        } catch {
            if EditorRemoteHotPreviewPlugin.verbose {
                            EditorRemoteHotPreviewPlugin.logger.debug(
                                "\(self.t)Failed to capture hot preview frame: \(error.localizedDescription, privacy: .public)"
                            )
            }
        }
    }

    private func degradeLiveModeAfterRefreshFailure(_ message: String) async {
        guard let session = previewSession,
              let engine = previewEngine else {
            return
        }

        do {
            try await engine.stopLivePreview(session)
            isLivePreviewShown = false
        } catch {
            if EditorRemoteHotPreviewPlugin.verbose {
                            EditorRemoteHotPreviewPlugin.logger.debug(
                                "\(self.t)Failed to stop hot live preview after refresh failure: \(error.localizedDescription, privacy: .public)"
                            )
            }
        }

        effectiveDisplayMode = .image
        shouldRestorePreferredLiveMode = false
        livePreviewInfo = LumiPreviewFacade.LivePreviewInfo(
            state: .failed,
            unavailableReason: message
        )
        syncModeStatusMessage()
        refreshDiagnosticSummary()
    }

    private func preserveCurrentFrameForRestart(message: String) {
        guard renderImage != nil else { return }
        isShowingStaleFrame = true
        modeStatusMessage = message
    }

    private func isSelectedPreviewAlreadyRendered(_ preview: LumiPreviewFacade.PreviewDiscovery) -> Bool {
        previewFingerprint(for: preview) == lastRenderedPreviewFingerprint
    }

    private func clearRenderedFrameForPreviewChange() {
        renderImage = nil
        lastFrame = nil
        transportSummary = "-"
        isShowingStaleFrame = false
        modeStatusMessage = nil
    }

    private func makePreviewEngine(hostExecutableURL: URL) -> LumiPreviewFacade.HotPreviewEngine {
        let xcodeCompiler = LumiPreviewFacade.XcodeCompiler(
            derivedDataPath: EditorPreviewStorage.derivedDataDirectory
        )
        let previewEntryBuilder = LumiPreviewFacade.PreviewEntryBuilder(
            xcodeCompiler: xcodeCompiler
        )
        let incrementalBuildPipeline = LumiPreviewFacade.IncrementalBuildPipeline(
            xcodeCompiler: xcodeCompiler
        )

        return LumiPreviewFacade.HotPreviewEngine(
            hostExecutableURL: hostExecutableURL,
            xcodeCompiler: xcodeCompiler,
            previewEntryBuilder: previewEntryBuilder,
            incrementalBuildPipeline: incrementalBuildPipeline
        )
    }

    private func syncModeStatusMessage() {
        if livePreviewInfo.state == .failed,
           let reason = livePreviewInfo.unavailableReason,
           !reason.isEmpty {
            modeStatusMessage = reason
            return
        }

        if isLiveLoading {
            modeStatusMessage = String(localized: "Starting live preview.", table: "EditorPreview")
            return
        }

        if preferredDisplayMode == .live && effectiveDisplayMode == .image {
            modeStatusMessage = String(localized: "Live mode is preferred, but the host is currently showing image preview.", table: "EditorPreview")
            return
        }

        if isShowingStaleFrame {
            modeStatusMessage = String(localized: "Showing the previous frame because no fresh frame is available yet.", table: "EditorPreview")
            return
        }

        modeStatusMessage = nil
    }

    private func refreshDiagnosticSummary() {
        let rect = liveCanvasService.canvasRect
        diagnosticSummary = [
            "host: \(hostState.rawValue)",
            "update: \(updatePhase.rawValue)",
            "live: \(livePreviewInfo.state.rawValue)",
            "transport: \(transportSummary)",
            projectPreviewIndexSummary,
            prewarmSummary,
            prewarmCandidateSummary,
            prewarmStatsSummary,
            prewarmResourceSummary,
            startupTimingSummary,
            hostLifecycleSummary,
            "pid: \(livePreviewInfo.hostProcessID.map(String.init) ?? "-")",
            "window: \(livePreviewInfo.hostWindowNumber.map(String.init) ?? "-")",
            String(format: "frame: %.1f, %.1f, %.1f x %.1f", rect.origin.x, rect.origin.y, rect.width, rect.height)
        ].joined(separator: " | ")
    }
}
