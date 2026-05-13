import AppKit
import Foundation
import LumiPreviewKit

@MainActor
final class EditorPreviewRemoteService: ObservableObject {
    @Published private(set) var hostState: EditorPreviewRemoteHostState = .idle
    @Published private(set) var lastFrame: EditorPreviewRemoteFrame?
    @Published private(set) var previews: [LumiPreviewPackage.PreviewDiscovery] = []
    @Published var selectedPreviewID: String?
    @Published private(set) var renderImage: NSImage?
    @Published private(set) var renderSurfaceFrame: LumiPreviewPackage.PreviewSurfaceFrame?
    @Published private(set) var renderMessage: String?
    @Published private(set) var diagnostics: String?
    @Published private(set) var performanceSummary: String?
    @Published private(set) var livePreviewInfo = LumiPreviewPackage.LivePreviewInfo()
    @Published private(set) var isLiveLoading = false
    @Published private(set) var staleLivePreviewMessage: String?
    @Published private(set) var updatePhase: EditorPreviewRemoteUpdatePhase = .idle
    @Published private(set) var lastFrameSummary: String = String(
        localized: "No Frame",
        table: EditorPreviewRemoteConstants.localizationTable
    )
    @Published private(set) var surfaceTransportSummary = "-"
    @Published private(set) var failureMessage: String?

    private let scanner = LumiPreviewPackage.PreviewScanner()
    private let liveCanvasService = EditorPreviewRemoteLiveCanvasService()
    private let embeddedFrameStream = EditorPreviewRemoteEmbeddedFrameStream()
    private var previewSession: (any LumiPreviewPackage.PreviewSession)?
    private var previewEngine: LumiPreviewPackage.LivePreviewEngine?
    private var commandTask: Task<Void, Never>?
    private var scheduledRefreshTask: Task<Void, Never>?
    private var isExecutingCommand = false
    private var pendingReloadReason: String?
    private var activeFileURL: URL?
    private var activeSourceText: String?
    private var forceImageFallbackNextCapture = true

    init() {
        bindLiveCanvasService()
    }

    deinit {
        commandTask?.cancel()
        scheduledRefreshTask?.cancel()
    }

    func update(sourceText: String?, fileURL: URL?) {
        activeSourceText = sourceText
        activeFileURL = fileURL

        guard let sourceText,
              let fileURL,
              fileURL.pathExtension == "swift" else {
            previews = []
            selectedPreviewID = nil
            stop(reason: "remote preview source became unavailable")
            return
        }

        let nextPreviews = scanner.scan(fileURL: fileURL, sourceText: sourceText)
        previews = nextPreviews

        if let selectedPreviewID,
           nextPreviews.contains(where: { $0.id == selectedPreviewID }) {
            return
        }

        selectedPreviewID = nextPreviews.first?.id
        if nextPreviews.isEmpty {
            resetRenderState()
        } else if previewSession != nil {
            start(reason: "selected preview changed after source scan")
        }
    }

    func selectPreview(id: String?) {
        guard selectedPreviewID != id else { return }
        selectedPreviewID = id
        guard id != nil else {
            stop(reason: "remote preview selection cleared")
            return
        }
        start(reason: "remote preview selection changed")
    }

    func start(reason: String) {
        run(.start(reason: reason))
    }

    func reload(reason: String) {
        guard previewSession != nil else {
            start(reason: reason)
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

        scheduledRefreshTask?.cancel()
        updatePhase = .waitingToRefresh
        scheduledRefreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            self?.reload(reason: "scheduled remote preview refresh: \(reason)")
        }
    }

    func stop(reason: String) {
        run(.stop(reason: reason))
    }

    var diagnosticSummary: String {
        let rect = liveCanvasService.canvasRect
        return [
            "host: \(hostState.rawValue)",
            "update: \(updatePhase.rawValue)",
            "live: \(livePreviewInfo.state.rawValue)",
            "transport: \(surfaceTransportSummary)",
            "pid: \(livePreviewInfo.hostProcessID.map(String.init) ?? "-")",
            "window: \(livePreviewInfo.hostWindowNumber.map(String.init) ?? "-")",
            String(format: "frame: %.1f, %.1f, %.1f x %.1f", rect.origin.x, rect.origin.y, rect.width, rect.height)
        ].joined(separator: " | ")
    }

