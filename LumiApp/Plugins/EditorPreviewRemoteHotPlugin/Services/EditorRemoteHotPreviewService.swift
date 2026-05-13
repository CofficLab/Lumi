import AppKit
import Foundation
import LumiHotPreviewKit
import LumiPreviewKit

@MainActor
final class EditorRemoteHotPreviewService: ObservableObject {
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
    @Published private(set) var lastFrameSummary = "No Frame"
    @Published private(set) var livePreviewInfo = LumiPreviewPackage.LivePreviewInfo()
    @Published private(set) var isLiveLoading = false

    private let scanner = LumiPreviewPackage.PreviewScanner()
    private let imageLoader = LumiHotPreviewPackage.ImageFileLoader()
    private var previewSession: LumiHotPreviewPackage.HotPreviewSession?
    private var previewEngine: LumiHotPreviewPackage.HotPreviewEngine?
    private var commandTask: Task<Void, Never>?
    private var scheduledRefreshTask: Task<Void, Never>?
    private var isExecutingCommand = false
    private var pendingReloadReason: String?
    private var activeFileURL: URL?
    private var activeSourceText: String?

    init() {
        warmupHostIfPossible()
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
            return
        }

        selectedPreviewID = nextPreviews.first?.id
        if nextPreviews.isEmpty {
            resetRenderState()
        } else if previewSession != nil {
            start(reason: "selected hot preview changed after source scan")
        }
    }

    func selectPreview(id: String?) {
        guard selectedPreviewID != id else { return }
        selectedPreviewID = id
        guard id != nil else {
            stop(reason: "hot preview selection cleared")
            return
        }
        start(reason: "hot preview selection changed")
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
            self?.reload(reason: "scheduled hot preview refresh: \(reason)")
        }
    }

    func stop(reason: String) {
        run(.stop(reason: reason))
    }

    func startLivePreview(reason: String) {
        Task { [weak self] in
            await self?.startLivePreviewSession(reason: reason)
        }
    }

    func stopLivePreview(reason: String) {
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
        EditorRemoteHotPreviewPlugin.logger.info("Starting hot preview: \(reason, privacy: .public)")
        scheduledRefreshTask?.cancel()
        scheduledRefreshTask = nil

        guard let selectedPreview else {
            resetRenderState()
            lastFrameSummary = "No Preview"
            return
        }

        guard let hostExecutableURL = LumiHotPreviewPackage.HotPreviewHostExecutableResolver.resolve() else {
            handle(.failed(message: "Hot preview host executable was not found."))
            return
        }
        if let previousSession = previewSession, let previousEngine = previewEngine {
            try? await previousEngine.stopLivePreview(previousSession)
            await previousEngine.stopPreview(previousSession)
        }

        hostState = .launching
        updatePhase = .refreshing
        failureMessage = nil
        renderImage = nil
        renderMessage = nil
        diagnostics = nil
        performanceSummary = nil
        transportSummary = "-"
        lastFrame = nil
        lastFrameSummary = "Waiting for Host"

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
            handle(.frameRendered(makeFrame()))
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
        guard let previewSession, let previewEngine else {
            EditorRemoteHotPreviewPlugin.logger.debug(
                "Skipping hot preview reload without a session: \(reason, privacy: .public)"
            )
            return
        }

        EditorRemoteHotPreviewPlugin.logger.info("Reloading hot preview: \(reason, privacy: .public)")
        hostState = .rendering
        updatePhase = .refreshing
        failureMessage = nil
        lastFrameSummary = "Frame Pending"

        do {
            if let selectedPreview {
                await previewSession.updateDiscovery(selectedPreview)
            }
            try await previewEngine.refreshPreview(previewSession)
            guard !Task.isCancelled else { return }
            await syncPreviewState(from: previewSession)
            handle(.frameRendered(makeFrame()))
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
        updatePhase = .idle
        guard let session = previewSession, let engine = previewEngine else {
            handle(.sessionStopped(reason: reason))
            return
        }

        EditorRemoteHotPreviewPlugin.logger.info("Stopping hot preview: \(reason, privacy: .public)")
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
            EditorRemoteHotPreviewPlugin.logger.info("Hot preview stopped: \(reason, privacy: .public)")
            resetRenderState()
        case let .failed(message):
            EditorRemoteHotPreviewPlugin.logger.error("Hot preview failed: \(message, privacy: .public)")
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

    private func handleRefreshFailure(_ message: String) {
        if renderImage != nil {
            renderMessage = message
            failureMessage = message
            hostState = .failed
            lastFrameSummary = message
            updatePhase = .idle
        } else {
            handle(.failed(message: message))
        }
    }

    private func syncPreviewState(from session: LumiHotPreviewPackage.HotPreviewSession) async {
        if let response = await session.lastHotRenderResponse {
            applyRenderResponse(response)
        }

        performanceSummary = EditorPreviewFormatter.performanceSummary(for: await session.performanceMetrics)
        livePreviewInfo = await session.livePreviewInfo

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

    private func applyRenderResponse(_ response: LumiHotPreviewPackage.HotRenderResponse) {
        if let imageFilePath = response.imageFilePath,
           let image = imageLoader.loadImage(at: URL(fileURLWithPath: imageFilePath)) {
            renderImage = image
            transportSummary = "file"
        } else if let base64 = response.previewImagePNGBase64,
                  let data = Data(base64Encoded: base64),
                  let image = NSImage(data: data) {
            renderImage = image
            transportSummary = "base64"
        } else {
            renderImage = nil
            transportSummary = response.preferredTransport.rawValue
        }

        renderMessage = response.message
        diagnostics = response.diagnostics
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
        livePreviewInfo = LumiPreviewPackage.LivePreviewInfo()
        isLiveLoading = false
        updatePhase = .idle
        hostState = .idle
        lastFrameSummary = "No Frame"
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
            do {
                try await self?.previewEngine?.warmupHost()
            } catch {
                EditorRemoteHotPreviewPlugin.logger.debug(
                    "Hot preview warmup skipped: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    private func startLivePreviewSession(reason: String) async {
        guard let session = previewSession, let engine = previewEngine else { return }
        EditorRemoteHotPreviewPlugin.logger.info("Starting hot live preview: \(reason, privacy: .public)")
        isLiveLoading = true
        livePreviewInfo = LumiPreviewPackage.LivePreviewInfo(state: .launching)

        do {
            try await engine.startLivePreview(session)
            try await engine.showLivePreview(session)
            await syncPreviewState(from: session)
            isLiveLoading = false
        } catch let error as LumiPreviewPackage.PreviewError {
            livePreviewInfo = LumiPreviewPackage.LivePreviewInfo(
                state: .failed,
                unavailableReason: EditorPreviewFormatter.message(for: error)
            )
            isLiveLoading = false
        } catch {
            livePreviewInfo = LumiPreviewPackage.LivePreviewInfo(
                state: .failed,
                unavailableReason: error.localizedDescription
            )
            isLiveLoading = false
        }
    }

    private func stopLivePreviewSession(reason: String) async {
        guard let session = previewSession, let engine = previewEngine else { return }
        EditorRemoteHotPreviewPlugin.logger.info("Stopping hot live preview: \(reason, privacy: .public)")
        do {
            try await engine.stopLivePreview(session)
            await syncPreviewState(from: session)
        } catch let error as LumiPreviewPackage.PreviewError {
            livePreviewInfo = LumiPreviewPackage.LivePreviewInfo(
                state: .failed,
                unavailableReason: EditorPreviewFormatter.message(for: error)
            )
        } catch {
            livePreviewInfo = LumiPreviewPackage.LivePreviewInfo(
                state: .failed,
                unavailableReason: error.localizedDescription
            )
        }
    }
}
