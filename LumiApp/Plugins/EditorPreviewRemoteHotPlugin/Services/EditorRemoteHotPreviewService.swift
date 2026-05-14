import AppKit
import MagicKit
import Foundation
import LumiHotPreviewKit
import LumiPreviewKit

@MainActor
final class EditorRemoteHotPreviewService: ObservableObject, SuperLog {
    nonisolated static let emoji = "⚡"
    @Published private(set) var hostState: EditorRemoteHotPreviewHostState = .idle
    @Published private(set) var lastFrame: EditorRemoteHotPreviewFrame?
    @Published private(set) var previews: [LumiPreviewPackage.PreviewDiscovery] = []
    @Published var selectedPreviewID: String?
    @Published private(set) var renderImage: NSImage?
    @Published private(set) var renderMessage: String?
    @Published private(set) var diagnostics: String?
    @Published private(set) var performanceSummary: String?
    @Published private(set) var transportSummary = "-"
    @Published private(set) var failureMessage: String?
    @Published private(set) var updatePhase: EditorRemoteHotPreviewUpdatePhase = .idle
    @Published private(set) var lastFrameSummary = String(localized: "No Frame", table: "EditorPreviewRemoteHotPlugin")
    @Published private(set) var diagnosticSummary = "host: idle | live: available | frame: 0, 0, 0 x 0"
    @Published private(set) var livePreviewInfo = LumiPreviewPackage.LivePreviewInfo()
    @Published private(set) var isLiveLoading = false
    @Published private(set) var preferredDisplayMode: LumiPreviewPackage.PreviewDisplayMode = .live
    @Published private(set) var effectiveDisplayMode: LumiPreviewPackage.PreviewDisplayMode = .image
    @Published private(set) var modeStatusMessage: String?
    @Published private(set) var isShowingStaleFrame = false

    private let scanner = LumiPreviewPackage.PreviewScanner()
    private let imageLoader = LumiHotPreviewPackage.ImageFileLoader()
    private let liveCanvasService = EditorRemoteHotPreviewLiveCanvasService()
    private var previewSession: LumiHotPreviewPackage.HotPreviewSession?
    private var previewEngine: LumiHotPreviewPackage.HotPreviewEngine?
    private var commandTask: Task<Void, Never>?
    private var scheduledRefreshTask: Task<Void, Never>?
    private var isExecutingCommand = false
    private var pendingReloadReason: String?
    private var activeFileURL: URL?
    private var activeSourceText: String?
    private var lastRenderedPreviewFingerprint: String?
    private var shouldRestorePreferredLiveMode = true
    private var isDetailViewVisible = false

    init() {
        bindLiveCanvasService()
        warmupHostIfPossible()
        refreshDiagnosticSummary()
    }

    deinit {
        commandTask?.cancel()
        scheduledRefreshTask?.cancel()
    }