    func detailViewDidDisappear() {
        liveCanvasService.canvasDidDisappear()
    }

    func liveCanvasDidAppear() {
        liveCanvasService.canvasDidAppear()
    }

    func liveCanvasDidDisappear() {
        liveCanvasService.canvasDidDisappear()
    }

    func liveCanvasFrameUnavailable() {
        liveCanvasService.canvasFrameUnavailable()
    }

    func updateLiveCanvasRect(_ rect: CGRect, scale: CGFloat) {
        liveCanvasService.updateCanvasRect(rect, scale: scale)
    }

    private func run(_ command: EditorPreviewRemoteCommand) {
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

    private func execute(_ command: EditorPreviewRemoteCommand) async {
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
        EditorPreviewRemotePlugin.logger.info("Starting remote preview: \(reason, privacy: .public)")
        scheduledRefreshTask?.cancel()
        scheduledRefreshTask = nil
        liveCanvasService.cancelPendingFrameSync()
        stopEmbeddedLiveFrameStream()
        guard let selectedPreview else {
            resetRenderState()
            lastFrameSummary = String(localized: "No Preview", table: EditorPreviewRemoteConstants.localizationTable)
            return
        }

        guard let hostExecutableURL = LumiPreviewPackage.PreviewHostExecutableResolver.resolve() else {
            handle(.failed(message: String(localized: "Preview host executable was not found.", table: EditorPreviewRemoteConstants.localizationTable)))
            return
        }

        if let previousSession = previewSession, let previousEngine = previewEngine {
            await hideLivePreview(
                session: previousSession,
                engine: previousEngine,
                reason: "replacing remote preview session"
            )
            await previousEngine.stopPreview(previousSession)
        }

        hostState = .launching
        updatePhase = .refreshing
        failureMessage = nil
        renderImage = nil
        renderSurfaceFrame = nil
        renderMessage = nil
        diagnostics = nil
        performanceSummary = nil
        surfaceTransportSummary = "-"
        forceImageFallbackNextCapture = true
        livePreviewInfo = LumiPreviewPackage.LivePreviewInfo()
        isLiveLoading = true
        staleLivePreviewMessage = nil
        lastFrame = nil
        lastFrameSummary = String(localized: "Waiting for Host", table: EditorPreviewRemoteConstants.localizationTable)

        let engine = LumiPreviewPackage.LivePreviewEngine(hostExecutableURL: hostExecutableURL)
        previewEngine = engine

        do {
            let nextPreviewSession = try await engine.startPreview(selectedPreview)
            guard !Task.isCancelled else {
                await engine.stopPreview(nextPreviewSession)
                return
            }
            previewSession = nextPreviewSession
            await syncPreviewState(from: nextPreviewSession)
            handle(.frameRendered(makeFrame()))

            await startLivePreview(reason: "remote preview session started")
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
        guard let previewSession,
              let previewEngine else {
            EditorPreviewRemotePlugin.logger.debug(
                "Skipping remote preview reload without a session: \(reason, privacy: .public)")
            return
        }

        EditorPreviewRemotePlugin.logger.info("Reloading remote preview: \(reason, privacy: .public)")
        hostState = .rendering
        updatePhase = .refreshing
        failureMessage = nil
        lastFrameSummary = String(localized: "Frame Pending", table: EditorPreviewRemoteConstants.localizationTable)
        stopEmbeddedLiveFrameStream()

        do {
            if let selectedPreview,
               let livePreviewSession = previewSession as? LumiPreviewPackage.LivePreviewSession {
                await livePreviewSession.updateDiscovery(selectedPreview)
            }
            try await previewEngine.refreshPreview(previewSession)
            guard !Task.isCancelled else { return }
            await syncPreviewState(from: previewSession)
            handle(.frameRendered(makeFrame()))

            await captureEmbeddedLiveFrame(
                reason: "remote preview reload finished: \(reason)",
                allowDuringCommand: true
            )
            startEmbeddedLiveFrameStream(reason: "remote preview reload finished: \(reason)")
            staleLivePreviewMessage = nil
            updatePhase = .idle
        } catch let error as LumiPreviewPackage.PreviewError {
            handleRefreshFailure(EditorPreviewFormatter.message(for: error))
        } catch {
            handleRefreshFailure(error.localizedDescription)
        }
    }

    private func stopSession(reason: String) async {
        scheduledRefreshTask?.cancel()
        scheduledRefreshTask = nil
        pendingReloadReason = nil
        liveCanvasService.cancelPendingFrameSync()
        stopEmbeddedLiveFrameStream()
        updatePhase = .idle
        guard let session = previewSession, let engine = previewEngine else {
            handle(.sessionStopped(reason: reason))
            return
        }

        EditorPreviewRemotePlugin.logger.info("Stopping remote preview: \(reason, privacy: .public)")
        await hideLivePreview(session: session, engine: engine, reason: "stopping remote preview: \(reason)")
        await engine.stopPreview(session)
        guard !Task.isCancelled else { return }
        handle(.sessionStopped(reason: reason))
    }

    private func handle(_ event: EditorPreviewRemoteEvent) {
        switch event {
        case let .frameRendered(frame):
            lastFrame = frame
            hostState = .connected
            lastFrameSummary = frame.summary
        case let .sessionStopped(reason):
            EditorPreviewRemotePlugin.logger.info(
                "Remote preview stopped: \(reason, privacy: .public)")
            previewSession = nil
            previewEngine = nil
            lastFrame = nil
            renderImage = nil
            renderSurfaceFrame = nil
            renderMessage = nil
            diagnostics = nil
            performanceSummary = nil
            surfaceTransportSummary = "-"
            forceImageFallbackNextCapture = true
            livePreviewInfo = LumiPreviewPackage.LivePreviewInfo()
            isLiveLoading = false
            liveCanvasService.cancelPendingFrameSync()
            stopEmbeddedLiveFrameStream()
            staleLivePreviewMessage = nil
            updatePhase = .idle
            hostState = .idle
            failureMessage = nil
            lastFrameSummary = String(localized: "No Frame", table: EditorPreviewRemoteConstants.localizationTable)
        case let .failed(message):
            EditorPreviewRemotePlugin.logger.error(
                "Remote preview failed: \(message, privacy: .public)")
            hostState = .failed
            failureMessage = message
            renderMessage = message
            isLiveLoading = false
            updatePhase = .idle
            lastFrameSummary = message
        }
    }

    private var selectedPreview: LumiPreviewPackage.PreviewDiscovery? {
        if let selectedPreviewID,
           let selected = previews.first(where: { $0.id == selectedPreviewID }) {
            return selected
        }
        return previews.first
    }

    private func bindLiveCanvasService() {
        liveCanvasService.onSyncFrame = { [weak self] reason in
            await self?.syncLiveFrameFromEngine(reason: reason)
        }
        liveCanvasService.onCaptureFrame = { [weak self] reason in
            await self?.captureEmbeddedLiveFrame(reason: "live canvas wants to show embedded frame: \(reason)")
        }
        liveCanvasService.onHideLivePreview = { [weak self] reason in
            await self?.hideCurrentLivePreview(reason: reason)
        }
    }

    private func startLivePreview(reason: String) async {
        guard let session = previewSession, let engine = previewEngine else { return }

        do {
            isLiveLoading = true
            try await engine.startLivePreview(session)
            livePreviewInfo = LumiPreviewPackage.LivePreviewInfo(state: .running)
            await syncPreviewState(from: session)
            await hideCurrentLivePreview(reason: "remote preview uses embedded live frame stream: \(reason)")
            await captureEmbeddedLiveFrame(reason: "live preview started: \(reason)", allowDuringCommand: true)
            startEmbeddedLiveFrameStream(reason: "live preview started: \(reason)")
            isLiveLoading = false
            staleLivePreviewMessage = nil
        } catch {
            fallbackToImage(reason: error.localizedDescription)
        }
    }

    private func syncLiveFrameFromEngine(reason: String) async {
        guard !liveCanvasService.canvasRect.isEmpty,
              let session = previewSession,
              let engine = previewEngine else {
            return
        }

        let rect = liveCanvasService.canvasRect
        EditorPreviewRemotePlugin.logger.info(
            "Syncing remote live preview frame: \(reason, privacy: .public)")
        try? await engine.updateLiveFrame(
            session,
            x: Double(rect.origin.x),
            y: Double(rect.origin.y),
            width: Double(rect.width),
            height: Double(rect.height),
            scale: Double(liveCanvasService.canvasScale)
        )
    }

    private func hideCurrentLivePreview(reason: String) async {
        guard let session = previewSession, let engine = previewEngine else { return }
        await hideLivePreview(session: session, engine: engine, reason: reason)
    }

    private func hideLivePreview(
        session: any LumiPreviewPackage.PreviewSession,
        engine: LumiPreviewPackage.LivePreviewEngine,
        reason: String
    ) async {
        EditorPreviewRemotePlugin.logger.info("Hiding remote live preview: \(reason, privacy: .public)")
        try? await engine.hideLivePreview(session)
        livePreviewInfo = LumiPreviewPackage.LivePreviewInfo(
            state: .available,
            hostWindowNumber: livePreviewInfo.hostWindowNumber,
            hostProcessID: livePreviewInfo.hostProcessID
        )
    }

    private func fallbackToImage(reason: String) {
        EditorPreviewRemotePlugin.logger.error(
            "Remote live preview failed: \(reason, privacy: .public)")
        stopEmbeddedLiveFrameStream()
        isLiveLoading = false
        livePreviewInfo = LumiPreviewPackage.LivePreviewInfo(
            state: .failed,
            unavailableReason: reason
        )
    }

    private func handleRefreshFailure(_ message: String) {
        if renderSurfaceFrame != nil || renderImage != nil {
            staleLivePreviewMessage = String(
                localized: "Showing previous successful Live preview",
                table: EditorPreviewRemoteConstants.localizationTable
            )
            renderMessage = message
            failureMessage = message
            hostState = .failed
            lastFrameSummary = message
            updatePhase = .idle
        } else {
            handle(.failed(message: message))
        }
    }

    private func syncPreviewState(from session: any LumiPreviewPackage.PreviewSession) async {
        if let response = await session.lastRenderResponse {
            applyRenderResponse(response)
        }

        performanceSummary = EditorPreviewFormatter.performanceSummary(for: await session.performanceMetrics)

        let nextLiveInfo = await session.livePreviewInfo
        if nextLiveInfo.state != .unavailable {
            livePreviewInfo = nextLiveInfo
        }

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
    }

    private func makeFrame() -> EditorPreviewRemoteFrame {
        let imageSize = renderSurfaceFrame.map { surfaceFrame in
            CGSize(
                width: Double(surfaceFrame.width) / max(surfaceFrame.scale, 1),
                height: Double(surfaceFrame.height) / max(surfaceFrame.scale, 1)
            )
        } ?? renderImage?.size ?? CGSize(width: 900, height: 560)
        return EditorPreviewRemoteFrame(
            frameID: UInt64(Date().timeIntervalSince1970 * 1_000),
            size: imageSize,
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            renderedAt: Date()
        )
    }

    private func resetRenderState() {
        previewSession = nil
        previewEngine = nil
        lastFrame = nil
        renderImage = nil
        renderSurfaceFrame = nil
        renderMessage = nil
        diagnostics = nil
        performanceSummary = nil
        surfaceTransportSummary = "-"
        forceImageFallbackNextCapture = true
        failureMessage = nil
        livePreviewInfo = LumiPreviewPackage.LivePreviewInfo()
        isLiveLoading = false
        liveCanvasService.cancelPendingFrameSync()
        stopEmbeddedLiveFrameStream()
        staleLivePreviewMessage = nil
        updatePhase = .idle
        hostState = .idle
        lastFrameSummary = String(localized: "No Frame", table: EditorPreviewRemoteConstants.localizationTable)
    }

    private func startEmbeddedLiveFrameStream(reason: String) {
        guard !embeddedFrameStream.isRunning,
              let session = previewSession,
              let engine = previewEngine else {
            return
        }

        embeddedFrameStream.start(
            session: session,
            engine: engine,
            reason: reason,
            includeImageFallback: { [weak self] in
                self?.needsImageFallbackForNextCapture ?? true
            },
            onFrame: { [weak self] response, _ in
                await self?.handleEmbeddedLiveFrame(response)
            },
            onFailure: { [weak self] captureReason, error in
                self?.logEmbeddedLiveFrameFailure(reason: captureReason, error: error)
            }
        )
    }

    private func stopEmbeddedLiveFrameStream() {
        embeddedFrameStream.stop()
    }

    private func captureEmbeddedLiveFrame(reason: String, allowDuringCommand: Bool = false) async {
        guard (allowDuringCommand || !isExecutingCommand),
              let session = previewSession,
              let engine = previewEngine else {
            return
        }

        await embeddedFrameStream.captureOnce(
            session: session,
            engine: engine,
            reason: reason,
            includeImageFallback: needsImageFallbackForNextCapture,
            onFrame: { [weak self] response, _ in
                await self?.handleEmbeddedLiveFrame(response)
            },
            onFailure: { [weak self] captureReason, error in
                self?.logEmbeddedLiveFrameFailure(reason: captureReason, error: error)
            }
        )
    }

    private func handleEmbeddedLiveFrame(_ response: LumiPreviewPackage.RenderResponse) async {
        applyRenderResponse(response)
        if let previewSession {
            await syncPreviewState(from: previewSession)
        }
        handle(.frameRendered(makeFrame()))
    }

    private var needsImageFallbackForNextCapture: Bool {
        forceImageFallbackNextCapture || renderSurfaceFrame == nil
    }

    private func applyRenderResponse(_ response: LumiPreviewPackage.RenderResponse) {
        let surfaceFrame = response.surfaceFrame
        let resolvedSurfaceFrame = EditorPreviewRemoteSurfaceResolver.canResolve(surfaceFrame) ? surfaceFrame : nil
        let fallbackImage = resolvedSurfaceFrame == nil ? EditorPreviewFormatter.image(from: response) : nil
        let hadVisibleFrame = renderSurfaceFrame != nil || renderImage != nil

        if let resolvedSurfaceFrame {
            renderSurfaceFrame = resolvedSurfaceFrame
            renderImage = nil
            forceImageFallbackNextCapture = false
        } else if let fallbackImage {
            renderSurfaceFrame = nil
            renderImage = fallbackImage
            forceImageFallbackNextCapture = true
        } else if surfaceFrame != nil {
            forceImageFallbackNextCapture = true
        } else if !hadVisibleFrame {
            renderSurfaceFrame = nil
            renderImage = nil
            forceImageFallbackNextCapture = true
        } else {
            forceImageFallbackNextCapture = true
        }

        renderMessage = response.message
        diagnostics = response.diagnostics
        surfaceTransportSummary = surfaceTransportSummary(
            surfaceFrame: surfaceFrame,
            resolvedSurfaceFrame: resolvedSurfaceFrame,
            hasImageFallback: fallbackImage != nil,
            keptPreviousFrame: hadVisibleFrame && resolvedSurfaceFrame == nil && fallbackImage == nil
        )
    }

    private func surfaceTransportSummary(
        surfaceFrame: LumiPreviewPackage.PreviewSurfaceFrame?,
        resolvedSurfaceFrame: LumiPreviewPackage.PreviewSurfaceFrame?,
        hasImageFallback: Bool,
        keptPreviousFrame: Bool
    ) -> String {
        if let resolvedSurfaceFrame {
            let suffix = resolvedSurfaceFrame.transport.isSecureCrossProcessTransport ? "" : " insecure"
            return "\(resolvedSurfaceFrame.transportKind)\(suffix)"
        }
        if let surfaceFrame {
            if keptPreviousFrame {
                return "\(surfaceFrame.transportKind) unresolved keeping previous"
            }
            return hasImageFallback ? "\(surfaceFrame.transportKind) fallback PNG" : "\(surfaceFrame.transportKind) unresolved"
        }
        if keptPreviousFrame {
            return "missing frame keeping previous"
        }
        return hasImageFallback ? "PNG" : "-"
    }

    private func logEmbeddedLiveFrameFailure(reason: String, error: Error) {
        EditorPreviewRemotePlugin.logger.debug(
            "Skipping embedded remote live frame capture: \(reason, privacy: .public) - \(error.localizedDescription, privacy: .public)")
    }
}
