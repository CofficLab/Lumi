#if canImport(LumiPreviewKit)
import Foundation
import LumiPreviewKit
import AppKit
import SwiftUI

@MainActor
final class EditorPreviewViewModel: ObservableObject {
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
        var session: (any PreviewSession)?
        var engine: LivePreviewEngine?
    }

    private let scanner = PreviewScanner()
    private var session: (any PreviewSession)?
    private var engine: LivePreviewEngine?
    private var liveFrameSyncTask: Task<Void, Never>?
    private var sourceRefreshTask: Task<Void, Never>?
    private var isStoppingLive: Bool = false
    private var activeFileKey: String?
    private var cachedContexts = PreviewFileContextCache<PreviewContext>(maximumCount: 4)

    init() {
        displayMode = Self.preferredDisplayMode
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
        session != nil && runState == .running
    }

    var canStop: Bool {
        session != nil
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
                    liveCanvasDidAppear()
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
        let shouldRefreshRunningPreview = runState == .running && session != nil

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
        isLiveLoading = displayMode == .live
        livePreviewInfo = LivePreviewInfo()
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
                runState = .failed(Self.message(for: error))
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

        // If in live mode, do live reload
        if displayMode == .live {
            liveReload()
            return
        }

        runState = .starting

        Task {
            do {
                if let selectedPreview,
                   let liveSession = session as? LivePreviewSession {
                    await liveSession.updateDiscovery(selectedPreview)
                }
                try await engine.refreshPreview(session)
                await syncSessionState(from: session)
            } catch let error as PreviewError {
                runState = .failed(Self.message(for: error))
            } catch {
                runState = .failed(error.localizedDescription)
            }
        }
    }

    func stopPreview() {
        isStoppingLive = true
        sourceRefreshTask?.cancel()
        sourceRefreshTask = nil
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
            isLiveLoading = false
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
        isLiveLoading = false
        livePreviewInfo = LivePreviewInfo()

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
        isLiveLoading = true

        Task {
            await startLivePreview()
        }
    }

    func switchToImage() {
        Self.preferredDisplayMode = .image
        guard canSwitchToImage else { return }
        displayMode = .image

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
            try? await engine.showLivePreview(session)
            isLiveLoading = false
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
        try? await engine.showLivePreview(session)
    }

    private func stopLiveInternal() {
        liveFrameSyncTask?.cancel()
        liveFrameSyncTask = nil

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

    private func liveReload() {
        guard let session, let engine else { return }
        runState = .starting

        let refreshFileKey = activeFileKey
        let refreshPreviewID = selectedPreviewID
        Task {
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
                try? await engine.showLivePreview(session)
            } catch let error as PreviewError {
                guard activeFileKey == refreshFileKey,
                      selectedPreviewID == refreshPreviewID else {
                    return
                }
                runState = .failed(Self.message(for: error))
            } catch {
                guard activeFileKey == refreshFileKey,
                      selectedPreviewID == refreshPreviewID else {
                    return
                }
                runState = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: - Live Canvas Frame Sync

    /// Update the canvas rect that the live window should overlay.
    func updateLiveCanvasRect(_ rect: CGRect) {
        let newRect = rect.standardized
        guard abs(newRect.origin.x - liveCanvasRect.origin.x) > 0.5
            || abs(newRect.origin.y - liveCanvasRect.origin.y) > 0.5
            || abs(newRect.size.width - liveCanvasRect.size.width) > 0.5
            || abs(newRect.size.height - liveCanvasRect.size.height) > 0.5 else {
            return
        }

        liveCanvasRect = newRect

        // Debounce frame sync
        liveFrameSyncTask?.cancel()
        liveFrameSyncTask = Task {
            try? await Task.sleep(nanoseconds: 16_000_000) // ~1 frame at 60fps
            guard !Task.isCancelled else { return }
            await syncLiveFrameFromEngine()
        }
    }

    /// Called when the panel becomes hidden or the tab switches away.
    func liveCanvasDidDisappear() {
        guard displayMode == .live else { return }
        Task {
            await hideLivePreviewInternal()
        }
    }

    /// Called when the panel becomes visible and live mode is active.
    func liveCanvasDidAppear() {
        guard displayMode == .live else { return }
        Task {
            await syncLiveFrameFromEngine()
            await showLivePreviewInternal()
        }
    }

    /// Called when Lumi main window loses focus.
    func lumiWindowDidResignKey() {
        guard displayMode == .live else { return }
        Task {
            await hideLivePreviewInternal()
        }
    }

    /// Called when Lumi main window gains focus.
    func lumiWindowDidBecomeKey() {
        guard displayMode == .live else { return }
        Task {
            await syncLiveFrameFromEngine()
            await showLivePreviewInternal()
        }
    }

    private func syncLiveFrameFromEngine() async {
        guard displayMode == .live,
              !liveCanvasRect.isEmpty,
              let session = self.session,
              let engine = self.engine else {
            return
        }

        // liveCanvasRect is already in AppKit screen coordinates, reported by the canvas NSView.
        let rect = liveCanvasRect

        try? await engine.updateLiveFrame(
            session,
            x: Double(rect.origin.x),
            y: Double(rect.origin.y),
            width: Double(rect.width),
            height: Double(rect.height)
        )
    }

    // MARK: - Fallback & Error Handling

    private func fallbackToImage(reason: String) {
        displayMode = .image
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
            renderImage = Self.image(from: response)
            diagnostics = response.diagnostics
        }

        let metrics = await session.performanceMetrics
        performanceSummary = Self.performanceSummary(for: metrics)

        // Sync live availability
        let liveInfo = await session.livePreviewInfo
        if liveInfo.state != .unavailable {
            livePreviewInfo = liveInfo
        }

        switch await session.state {
        case .running:
            runState = .running
        case .failed(let error):
            runState = .failed(Self.message(for: error))
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
        livePreviewInfo = LivePreviewInfo()
        isLiveLoading = false
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
        livePreviewInfo = context.livePreviewInfo
        isLiveLoading = context.isLiveLoading
        session = context.session
        engine = context.engine
    }

    private func stopActiveSessionForReplacement() {
        sourceRefreshTask?.cancel()
        sourceRefreshTask = nil
        liveFrameSyncTask?.cancel()
        liveFrameSyncTask = nil

        if let session, let engine {
            Task {
                await engine.stopPreview(session)
            }
        }

        session = nil
        engine = nil
        livePreviewInfo = LivePreviewInfo()
        isLiveLoading = false
        renderMessage = nil
        renderImage = nil
        diagnostics = nil
        performanceSummary = nil
        displayMode = Self.preferredDisplayMode
        runState = .stopped
    }

    private func scheduleSourceRefresh() {
        sourceRefreshTask?.cancel()
        let refreshFileKey = activeFileKey
        let refreshPreviewID = selectedPreviewID

        sourceRefreshTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard self.activeFileKey == refreshFileKey,
                      self.selectedPreviewID == refreshPreviewID,
                      self.runState == .running,
                      self.session != nil else {
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

    // MARK: - Error Formatting

    private static func message(for error: PreviewError) -> String {
        switch error {
        case .targetNotFound(let file):
            String(
                format: String(localized: "No build target found for %@", table: "EditorPreview"),
                URL(fileURLWithPath: file).lastPathComponent
            )
        case .unsupportedProjectType(let path):
            String(
                format: String(localized: "Unsupported project type: %@", table: "EditorPreview"),
                path
            )
        case .compilationFailed(let message):
            message
        case .buildProductNotFound:
            String(localized: "Build product was not found.", table: "EditorPreview")
        case .hostLaunchFailed(let message):
            message
        case .runtimeCrashed(let message):
            message
        case .timedOut(let seconds):
            String(
                format: String(localized: "Timed out after %lld seconds.", table: "EditorPreview"),
                Int64(seconds)
            )
        case .missingDependency(let description):
            description
        }
    }

    private static func performanceSummary(for metrics: PreviewPerformanceMetrics) -> String? {
        var parts: [String] = []
        if let compileDuration = metrics.lastCompileDuration {
            let cacheSuffix = metrics.lastCompileUsedCache ? String(localized: " cached", table: "EditorPreview") : ""
            parts.append(
                String(
                    format: String(localized: "Build %@%@", table: "EditorPreview"),
                    format(seconds: compileDuration),
                    cacheSuffix
                )
            )
        }
        if let refreshDuration = metrics.lastRefreshDuration {
            parts.append(
                String(
                    format: String(localized: "Refresh %@", table: "EditorPreview"),
                    format(seconds: refreshDuration)
                )
            )
        }
        return parts.isEmpty ? nil : parts.joined(separator: " | ")
    }

    private static func format(seconds: TimeInterval) -> String {
        String(format: "%.2fs", seconds)
    }

    private static func image(from response: RenderResponse) -> NSImage? {
        guard let previewImagePNGBase64 = response.previewImagePNGBase64,
              let data = Data(base64Encoded: previewImagePNGBase64) else {
            return nil
        }

        return NSImage(data: data)
    }
}
#endif
