#if canImport(LumiPreviewKit)
import Foundation
import LumiPreviewKit
import AppKit
import SwiftUI
import os

@MainActor
final class EditorPreviewViewModel: ObservableObject {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "EditorPreview")

    enum RunState: Equatable {
        case idle
        case hostMissing
        case starting
        case running
        case failed(String)
        case stopped

        var title: String {
            switch self {
            case .idle:
                String(localized: "Idle", table: "EditorPreview")
            case .hostMissing:
                String(localized: "Host missing", table: "EditorPreview")
            case .starting:
                String(localized: "Starting", table: "EditorPreview")
            case .running:
                String(localized: "Running", table: "EditorPreview")
            case .failed:
                String(localized: "Failed", table: "EditorPreview")
            case .stopped:
                String(localized: "Stopped", table: "EditorPreview")
            }
        }
    }

    enum UpdatePhase: Equatable {
        case idle
        case waitingToRefresh
        case refreshing

        var title: String {
            switch self {
            case .idle:
                ""
            case .waitingToRefresh:
                String(localized: "Waiting to refresh", table: "EditorPreview")
            case .refreshing:
                String(localized: "Updating preview", table: "EditorPreview")
            }
        }
    }

    // MARK: - Published State

    @Published private(set) var previews: [PreviewDiscovery] = []
    @Published var selectedPreviewID: String?
    @Published private(set) var runState: RunState = .idle
    @Published private(set) var renderMessage: String?
    @Published private(set) var renderImage: NSImage?
    @Published private(set) var diagnostics: String?
    @Published private(set) var performanceSummary: String?
    @Published private(set) var displayMode: PreviewDisplayMode = .live
    @Published private(set) var livePreviewInfo: LivePreviewInfo = LivePreviewInfo()
    @Published private(set) var liveCanvasRect: CGRect = .zero
    @Published private(set) var isLiveLoading: Bool = false
    @Published private(set) var updatePhase: UpdatePhase = .idle
    @Published private(set) var staleLivePreviewMessage: String?

    // MARK: - Private State

    private static let preferredDisplayModeKey = "EditorPreviewPlugin.preferredDisplayMode"
    private struct PreviewContext {
        var previews: [PreviewDiscovery]
        var selectedPreviewID: String?
        var runState: RunState
        var renderMessage: String?
        var renderImage: NSImage?
        var diagnostics: String?
        var performanceSummary: String?
        var displayMode: PreviewDisplayMode
        var livePreviewInfo: LivePreviewInfo
        var isLiveLoading: Bool
        var updatePhase: UpdatePhase
        var staleLivePreviewMessage: String?
        var session: (any PreviewSession)?
        var engine: LivePreviewEngine?
    }

    private let scanner = PreviewScanner()
    private var session: (any PreviewSession)?
    private var engine: LivePreviewEngine?
    private var sourceRefreshTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var hasPendingRefreshAfterCurrent: Bool = false
    private var isStoppingLive: Bool = false
    private var activeFileKey: String?
    private var cachedContexts = PreviewFileContextCache<PreviewContext>(maximumCount: 4)
    private let liveCanvasService: EditorPreviewLiveCanvasService

    init() {
        let preferredDisplayMode = Self.preferredDisplayMode
        displayMode = preferredDisplayMode
        liveCanvasService = EditorPreviewLiveCanvasService(displayMode: preferredDisplayMode)
        bindLiveCanvasService()
    }

    // MARK: - Computed Properties

    var selectedPreview: PreviewDiscovery? {
        if let selectedPreviewID,
           let selected = previews.first(where: { $0.id == selectedPreviewID }) {
            return selected
        }
        return previews.first
    }

    var canStart: Bool {
        selectedPreview != nil && runState != .starting && runState != .running
    }

    var canRefresh: Bool {
        session != nil && (runState == .running || staleLivePreviewMessage != nil) && updatePhase == .idle
    }

    var canStop: Bool {
        session != nil
    }

    var isUpdatingPreview: Bool {
        updatePhase != .idle
    }

    var isShowingStaleLivePreview: Bool {
        displayMode == .live && staleLivePreviewMessage != nil
    }

    /// Whether Live mode is available for the current session.
    var isLiveAvailable: Bool {
        guard session != nil else { return false }
        return livePreviewInfo.state == .available
            || livePreviewInfo.state == .running
            || livePreviewInfo.state == .launching
    }

    /// Whether Live mode can be switched to (host supports it).
    var canSwitchToLive: Bool {
        guard runState == .running else { return false }
        return livePreviewInfo.state == .available || livePreviewInfo.state == .running
    }

    /// Whether Image mode can be switched to.
    var canSwitchToImage: Bool {
        displayMode == .live
    }

    var liveUnavailableReason: String? {
        guard runState == .running else {
            return String(localized: "Start a preview first", table: "EditorPreview")
        }
        switch livePreviewInfo.state {
        case .unavailable:
            return String(localized: "Live requires a real SwiftUI view entry", table: "EditorPreview")
        case .failed:
            return livePreviewInfo.unavailableReason
                ?? String(localized: "Live preview failed", table: "EditorPreview")
        case .launching, .running, .available:
            return nil
        case .stopped:
            return String(localized: "Live preview stopped", table: "EditorPreview")
        }
    }

    // MARK: - Scan & Source Updates

    func update(sourceText: String?, fileURL: URL?) {
        guard let sourceText,
              let fileURL,
              fileURL.pathExtension == "swift" else {
            cacheActiveContextForFileSwitch()
            activeFileKey = nil
            resetPreviewState()
            return
        }

        let nextFileKey = PreviewFileContextCache<PreviewContext>.key(for: fileURL)
        if activeFileKey != nextFileKey {
            cacheActiveContextForFileSwitch()
            activeFileKey = nextFileKey
            if let cachedContext = cachedContexts.removeValue(forKey: nextFileKey) {
                apply(cachedContext)
                if displayMode == .live {
                    liveCanvasService.liveCanvasDidAppear()
                }
            } else {
                resetPreviewState()
            }
        }

        let nextPreviews = scanner.scan(fileURL: fileURL, sourceText: sourceText)
        previews = nextPreviews

        if let selectedPreviewID,
           nextPreviews.contains(where: { $0.id == selectedPreviewID }) {
            return
        }

        stopActiveSessionForReplacement()
        selectedPreviewID = nextPreviews.first?.id
        if nextPreviews.isEmpty {
            runState = .idle
            renderMessage = nil
            renderImage = nil
            diagnostics = nil
            performanceSummary = nil
        }
    }

    func sourceDidChange(sourceText: String?, fileURL: URL?) {
        let previousPreviewID = selectedPreviewID
        let shouldRefreshRunningPreview = (runState == .running || staleLivePreviewMessage != nil) && session != nil

        update(sourceText: sourceText, fileURL: fileURL)

        guard shouldRefreshRunningPreview,
              runState == .running,
              session != nil,
              selectedPreviewID == previousPreviewID else {
            return
        }

        scheduleSourceRefresh()
    }

    // MARK: - Start / Refresh / Stop

    func startSelectedPreviewIfNeeded(allowsStopped: Bool = true) {
        switch runState {
        case .idle:
            startSelectedPreview()
        case .stopped where allowsStopped:
            startSelectedPreview()
        case .hostMissing, .starting, .running, .failed, .stopped:
            return
        }
    }

    func startSelectedPreview() {
        guard canStart, let selectedPreview else { return }
        guard let hostExecutableURL = PreviewHostExecutableResolver.resolve() else {
            runState = .hostMissing
            return
        }

        let engine = LivePreviewEngine(hostExecutableURL: hostExecutableURL)
        self.engine = engine
        renderMessage = nil
        renderImage = nil
        diagnostics = nil
        performanceSummary = nil
        displayMode = Self.preferredDisplayMode
        liveCanvasService.updateDisplayMode(displayMode)
        isLiveLoading = displayMode == .live
        livePreviewInfo = LivePreviewInfo()
        staleLivePreviewMessage = nil
        runState = .starting

        let startedFileKey = activeFileKey
        let startedPreviewID = selectedPreview.id
        Task {
            do {
                let nextSession = try await engine.startPreview(selectedPreview)
                guard activeFileKey == startedFileKey,
                      selectedPreviewID == startedPreviewID else {
                    await engine.stopPreview(nextSession)
                    return
                }
                session = nextSession
                await syncSessionState(from: nextSession)
                await applyPreferredDisplayModeIfNeeded()
            } catch let error as PreviewError {
                guard activeFileKey == startedFileKey,
                      selectedPreviewID == startedPreviewID else {
                    return
                }
                runState = .failed(EditorPreviewFormatter.message(for: error))
            } catch {
                guard activeFileKey == startedFileKey,
                      selectedPreviewID == startedPreviewID else {
                    return
                }
                runState = .failed(error.localizedDescription)
            }
        }
    }

    func refreshPreview() {
        guard let session, let engine else { return }
        sourceRefreshTask?.cancel()
        sourceRefreshTask = nil
        guard updatePhase != .refreshing else {
            hasPendingRefreshAfterCurrent = true
            return
        }
        updatePhase = .refreshing

        // If in live mode, do live reload
        if displayMode == .live {
            liveReload(session: session, engine: engine)
            return
        }

        runState = .starting

        let refreshFileKey = activeFileKey
        let refreshPreviewID = selectedPreviewID
        refreshTask = Task {
            do {
                if let selectedPreview,
                   let liveSession = session as? LivePreviewSession {
                    await liveSession.updateDiscovery(selectedPreview)
                }
                try await engine.refreshPreview(session)
                guard activeFileKey == refreshFileKey,
                      selectedPreviewID == refreshPreviewID else {
                    return
                }
                await syncSessionState(from: session)
                staleLivePreviewMessage = nil
                finishRefresh()
            } catch let error as PreviewError {
                guard activeFileKey == refreshFileKey,
                      selectedPreviewID == refreshPreviewID else {
                    return
                }
                runState = .failed(EditorPreviewFormatter.message(for: error))
                finishRefresh()
            } catch {
                guard activeFileKey == refreshFileKey,
                      selectedPreviewID == refreshPreviewID else {
                    return
                }
                runState = .failed(error.localizedDescription)
                finishRefresh()
            }
        }
    }

    func stopPreview() {
        isStoppingLive = true
        sourceRefreshTask?.cancel()
        sourceRefreshTask = nil
        refreshTask?.cancel()
        refreshTask = nil
        hasPendingRefreshAfterCurrent = false
        liveCanvasService.cancelPendingFrameSync()
        if let activeFileKey {
            cachedContexts.removeValue(forKey: activeFileKey)
        }

        // Stop live first if running
        if displayMode == .live {
            stopLiveInternal()
        }

        guard let session, let engine else {
            runState = .stopped
            renderMessage = nil
            renderImage = nil
            diagnostics = nil
            performanceSummary = nil
            displayMode = Self.preferredDisplayMode
            liveCanvasService.updateDisplayMode(displayMode)
            isLiveLoading = false
            staleLivePreviewMessage = nil
            updatePhase = .idle
            return
        }

        self.session = nil
        self.engine = nil
        runState = .stopped
        renderMessage = nil
        renderImage = nil
        diagnostics = nil
        performanceSummary = nil
        displayMode = Self.preferredDisplayMode
        liveCanvasService.updateDisplayMode(displayMode)
        isLiveLoading = false
        livePreviewInfo = LivePreviewInfo()
        staleLivePreviewMessage = nil
        updatePhase = .idle

        Task {
            await engine.stopPreview(session)
            isStoppingLive = false
        }
    }

    func cacheActiveContextForFileSwitch() {
        guard let activeFileKey else { return }

        let cachedSession = session
        let cachedEngine = engine
        if displayMode == .live,
           let cachedSession,
           let cachedEngine {
            Task {
                try? await cachedEngine.hideLivePreview(cachedSession)
            }
        }

        let evictedContexts = cachedContexts.store(PreviewContext(
            previews: previews,
            selectedPreviewID: selectedPreviewID,
            runState: runState,
            renderMessage: renderMessage,
            renderImage: renderImage,
            diagnostics: diagnostics,
            performanceSummary: performanceSummary,
            displayMode: displayMode,
            livePreviewInfo: livePreviewInfo,
            isLiveLoading: false,
            updatePhase: .idle,
            staleLivePreviewMessage: staleLivePreviewMessage,
            session: session,
            engine: engine
        ), forKey: activeFileKey)
        stopEvictedContexts(evictedContexts.map(\.value))
    }

    // MARK: - Display Mode Switching

    func switchToLive() {
        guard canSwitchToLive else { return }
        Self.preferredDisplayMode = .live
        displayMode = .live
        liveCanvasService.updateDisplayMode(.live)
        isLiveLoading = true
        staleLivePreviewMessage = nil

        Task {
            await startLivePreview()
        }
    }

    func switchToImage() {
        Self.preferredDisplayMode = .image
        guard canSwitchToImage else { return }
        displayMode = .image
        liveCanvasService.updateDisplayMode(.image)
        staleLivePreviewMessage = nil

        Task {
            await hideLivePreviewInternal()
        }
    }

    // MARK: - Live Preview Lifecycle

    private func startLivePreview() async {
        guard let session = self.session, let engine = self.engine else {
            fallbackToImage(reason: String(localized: "No active session", table: "EditorPreview"))
            return
        }

        do {
            try await engine.startLivePreview(session)
            livePreviewInfo = LivePreviewInfo(state: .running)
            await syncLiveFrameFromEngine()
            await syncLiveVisibility()
            isLiveLoading = false
            staleLivePreviewMessage = nil
        } catch {
            fallbackToImage(reason: error.localizedDescription)
        }
    }

    private func hideLivePreviewInternal() async {
        guard let session = self.session, let engine = self.engine else { return }
        try? await engine.hideLivePreview(session)
        livePreviewInfo = LivePreviewInfo(
            state: .available,
            hostWindowNumber: livePreviewInfo.hostWindowNumber
        )
    }

    private func showLivePreviewInternal() async {
        guard let session = self.session, let engine = self.engine else { return }
        guard liveCanvasService.shouldShowLiveWindow else { return }
        try? await engine.showLivePreview(session)
    }

    private func stopLiveInternal() {
        liveCanvasService.cancelPendingFrameSync()

        guard let session = self.session, let engine = self.engine else {
            return
        }

        Task {
            try? await engine.stopLivePreview(session)
        }

        livePreviewInfo = LivePreviewInfo(
            state: .available,
            hostWindowNumber: nil
        )
    }

    // MARK: - Live Reload

    private func liveReload(session: any PreviewSession, engine: LivePreviewEngine) {
        let refreshFileKey = activeFileKey
        let refreshPreviewID = selectedPreviewID
        refreshTask = Task {
            do {
                if let selectedPreview,
                   let liveSession = session as? LivePreviewSession {
                    await liveSession.updateDiscovery(selectedPreview)
                }
                try await engine.refreshPreview(session)
                guard activeFileKey == refreshFileKey,
                      selectedPreviewID == refreshPreviewID else {
                    return
                }
                await syncSessionState(from: session)
                await syncLiveFrameFromEngine()
                await syncLiveVisibility()
                staleLivePreviewMessage = nil
                finishRefresh()
            } catch let error as PreviewError {
                guard activeFileKey == refreshFileKey,
                      selectedPreviewID == refreshPreviewID else {
                    return
                }
                markStaleLivePreview(errorMessage: EditorPreviewFormatter.message(for: error))
                finishRefresh()
            } catch {
                guard activeFileKey == refreshFileKey,
                      selectedPreviewID == refreshPreviewID else {
                    return
                }
                markStaleLivePreview(errorMessage: error.localizedDescription)
                finishRefresh()
            }
        }
    }

    private func finishRefresh() {
        refreshTask = nil
        if hasPendingRefreshAfterCurrent {
            hasPendingRefreshAfterCurrent = false
            scheduleSourceRefresh()
        } else {
            updatePhase = .idle
        }
    }

    private func markStaleLivePreview(errorMessage: String) {
        runState = .failed(errorMessage)
        renderMessage = errorMessage
        staleLivePreviewMessage = String(
            localized: "Showing previous successful Live preview",
            table: "EditorPreview"
        )
    }

    // MARK: - Live Canvas Frame Sync

    /// Update the canvas rect that the live window should overlay.
    func updateLiveCanvasRect(_ rect: CGRect) {
        let newRect = rect.standardized
        liveCanvasService.updateLiveCanvasRect(rect)
        // Mirror the rect back for View binding
        liveCanvasRect = newRect
    }

    func liveCanvasFrameUnavailable() {
        liveCanvasService.liveCanvasFrameUnavailable()
        liveCanvasRect = .zero
    }

    /// Called when the panel becomes hidden or the tab switches away.
    func liveCanvasDidDisappear() {
        liveCanvasService.liveCanvasDidDisappear()
    }

    /// Called when the panel becomes visible and live mode is active.
    func liveCanvasDidAppear() {
        liveCanvasService.liveCanvasDidAppear()
    }

    /// Called when Lumi main window loses focus.
    func lumiWindowDidResignKey() {
        liveCanvasService.lumiWindowDidResignKey()
    }

    /// Called when Lumi main window gains focus.
    func lumiWindowDidBecomeKey() {
        liveCanvasService.lumiWindowDidBecomeKey()
    }

    func lumiWindowDidMiniaturizeOrClose() {
        liveCanvasService.lumiWindowDidMiniaturizeOrClose()
    }

    func previewWindowDidBecomeActive() {
        liveCanvasService.previewWindowDidBecomeActive()
    }

    func previewWindowDidBecomeInactive() {
        liveCanvasService.previewWindowDidBecomeInactive()
    }

    // MARK: - Live Canvas Service Binding

    private func bindLiveCanvasService() {
        liveCanvasService.onSyncLiveFrameFromEngine = { [weak self] in
            await self?.syncLiveFrameFromEngine()
        }
        liveCanvasService.onShowLivePreview = { [weak self] in
            await self?.showLivePreviewInternal()
        }
        liveCanvasService.onHideLivePreview = { [weak self] in
            await self?.hideLivePreviewInternal()
        }
    }

    private func syncLiveFrameFromEngine() async {
        guard displayMode == .live,
              !liveCanvasService.liveCanvasRect.isEmpty,
              let session = self.session,
              let engine = self.engine else {
            return
        }

        // liveCanvasRect is already in AppKit screen coordinates, reported by the canvas NSView.
        let rect = liveCanvasService.liveCanvasRect

        try? await engine.updateLiveFrame(
            session,
            x: Double(rect.origin.x),
            y: Double(rect.origin.y),
            width: Double(rect.width),
            height: Double(rect.height)
        )
    }

    private func syncLiveVisibility() async {
        if liveCanvasService.shouldShowLiveWindow {
            await showLivePreviewInternal()
        } else {
            await hideLivePreviewInternal()
        }
    }

    // MARK: - Fallback & Error Handling

    private func fallbackToImage(reason: String) {
        displayMode = .image
        liveCanvasService.updateDisplayMode(.image)
        livePreviewInfo = LivePreviewInfo(
            state: .failed,
            unavailableReason: reason
        )
        isLiveLoading = false
    }

    // MARK: - Session State Sync

    private func syncSessionState(from session: any PreviewSession) async {
        if let response = await session.lastRenderResponse {
            renderMessage = response.message
            renderImage = EditorPreviewFormatter.image(from: response)
            diagnostics = response.diagnostics
        }

        let metrics = await session.performanceMetrics
        performanceSummary = EditorPreviewFormatter.performanceSummary(for: metrics)

        // Sync live availability
        let liveInfo = await session.livePreviewInfo
        if liveInfo.state != .unavailable {
            livePreviewInfo = liveInfo
        }

        switch await session.state {
        case .running:
            runState = .running
        case .failed(let error):
            runState = .failed(EditorPreviewFormatter.message(for: error))
        case .stopped:
            runState = .stopped
        case .planning, .compiling, .launching:
            runState = .starting
        }
    }

    private func applyPreferredDisplayModeIfNeeded() async {
        guard Self.preferredDisplayMode == .live,
              runState == .running else {
            return
        }

        guard livePreviewInfo.state == .available || livePreviewInfo.state == .running else {
            fallbackToImage(
                reason: liveUnavailableReason
                    ?? String(localized: "Live preview is not available", table: "EditorPreview")
            )
            return
        }

        displayMode = .live
        liveCanvasService.updateDisplayMode(.live)
        isLiveLoading = true
        await startLivePreview()
    }

    private func resetPreviewState() {
        previews = []
        selectedPreviewID = nil
        runState = .idle
        renderMessage = nil
        renderImage = nil
        diagnostics = nil
        performanceSummary = nil
        displayMode = Self.preferredDisplayMode
        liveCanvasService.updateDisplayMode(displayMode)
        livePreviewInfo = LivePreviewInfo()
        isLiveLoading = false
        staleLivePreviewMessage = nil
        updatePhase = .idle
        session = nil
        engine = nil
    }

    private func apply(_ context: PreviewContext) {
        previews = context.previews
        selectedPreviewID = context.selectedPreviewID
        runState = context.runState
        renderMessage = context.renderMessage
        renderImage = context.renderImage
        diagnostics = context.diagnostics
        performanceSummary = context.performanceSummary
        displayMode = context.displayMode
        liveCanvasService.updateDisplayMode(displayMode)
        livePreviewInfo = context.livePreviewInfo
        isLiveLoading = context.isLiveLoading
        updatePhase = context.updatePhase
        staleLivePreviewMessage = context.staleLivePreviewMessage
        session = context.session
        engine = context.engine
    }

    private func stopActiveSessionForReplacement() {
        sourceRefreshTask?.cancel()
        sourceRefreshTask = nil
        refreshTask?.cancel()
        refreshTask = nil
        hasPendingRefreshAfterCurrent = false
        liveCanvasService.cancelPendingFrameSync()

        if let session, let engine {
            Task {
                await engine.stopPreview(session)
            }
        }

        session = nil
        engine = nil
        livePreviewInfo = LivePreviewInfo()
        isLiveLoading = false
        staleLivePreviewMessage = nil
        updatePhase = .idle
        renderMessage = nil
        renderImage = nil
        diagnostics = nil
        performanceSummary = nil
        displayMode = Self.preferredDisplayMode
        liveCanvasService.updateDisplayMode(displayMode)
        runState = .stopped
    }

    private func scheduleSourceRefresh() {
        guard updatePhase != .refreshing else {
            hasPendingRefreshAfterCurrent = true
            return
        }
        sourceRefreshTask?.cancel()
        let refreshFileKey = activeFileKey
        let refreshPreviewID = selectedPreviewID
        updatePhase = .waitingToRefresh

        sourceRefreshTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard self.activeFileKey == refreshFileKey,
                      self.selectedPreviewID == refreshPreviewID,
                      (self.runState == .running || self.staleLivePreviewMessage != nil),
                      self.session != nil else {
                    if self.activeFileKey == refreshFileKey,
                       self.selectedPreviewID == refreshPreviewID {
                        self.updatePhase = .idle
                    }
                    return
                }
                self.refreshPreview()
            }
        }
    }

    private func stopEvictedContexts(_ contexts: [PreviewContext]) {
        for context in contexts {
            guard let session = context.session,
                  let engine = context.engine else { continue }
            Task {
                await engine.stopPreview(session)
            }
        }
    }

    private static var preferredDisplayMode: PreviewDisplayMode {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: preferredDisplayModeKey),
                  let mode = PreviewDisplayMode(rawValue: rawValue) else {
                return .live
            }
            return mode
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: preferredDisplayModeKey)
        }
    }
}
#endif
