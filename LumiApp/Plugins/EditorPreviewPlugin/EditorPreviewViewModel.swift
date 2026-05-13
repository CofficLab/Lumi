import Foundation
import MagicKit
import LumiPreviewKit
import AppKit
import SwiftUI
import os

@MainActor
final class EditorPreviewViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "🧊"
    nonisolated static let verbose = false

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

    enum CanvasSizePreset: String, CaseIterable, Identifiable {
        case automatic
        case compact
        case regular
        case phone

        var id: String { rawValue }

        var title: String {
            switch self {
            case .automatic:
                String(localized: "Auto", table: "EditorPreview")
            case .compact:
                String(localized: "Compact", table: "EditorPreview")
            case .regular:
                String(localized: "Regular", table: "EditorPreview")
            case .phone:
                String(localized: "Phone", table: "EditorPreview")
            }
        }

        var fixedSize: CGSize? {
            switch self {
            case .automatic:
                nil
            case .compact:
                CGSize(width: 320, height: 240)
            case .regular:
                CGSize(width: 768, height: 480)
            case .phone:
                CGSize(width: 393, height: 852)
            }
        }
    }

    // MARK: - Supported File Extensions

    /// Image file extensions supported for inline preview.
    /// Uses macOS native NSImage support: PNG, JPEG, GIF, TIFF, BMP, WebP, SVG, ICNS, ICO, HEIC.
    private static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "tiff", "tif", "bmp", "webp",
        "svg", "icns", "ico", "heic", "heif"
    ]

    /// Markdown file extensions supported for inline rendering.
    private static let markdownExtensions: Set<String> = ["md", "markdown"]

    // MARK: - Published State

    @Published private(set) var previews: [LumiPreviewPackage.PreviewDiscovery] = []
    @Published var selectedPreviewID: String?
    @Published private(set) var runState: RunState = .idle
    @Published private(set) var renderMessage: String?
    @Published private(set) var renderImage: NSImage?
    @Published private(set) var diagnostics: String?
    @Published private(set) var performanceSummary: String?
    @Published private(set) var displayMode: LumiPreviewPackage.PreviewDisplayMode = .live
    @Published private(set) var livePreviewInfo: LumiPreviewPackage.LivePreviewInfo = LumiPreviewPackage.LivePreviewInfo()
    @Published private(set) var liveCanvasRect: CGRect = .zero
    @Published private(set) var isLiveLoading: Bool = false
    @Published private(set) var updatePhase: UpdatePhase = .idle
    @Published private(set) var staleLivePreviewMessage: String?
    @Published var canvasScale: CGFloat = 1
    @Published var isCanvasScaleToFit: Bool = true
    @Published private(set) var canvasSizePreset: CanvasSizePreset = .automatic

    /// Whether the current file is a Markdown file and should render inline.
    @Published private(set) var isMarkdownMode: Bool = false

    /// Markdown source text for inline rendering.
    @Published private(set) var markdownSource: String?

    /// Whether the current file is an image and should render as image preview.
    /// Supports: PNG, JPEG, GIF, TIFF, BMP, WebP, SVG, ICNS, ICO, HEIC, HEIF.
    @Published private(set) var isImageMode: Bool = false

    /// Image file URL for preview rendering.
    @Published private(set) var imageFileURL: URL?

    // MARK: - Private State

    private static let preferredDisplayModeKey = "EditorPreviewPlugin.preferredDisplayMode"
    private static let preferredCanvasSizePresetKey = "EditorPreviewPlugin.preferredCanvasSizePreset"
    private struct PreviewContext {
        var previews: [LumiPreviewPackage.PreviewDiscovery]
        var selectedPreviewID: String?
        var runState: RunState
        var renderMessage: String?
        var renderImage: NSImage?
        var diagnostics: String?
        var performanceSummary: String?
        var displayMode: LumiPreviewPackage.PreviewDisplayMode
        var livePreviewInfo: LumiPreviewPackage.LivePreviewInfo
        var isLiveLoading: Bool
        var updatePhase: UpdatePhase
        var staleLivePreviewMessage: String?
        var session: (any LumiPreviewPackage.PreviewSession)?
        var engine: LumiPreviewPackage.LivePreviewEngine?
    }

    private struct LivePreviewHideTarget {
        var session: any LumiPreviewPackage.PreviewSession
        var engine: LumiPreviewPackage.LivePreviewEngine
        var updatesCurrentInfo: Bool
    }

    private let scanner = LumiPreviewPackage.PreviewScanner()
    private var session: (any LumiPreviewPackage.PreviewSession)?
    private var engine: LumiPreviewPackage.LivePreviewEngine?
    private var sourceRefreshTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var hasPendingRefreshAfterCurrent: Bool = false
    private var isStoppingLive: Bool = false
    private var activeFileKey: String?
    private var cachedContexts = LumiPreviewPackage.PreviewFileContextCache<PreviewContext>(maximumCount: 4)
    private let liveCanvasService: LumiPreviewPackage.EditorPreviewLiveCanvasService
    private var livePreviewHideTarget: LivePreviewHideTarget?
    private var isLivePreviewShown = false

    init() {
        let preferredDisplayMode = Self.preferredDisplayMode
        displayMode = preferredDisplayMode
        canvasSizePreset = Self.preferredCanvasSizePreset
        liveCanvasService = LumiPreviewPackage.EditorPreviewLiveCanvasService(displayMode: preferredDisplayMode)
        bindLiveCanvasService()
    }

    // MARK: - Computed Properties

    var selectedPreview: LumiPreviewPackage.PreviewDiscovery? {
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

    var diagnosticSummary: String {
        var lines: [String] = [
            "mode: \(displayMode.rawValue)",
            "runState: \(runState.title)",
            "updatePhase: \(updatePhase.title.isEmpty ? "idle" : updatePhase.title)",
            "liveState: \(livePreviewInfo.state.rawValue)",
            "canvasPreset: \(canvasSizePreset.rawValue)",
            "canvasScale: \(isCanvasScaleToFit ? "fit" : String(format: "%.0f%%", canvasScale * 100))",
            "hostPID: \(livePreviewInfo.hostProcessID.map(String.init) ?? "-")",
            "window: \(livePreviewInfo.hostWindowNumber.map(String.init) ?? "-")",
            String(
                format: "frame: %.1f, %.1f, %.1f x %.1f",
                liveCanvasRect.origin.x,
                liveCanvasRect.origin.y,
                liveCanvasRect.width,
                liveCanvasRect.height
            )
        ]
        if let selectedPreviewID {
            lines.append("previewID: \(selectedPreviewID)")
        }
        if let renderMessage {
            lines.append("message: \(renderMessage)")
        }
        if let diagnostics {
            lines.append("diagnostics: \(diagnostics.prefix(500))")
        }
        return lines.joined(separator: "\n")
    }

    func setCanvasScaleToFit() {
        isCanvasScaleToFit = true
    }

    func setCanvasScale(_ scale: CGFloat) {
        isCanvasScaleToFit = false
        canvasScale = min(max(scale, 0.25), 2)
    }

    func setCanvasSizePreset(_ preset: CanvasSizePreset) {
        canvasSizePreset = preset
        Self.preferredCanvasSizePreset = preset
        EditorPreviewLiveCanvasFrameReporter.scheduleFrameUpdate()
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
        // Handle image files — render via NSImage native support
        if let fileURL, Self.imageExtensions.contains(fileURL.pathExtension.lowercased()) {
            isMarkdownMode = false
            markdownSource = nil
            isImageMode = true
            imageFileURL = fileURL
            // Stop any running SwiftUI preview session
            if session != nil {
                stopActiveSessionForReplacement(hideFirst: true)
            }
            previews = []
            selectedPreviewID = nil
            runState = .idle
            renderMessage = nil
            renderImage = nil
            diagnostics = nil
            performanceSummary = nil
            return
        }

        isImageMode = false
        imageFileURL = nil

        // Handle Markdown files — render inline, no SwiftUI preview pipeline
        if let sourceText,
           let fileURL,
           Self.markdownExtensions.contains(fileURL.pathExtension.lowercased()) {
            cacheActiveContextForFileSwitch()
            activeFileKey = nil
            isMarkdownMode = true
            markdownSource = sourceText
            // Stop any running SwiftUI preview session
            if session != nil {
                stopActiveSessionForReplacement(hideFirst: true)
            }
            previews = []
            selectedPreviewID = nil
            runState = .idle
            renderMessage = nil
            renderImage = nil
            diagnostics = nil
            performanceSummary = nil
            return
        }

        isMarkdownMode = false
        markdownSource = nil

        guard let sourceText,
              let fileURL,
              fileURL.pathExtension == "swift" else {
            cacheActiveContextForFileSwitch()
            activeFileKey = nil
            resetPreviewState()
            return
        }

        let nextFileKey = LumiPreviewPackage.PreviewFileContextCache<PreviewContext>.key(for: fileURL)
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

        stopActiveSessionForReplacement(hideFirst: true)
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
        // Image files — just update the file URL, NSImage reloads via task(id:)
        if let fileURL,
           Self.imageExtensions.contains(fileURL.pathExtension.lowercased()) {
            update(sourceText: sourceText, fileURL: fileURL)
            return
        }

        // Markdown files update live — no compile/refresh cycle needed
        if let fileURL,
           Self.markdownExtensions.contains(fileURL.pathExtension.lowercased()) {
            update(sourceText: sourceText, fileURL: fileURL)
            return
        }

        let previousPreviewID = selectedPreviewID
        let hadRefreshableSessionBeforeUpdate = (runState == .running || staleLivePreviewMessage != nil) && session != nil

        update(sourceText: sourceText, fileURL: fileURL)

        guard LumiPreviewPackage.EditorPreviewRefreshPolicy.shouldScheduleRefresh(
            previousPreviewID: previousPreviewID,
            currentPreviewID: selectedPreviewID,
            hadRefreshableSessionBeforeUpdate: hadRefreshableSessionBeforeUpdate,
            isRunningAfterUpdate: runState == .running,
            hasSessionAfterUpdate: session != nil
        ) else {
            return
        }

        scheduleSourceRefresh()
    }

    func selectPreview(id: String?) {
        guard selectedPreviewID != id else { return }
        stopActiveSessionForReplacement(hideFirst: true)
        selectedPreviewID = id
        guard id != nil else { return }
        startSelectedPreviewIfNeeded()
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
        guard let hostExecutableURL = LumiPreviewPackage.PreviewHostExecutableResolver.resolve() else {
            runState = .hostMissing
            return
        }

        let engine = LumiPreviewPackage.LivePreviewEngine(hostExecutableURL: hostExecutableURL)
        self.engine = engine
        renderMessage = nil
        renderImage = nil
        diagnostics = nil
        performanceSummary = nil
        displayMode = Self.preferredDisplayMode
        canvasSizePreset = Self.preferredCanvasSizePreset
        liveCanvasService.updateDisplayMode(displayMode)
        isLiveLoading = displayMode == .live
        livePreviewInfo = LumiPreviewPackage.LivePreviewInfo()
        isLivePreviewShown = false
        staleLivePreviewMessage = nil
        runState = .starting

        let startedFileKey = activeFileKey
        let startedPreviewID = selectedPreview.id
        if Self.verbose {
            EditorPreviewPlugin.logger.info("\(self.t)Starting preview: \(selectedPreview.title, privacy: .public)")
        }
        Task {
            do {
                let nextSession = try await engine.startPreview(selectedPreview)
                guard activeFileKey == startedFileKey,
                      selectedPreviewID == startedPreviewID else {
                    if Self.verbose {
                        EditorPreviewPlugin.logger.info("\(Self.t)Stale start result, discarding session")
                    }
                    await engine.stopPreview(nextSession)
                    return
                }
                session = nextSession
                await syncSessionState(from: nextSession)
                await applyPreferredDisplayModeIfNeeded()
            } catch let error as LumiPreviewPackage.PreviewError {
                guard activeFileKey == startedFileKey,
                      selectedPreviewID == startedPreviewID else {
                    return
                }
                EditorPreviewPlugin.logger.error("\(self.t)Start failed: \(EditorPreviewFormatter.message(for: error), privacy: .public)")
                runState = .failed(EditorPreviewFormatter.message(for: error))
            } catch {
                guard activeFileKey == startedFileKey,
                      selectedPreviewID == startedPreviewID else {
                    return
                }
                EditorPreviewPlugin.logger.error("\(self.t)Start failed: \(error.localizedDescription, privacy: .public)")
                runState = .failed(error.localizedDescription)
            }
        }
    }

    func refreshPreview(reason: String = "manual refresh") {
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
            liveReload(session: session, engine: engine, reason: reason)
            return
        }

        runState = .starting

        let refreshFileKey = activeFileKey
        let refreshPreviewID = selectedPreviewID
        refreshTask = Task {
            do {
                if let selectedPreview,
                   let liveSession = session as? LumiPreviewPackage.LivePreviewSession {
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
            } catch let error as LumiPreviewPackage.PreviewError {
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
        if let activeFileKey,
           let cachedActiveContext = cachedContexts.removeValue(forKey: activeFileKey) {
            stopEvictedContexts([cachedActiveContext])
        }
        stopCachedContexts()

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
            canvasSizePreset = Self.preferredCanvasSizePreset
            liveCanvasService.updateDisplayMode(displayMode)
            isLiveLoading = false
            staleLivePreviewMessage = nil
            updatePhase = .idle
            isLivePreviewShown = false
            isStoppingLive = false
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
        canvasSizePreset = Self.preferredCanvasSizePreset
        liveCanvasService.updateDisplayMode(displayMode)
        isLiveLoading = false
        livePreviewInfo = LumiPreviewPackage.LivePreviewInfo()
        staleLivePreviewMessage = nil
        updatePhase = .idle
        isLivePreviewShown = false

        Task {
            await engine.stopPreview(session)
            isStoppingLive = false
        }
    }

    func previewPanelDidDisappear() {
        liveCanvasDidDisappear()
        stopCachedContexts()
        guard session != nil else { return }
        stopPreview()
    }

    func applicationWillTerminate() {
        stopCachedContexts()
        guard session != nil else { return }
        stopPreview()
    }

    func cacheActiveContextForFileSwitch() {
        guard let activeFileKey else { return }

        if displayMode == .live,
           let cachedSession = session,
           let cachedEngine = engine {
            Task {
                await requestLivePreviewHide(
                    session: cachedSession,
                    engine: cachedEngine,
                    reason: "caching active preview context for file switch",
                    updatesCurrentInfo: false
                )
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
            await liveCanvasService.syncLiveVisibility(
                showReason: "switched display mode to image but display conditions still allow showing",
                hideReason: "switched display mode to image"
            )
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
            livePreviewInfo = LumiPreviewPackage.LivePreviewInfo(state: .running)
            await syncSessionState(from: session)
            await syncLiveFrameFromEngine(reason: "live preview started")
            await liveCanvasService.syncLiveVisibility(
                showReason: "live preview started",
                hideReason: "live preview started but display conditions are not satisfied"
            )
            isLiveLoading = false
            staleLivePreviewMessage = nil
        } catch {
            fallbackToImage(reason: error.localizedDescription)
        }
    }

    private func hideLivePreviewInternal(reason: String) async {
        let target = livePreviewHideTarget
        guard let session = target?.session ?? self.session,
              let engine = target?.engine ?? self.engine else { return }
        if Self.verbose {
            EditorPreviewPlugin.logger.info("\(self.t)Hiding live preview: \(reason, privacy: .public)")
        }
        try? await engine.hideLivePreview(session)
        isLivePreviewShown = false
        if target?.updatesCurrentInfo ?? true {
            livePreviewInfo = LumiPreviewPackage.LivePreviewInfo(
                state: .available,
                hostWindowNumber: livePreviewInfo.hostWindowNumber,
                hostProcessID: livePreviewInfo.hostProcessID
            )
        }
    }

    private func showLivePreviewInternal(reason: String) async {
        guard let session = self.session, let engine = self.engine else { return }
        guard liveCanvasService.shouldShowLiveWindow else { return }
        guard !isLivePreviewShown else {
            EditorPreviewPlugin.logger.debug("\(self.t)Skipping live preview show because it is already shown: \(reason, privacy: .public)")
            return
        }
        EditorPreviewPlugin.logger.info("\(self.t)Showing live preview: \(reason, privacy: .public)")
        do {
            try await engine.showLivePreview(session)
            isLivePreviewShown = true
        } catch {
            EditorPreviewPlugin.logger.error("\(self.t)Failed to show live preview: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func stopLiveInternal() {
        liveCanvasService.cancelPendingFrameSync()

        guard let session = self.session, let engine = self.engine else {
            return
        }

        Task {
            await requestLivePreviewHide(
                session: session,
                engine: engine,
                reason: "stopping live preview",
                updatesCurrentInfo: true
            )
            try? await engine.stopLivePreview(session)
        }

        livePreviewInfo = LumiPreviewPackage.LivePreviewInfo(
            state: .available,
            hostWindowNumber: nil,
            hostProcessID: livePreviewInfo.hostProcessID
        )
        isLivePreviewShown = false
    }

    // MARK: - Live Reload

    private func liveReload(session: any LumiPreviewPackage.PreviewSession, engine: LumiPreviewPackage.LivePreviewEngine, reason: String) {
        let refreshFileKey = activeFileKey
        let refreshPreviewID = selectedPreviewID
        refreshTask = Task {
            do {
                EditorPreviewPlugin.logger.info("\(self.t)Refreshing live preview: \(reason, privacy: .public)")
                if let selectedPreview,
                   let liveSession = session as? LumiPreviewPackage.LivePreviewSession {
                    await liveSession.updateDiscovery(selectedPreview)
                }
                try await engine.refreshPreview(session)
                guard activeFileKey == refreshFileKey,
                      selectedPreviewID == refreshPreviewID else {
                    return
                }
                await syncSessionState(from: session)
                await syncLiveFrameFromEngine(reason: "live reload finished: \(reason)")
                await liveCanvasService.syncLiveVisibility(
                    showReason: "live reload finished: \(reason)",
                    hideReason: "live reload finished but display conditions are not satisfied: \(reason)"
                )
                staleLivePreviewMessage = nil
                finishRefresh()
            } catch let error as LumiPreviewPackage.PreviewError {
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
    func updateLiveCanvasRect(_ rect: CGRect, scale: CGFloat = 1) {
        let newRect = rect.standardized
        liveCanvasService.updateLiveCanvasRect(rect, scale: scale)
        // Mirror the rect back for View binding
        liveCanvasRect = newRect
    }

    func liveCanvasFrameUnavailable() {
        liveCanvasService.liveCanvasFrameUnavailable()
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
        liveCanvasService.onSyncLiveFrameFromEngine = { [weak self] reason in
            await self?.syncLiveFrameFromEngine(reason: reason)
        }
        liveCanvasService.onShowLivePreview = { [weak self] reason in
            await self?.showLivePreviewInternal(reason: reason)
        }
        liveCanvasService.onHideLivePreview = { [weak self] reason in
            await self?.hideLivePreviewInternal(reason: reason)
        }
    }

    private func syncLiveFrameFromEngine(reason: String) async {
        guard displayMode == .live,
              !liveCanvasService.liveCanvasRect.isEmpty,
              let session = self.session,
              let engine = self.engine else {
            return
        }

        // liveCanvasRect is already in AppKit screen coordinates, reported by the canvas NSView.
        let rect = liveCanvasService.liveCanvasRect
        EditorPreviewPlugin.logger.info("\(self.t)Syncing live preview frame: \(reason, privacy: .public)")

        try? await engine.updateLiveFrame(
            session,
            x: Double(rect.origin.x),
            y: Double(rect.origin.y),
            width: Double(rect.width),
            height: Double(rect.height),
            scale: Double(liveCanvasService.liveCanvasScale)
        )
    }

    // MARK: - Fallback & Error Handling

    private func fallbackToImage(reason: String) {
        let hideSession = session
        let hideEngine = engine
        displayMode = .image
        liveCanvasService.updateDisplayMode(.image)
        isLivePreviewShown = false
        if let hideSession, let hideEngine {
            Task {
                await requestLivePreviewHide(
                    session: hideSession,
                    engine: hideEngine,
                    reason: "fallback to image: \(reason)",
                    updatesCurrentInfo: false
                )
            }
        } else {
            Task {
                await liveCanvasService.syncLiveVisibility(
                    showReason: "fallback to image but display conditions still allow showing: \(reason)",
                    hideReason: "fallback to image: \(reason)"
                )
            }
        }
        livePreviewInfo = LumiPreviewPackage.LivePreviewInfo(
            state: .failed,
            unavailableReason: reason
        )
        isLiveLoading = false
    }

    // MARK: - Session State Sync

    private func syncSessionState(from session: any LumiPreviewPackage.PreviewSession) async {
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
        canvasSizePreset = Self.preferredCanvasSizePreset
        liveCanvasService.updateDisplayMode(displayMode)
        livePreviewInfo = LumiPreviewPackage.LivePreviewInfo()
        isLiveLoading = false
        staleLivePreviewMessage = nil
        updatePhase = .idle
        session = nil
        engine = nil
        isLivePreviewShown = false
        isMarkdownMode = false
        markdownSource = nil
        isImageMode = false
        imageFileURL = nil
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
        isLivePreviewShown = false
    }

    private func stopActiveSessionForReplacement(hideFirst: Bool = false) {
        sourceRefreshTask?.cancel()
        sourceRefreshTask = nil
        refreshTask?.cancel()
        refreshTask = nil
        hasPendingRefreshAfterCurrent = false
        liveCanvasService.cancelPendingFrameSync()

        if let session, let engine {
            Task {
                if hideFirst {
                    await requestLivePreviewHide(
                        session: session,
                        engine: engine,
                        reason: "replacing active preview session",
                        updatesCurrentInfo: false
                    )
                }
                await engine.stopPreview(session)
            }
        }

        session = nil
        engine = nil
        livePreviewInfo = LumiPreviewPackage.LivePreviewInfo()
        isLiveLoading = false
        staleLivePreviewMessage = nil
        updatePhase = .idle
        isLivePreviewShown = false
        renderMessage = nil
        renderImage = nil
        diagnostics = nil
        performanceSummary = nil
        displayMode = Self.preferredDisplayMode
        canvasSizePreset = Self.preferredCanvasSizePreset
        liveCanvasService.updateDisplayMode(displayMode)
        runState = .stopped
    }

    private func requestLivePreviewHide(
        session: any LumiPreviewPackage.PreviewSession,
        engine: LumiPreviewPackage.LivePreviewEngine,
        reason: String,
        updatesCurrentInfo: Bool
    ) async {
        let previousTarget = livePreviewHideTarget
        livePreviewHideTarget = LivePreviewHideTarget(
            session: session,
            engine: engine,
            updatesCurrentInfo: updatesCurrentInfo
        )
        isLivePreviewShown = false
        liveCanvasService.updateLiveCanvasVisibility(false)
        await liveCanvasService.syncLiveVisibility(
            showReason: "requested live preview hide but display conditions still allow showing: \(reason)",
            hideReason: reason
        )
        livePreviewHideTarget = previousTarget
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
                guard LumiPreviewPackage.EditorPreviewRefreshPolicy.shouldExecuteScheduledRefresh(
                    activeFileKey: self.activeFileKey,
                    expectedFileKey: refreshFileKey,
                    currentPreviewID: self.selectedPreviewID,
                    expectedPreviewID: refreshPreviewID,
                    isRunningOrShowingStalePreview: self.runState == .running || self.staleLivePreviewMessage != nil,
                    hasSession: self.session != nil
                ) else {
                    if self.activeFileKey == refreshFileKey,
                       self.selectedPreviewID == refreshPreviewID {
                        self.updatePhase = .idle
                    }
                    return
                }
                self.refreshPreview(reason: "scheduled source refresh")
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

    private func stopCachedContexts() {
        stopEvictedContexts(cachedContexts.removeAll().map(\.value))
    }

    private static var preferredDisplayMode: LumiPreviewPackage.PreviewDisplayMode {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: preferredDisplayModeKey),
                  let mode = LumiPreviewPackage.PreviewDisplayMode(rawValue: rawValue) else {
                return .live
            }
            return mode
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: preferredDisplayModeKey)
        }
    }

    private static var preferredCanvasSizePreset: CanvasSizePreset {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: preferredCanvasSizePresetKey),
                  let preset = CanvasSizePreset(rawValue: rawValue) else {
                return .automatic
            }
            return preset
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: preferredCanvasSizePresetKey)
        }
    }
}