    func update(sourceText: String?, fileURL: URL?) {
        activeSourceText = sourceText
        activeFileURL = fileURL

        guard let sourceText, let fileURL, fileURL.pathExtension == "swift" else {
            previews = []
            selectedPreviewID = nil
            stop(reason: "hot preview source became unavailable")
            return
        }

        let nextPreviews = scanner.scan(fileURL: fileURL, sourceText: sourceText)
        previews = nextPreviews

        if let selectedPreviewID,
           nextPreviews.contains(where: { $0.id == selectedPreviewID }) {
            if previewSession != nil,
               let selectedPreview,
               previewFingerprint(for: selectedPreview) != lastRenderedPreviewFingerprint {
                scheduleReload(reason: "selected hot preview fingerprint changed after source scan")
            }
            return
        }

        selectedPreviewID = nextPreviews.first?.id
        if nextPreviews.isEmpty {
            resetRenderState()
        } else if previewSession != nil {
            reload(reason: "selected hot preview changed after source scan")
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

    func detailViewDidDisappear() {
        isDetailViewVisible = false
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
        liveCanvasService.updateCanvasRect(rect, scale: scale)
        refreshDiagnosticSummary()
    }

    func previewWindowDidBecomeActive() {
        Task { [weak self] in
            await self?.restoreLivePreviewIfNeeded(reason: "preview window became active")
        }
    }

    func previewWindowDidReceiveInteraction() {
        Task { [weak self] in
            await self?.restoreLivePreviewIfNeeded(reason: "preview window received interaction")
        }
    }

    private func startLivePreview(reason: String) {
        Task { [weak self] in
            await self?.startLivePreviewSession(reason: reason)
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

        commandTask?.cancel()
        commandTask = Task { [weak self] in
            guard let self else { return }
            await execute(command)
        }
    }

    private func execute(_ command: EditorRemoteHotPreviewCommand) async {
        isExecutingCommand = true
        defer {
            isExecutingCommand = false
            runPendingReloadIfNeeded()
        }

        switch command {
        case let .start(reason):
            await startSession(reason: reason)
        case let .reload(reason):
            await reloadSession(reason: reason)
        case let .stop(reason):
            await stopSession(reason: reason)
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

    private func startSession(reason: String) async {
        EditorRemoteHotPreviewPlugin.logger.info("\(self.t)Starting hot preview: \(reason, privacy: .public)")
        scheduledRefreshTask?.cancel()
        scheduledRefreshTask = nil
        liveCanvasService.cancelPendingFrameSync()

        guard let selectedPreview else {
            resetRenderState()
            lastFrameSummary = String(localized: "No Preview", table: "EditorPreviewRemoteHotPlugin")
            return
        }

        guard let hostExecutableURL = LumiHotPreviewPackage.HotPreviewHostExecutableResolver.resolve() else {
            handle(.failed(message: String(localized: "Hot preview host executable was not found.", table: "EditorPreviewRemoteHotPlugin")))
            return
        }
        if let previousSession = previewSession, let previousEngine = previewEngine {
            try? await previousEngine.stopLivePreview(previousSession)
            await previousEngine.stopPreview(previousSession)
        }

        preserveCurrentFrameForRestart(message: String(localized: "Rebuilding hot preview. Showing the previous frame.", table: "EditorPreviewRemoteHotPlugin"))
        hostState = .launching
        updatePhase = .refreshing
        failureMessage = nil
        renderMessage = nil
        diagnostics = nil
        performanceSummary = nil
        transportSummary = "-"
        lastFrame = nil
        lastFrameSummary = "Waiting for Host"  // non-user-facing diagnostic label

        let engine = previewEngine ?? LumiHotPreviewPackage.HotPreviewEngine(hostExecutableURL: hostExecutableURL)
        previewEngine = engine

        do {
            let session = try await engine.startPreview(selectedPreview)
            guard !Task.isCancelled else {
                await engine.stopPreview(session)
                return
            }
            previewSession = session
            await syncPreviewState(from: session)
            lastRenderedPreviewFingerprint = previewFingerprint(for: selectedPreview)
            handle(.frameRendered(makeFrame()))
            if preferredDisplayMode == .live, shouldRestorePreferredLiveMode {
                await startLivePreviewSession(reason: "restoring preferred live mode after start")
            }
            updatePhase = .idle
        } catch let error as LumiPreviewPackage.PreviewError {
            handle(.failed(message: EditorPreviewFormatter.message(for: error)))
        } catch {
            handle(.failed(message: error.localizedDescription))
        }
    }

    private func reloadSession(reason: String) async {
        scheduledRefreshTask?.cancel()
        scheduledRefreshTask = nil
        liveCanvasService.cancelPendingFrameSync()
        guard let previewSession, let previewEngine else {
            EditorRemoteHotPreviewPlugin.logger.debug(
                "\(self.t)Skipping hot preview reload without a session: \(reason, privacy: .public)"
            )
            return
        }

        EditorRemoteHotPreviewPlugin.logger.info("\(self.t)Reloading hot preview: \(reason, privacy: .public)")
        hostState = .rendering
        updatePhase = .refreshing
        failureMessage = nil
        lastFrameSummary = "Frame Pending"  // non-user-facing diagnostic label

        do {
            if let selectedPreview {
                await previewSession.updateDiscovery(selectedPreview)
            }
            try await previewEngine.refreshPreview(previewSession)
            guard !Task.isCancelled else { return }
            await syncPreviewState(from: previewSession)
            if let selectedPreview {
                lastRenderedPreviewFingerprint = previewFingerprint(for: selectedPreview)
            }
            if livePreviewInfo.state == .running || livePreviewInfo.state == .launching {
                await syncLiveFrameFromEngine(reason: "hot preview reload finished")
                await capturePreviewFrameIfNeeded(
                    reason: "hot preview reload finished",
                    preferFreshImage: true
                )
            }
            handle(.frameRendered(makeFrame()))
            if preferredDisplayMode == .live,
               shouldRestorePreferredLiveMode,
               livePreviewInfo.state != .running,
               livePreviewInfo.state != .launching {
                await startLivePreviewSession(reason: "restoring preferred live mode after reload")
            }
            updatePhase = .idle
        } catch let error as LumiPreviewPackage.PreviewError {
            await handleRefreshFailure(EditorPreviewFormatter.message(for: error))
        } catch {
            await handleRefreshFailure(error.localizedDescription)
        }
    }

    private func stopSession(reason: String) async {
        scheduledRefreshTask?.cancel()
        scheduledRefreshTask = nil
        liveCanvasService.cancelPendingFrameSync()
        pendingReloadReason = nil
        updatePhase = .idle
        guard let session = previewSession, let engine = previewEngine else {
            handle(.sessionStopped(reason: reason))
            return
        }

        EditorRemoteHotPreviewPlugin.logger.info("\(self.t)Stopping hot preview: \(reason, privacy: .public)")
        try? await engine.stopLivePreview(session)
        await engine.stopPreview(session)
        guard !Task.isCancelled else { return }
        handle(.sessionStopped(reason: reason))
    }

    private func handle(_ event: EditorRemoteHotPreviewEvent) {
        switch event {
        case let .frameRendered(frame):
            lastFrame = frame
            hostState = .connected
            lastFrameSummary = frame.summary
        case let .sessionStopped(reason):
            EditorRemoteHotPreviewPlugin.logger.info("\(self.t)Hot preview stopped: \(reason, privacy: .public)")
            resetRenderState()
        case let .failed(message):
            EditorRemoteHotPreviewPlugin.logger.error("\(self.t)Hot preview failed: \(message, privacy: .public)")
            hostState = .failed
            failureMessage = message
            renderMessage = message
            isLiveLoading = false
            updatePhase = .idle
            lastFrameSummary = message
        }
        refreshDiagnosticSummary()
    }

    private var selectedPreview: LumiPreviewPackage.PreviewDiscovery? {
        if let selectedPreviewID,
           let selected = previews.first(where: { $0.id == selectedPreviewID }) {
            return selected
        }
        return previews.first
    }

    private func handleRefreshFailure(_ message: String) async {
        if renderImage != nil {
            renderMessage = message
            failureMessage = message
            hostState = .failed
            isShowingStaleFrame = true
            modeStatusMessage = String(localized: "Refresh failed. Showing the previous frame.", table: "EditorPreviewRemoteHotPlugin")
            lastFrameSummary = message
            updatePhase = .idle
        } else {
            handle(.failed(message: message))
        }

        if preferredDisplayMode == .live,
           (livePreviewInfo.state == .running || livePreviewInfo.state == .launching) {
            await degradeLiveModeAfterRefreshFailure(message)
        }

        refreshDiagnosticSummary()
    }

    private func syncPreviewState(from session: LumiHotPreviewPackage.HotPreviewSession) async {
        if let response = await session.lastHotRenderResponse {
            applyRenderResponse(response)
        }

        performanceSummary = EditorPreviewFormatter.performanceSummary(for: await session.performanceMetrics)
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

    private func applyRenderResponse(_ response: LumiHotPreviewPackage.HotRenderResponse) {
        let previousImage = renderImage
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
        livePreviewInfo = LumiPreviewPackage.LivePreviewInfo()
        isLiveLoading = false
        effectiveDisplayMode = .image
        updatePhase = .idle
        hostState = .idle
        isShowingStaleFrame = false
        modeStatusMessage = nil
        lastFrameSummary = String(localized: "No Frame", table: "EditorPreviewRemoteHotPlugin")
        refreshDiagnosticSummary()
    }

    private func resolvedEffectiveDisplayMode(
        preferredMode: LumiPreviewPackage.PreviewDisplayMode,
        liveInfo: LumiPreviewPackage.LivePreviewInfo,
        fallbackMode: LumiPreviewPackage.PreviewDisplayMode
    ) -> LumiPreviewPackage.PreviewDisplayMode {
        guard preferredMode == .live else {
            return fallbackMode
        }

        switch liveInfo.state {
        case .available, .launching, .running:
            return .live
        case .failed, .stopped, .unavailable:
            return .image
        }
    }

    private func warmupHostIfPossible() {
        guard let hostExecutableURL = LumiHotPreviewPackage.HotPreviewHostExecutableResolver.resolve() else {
            return
        }

        if previewEngine == nil {
            previewEngine = LumiHotPreviewPackage.HotPreviewEngine(hostExecutableURL: hostExecutableURL)
        }

        Task { [weak self] in
            _ = LumiHotPreviewPackage.ImageFileLoader.removeExpiredFrames()
            _ = LumiHotPreviewPackage.SharedMemoryFrameChannel.removeExpiredFrames()
            do {
                try await self?.previewEngine?.warmupHost()
            } catch {
                EditorRemoteHotPreviewPlugin.logger.debug(
                    "\(Self.t)Hot preview warmup skipped: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    private var needsReload: Bool {
        guard let selectedPreview else {
            return false
        }
        return previewFingerprint(for: selectedPreview) != lastRenderedPreviewFingerprint
    }

    private func previewFingerprint(for preview: LumiPreviewPackage.PreviewDiscovery) -> String {
        [
            preview.id,
            preview.title,
            preview.primaryTypeName ?? "",
            "\(preview.lineNumber)",
            "\(preview.endLineNumber)",
            preview.bodySource ?? ""
        ].joined(separator: "\u{1F}")
    }

    private func startLivePreviewSession(reason: String) async {
        guard let session = previewSession, let engine = previewEngine else { return }
        EditorRemoteHotPreviewPlugin.logger.info("\(self.t)Starting hot live preview: \(reason, privacy: .public)")
        effectiveDisplayMode = .live
        isLiveLoading = true
        livePreviewInfo = LumiPreviewPackage.LivePreviewInfo(state: .launching)
        modeStatusMessage = String(localized: "Starting live preview.", table: "EditorPreviewRemoteHotPlugin")
        refreshDiagnosticSummary()

        do {
            try await engine.startLivePreview(session)
            try await engine.showLivePreview(session)
            await syncLiveFrameFromEngine(reason: "hot live preview started")
            await capturePreviewFrameIfNeeded(reason: "hot live preview started")
            await syncPreviewState(from: session)
            isLiveLoading = false
        } catch let error as LumiPreviewPackage.PreviewError {
            livePreviewInfo = LumiPreviewPackage.LivePreviewInfo(
                state: .failed,
                unavailableReason: EditorPreviewFormatter.message(for: error)
            )
            effectiveDisplayMode = .image
            shouldRestorePreferredLiveMode = false
            isLiveLoading = false
            syncModeStatusMessage()
            refreshDiagnosticSummary()
        } catch {
            livePreviewInfo = LumiPreviewPackage.LivePreviewInfo(
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
        EditorRemoteHotPreviewPlugin.logger.info("\(self.t)Stopping hot live preview: \(reason, privacy: .public)")
        do {
            try await engine.stopLivePreview(session)
            effectiveDisplayMode = .image
            await syncPreviewState(from: session)
        } catch let error as LumiPreviewPackage.PreviewError {
            livePreviewInfo = LumiPreviewPackage.LivePreviewInfo(
                state: .failed,
                unavailableReason: EditorPreviewFormatter.message(for: error)
            )
            effectiveDisplayMode = .image
            syncModeStatusMessage()
        } catch {
            livePreviewInfo = LumiPreviewPackage.LivePreviewInfo(
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
              preferredDisplayMode == .live,
              shouldRestorePreferredLiveMode,
              let session = previewSession,
              let engine = previewEngine else {
            return
        }

        switch livePreviewInfo.state {
        case .available, .stopped:
            EditorRemoteHotPreviewPlugin.logger.info(
                "\(self.t)Restoring hot live preview: \(reason, privacy: .public)"
            )
            do {
                try await engine.showLivePreview(session)
                await syncLiveFrameFromEngine(reason: reason)
                await capturePreviewFrameIfNeeded(reason: reason)
                await syncPreviewState(from: session)
            } catch {
                EditorRemoteHotPreviewPlugin.logger.debug(
                    "\(self.t)Failed to restore hot live preview: \(error.localizedDescription, privacy: .public)"
                )
            }
        case .running, .launching:
            await syncLiveFrameFromEngine(reason: reason)
            await capturePreviewFrameIfNeeded(reason: reason)
            await syncPreviewState(from: session)
        case .failed, .unavailable:
            break
        }
    }

    private func hideLivePreviewIfNeeded(reason: String) async {
        guard let session = previewSession,
              let engine = previewEngine,
              livePreviewInfo.state == .running || livePreviewInfo.state == .launching else {
            return
        }

        EditorRemoteHotPreviewPlugin.logger.info("\(self.t)Hiding hot live preview: \(reason, privacy: .public)")
        do {
            try await engine.hideLivePreview(session)
            await syncPreviewState(from: session)
        } catch {
            EditorRemoteHotPreviewPlugin.logger.debug(
                "\(self.t)Failed to hide hot live preview: \(error.localizedDescription, privacy: .public)"
            )
        }
        refreshDiagnosticSummary()
    }

    private func bindLiveCanvasService() {
        liveCanvasService.onSyncFrame = { [weak self] reason in
            await self?.syncLiveFrameFromEngine(reason: reason)
        }
        liveCanvasService.onHideLivePreview = { [weak self] reason in
            await self?.hideLivePreviewIfNeeded(reason: reason)
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
        EditorRemoteHotPreviewPlugin.logger.info("\(self.t)Syncing hot live preview frame: \(reason, privacy: .public)")

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
            EditorRemoteHotPreviewPlugin.logger.debug(
                "\(self.t)Failed to sync hot live preview frame: \(error.localizedDescription, privacy: .public)"
            )
        }

        refreshDiagnosticSummary()
    }

    private func capturePreviewFrameIfNeeded(
        reason: String,
        preferFreshImage: Bool = false
    ) async {
        guard let session = previewSession,
              let engine = previewEngine else {
            return
        }

        if !preferFreshImage, renderImage != nil {
            return
        }

        EditorRemoteHotPreviewPlugin.logger.debug(
            "\(self.t)Capturing hot preview frame: \(reason, privacy: .public)"
        )

        do {
            let response = try await engine.capturePreviewFrame(session)
            applyRenderResponse(response)
        } catch {
            EditorRemoteHotPreviewPlugin.logger.debug(
                "\(self.t)Failed to capture hot preview frame: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func degradeLiveModeAfterRefreshFailure(_ message: String) async {
        guard let session = previewSession,
              let engine = previewEngine else {
            return
        }

        do {
            try await engine.stopLivePreview(session)
        } catch {
            EditorRemoteHotPreviewPlugin.logger.debug(
                "\(self.t)Failed to stop hot live preview after refresh failure: \(error.localizedDescription, privacy: .public)"
            )
        }

        effectiveDisplayMode = .image
        shouldRestorePreferredLiveMode = false
        livePreviewInfo = LumiPreviewPackage.LivePreviewInfo(
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

    private func syncModeStatusMessage() {
        if livePreviewInfo.state == .failed,
           let reason = livePreviewInfo.unavailableReason,
           !reason.isEmpty {
            if preferredDisplayMode == .live && effectiveDisplayMode == .image {
                modeStatusMessage = String(localized: "Live preview is unavailable. Showing image preview. \(reason)", table: "EditorPreviewRemoteHotPlugin")
            } else {
                modeStatusMessage = reason
            }
            return
        }

        if isLiveLoading {
            modeStatusMessage = String(localized: "Starting live preview.", table: "EditorPreviewRemoteHotPlugin")
            return
        }

        if preferredDisplayMode == .live && effectiveDisplayMode == .image {
            modeStatusMessage = String(localized: "Live mode is preferred, but the host is currently showing image preview.", table: "EditorPreviewRemoteHotPlugin")
            return
        }

        if isShowingStaleFrame {
            modeStatusMessage = String(localized: "Showing the previous frame because no fresh frame is available yet.", table: "EditorPreviewRemoteHotPlugin")
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
            "pid: \(livePreviewInfo.hostProcessID.map(String.init) ?? "-")",
            "window: \(livePreviewInfo.hostWindowNumber.map(String.init) ?? "-")",
            String(format: "frame: %.1f, %.1f, %.1f x %.1f", rect.origin.x, rect.origin.y, rect.width, rect.height)
        ].joined(separator: " | ")
    }
}
