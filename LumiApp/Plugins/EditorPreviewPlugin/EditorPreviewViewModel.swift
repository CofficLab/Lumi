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

    private let scanner = PreviewScanner()
    private var session: (any PreviewSession)?
    private var engine: LivePreviewEngine?
    private var liveFrameSyncTask: Task<Void, Never>?
    private var isStoppingLive: Bool = false

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
            previews = []
            selectedPreviewID = nil
            runState = .idle
            renderMessage = nil
            renderImage = nil
            diagnostics = nil
            performanceSummary = nil
            displayMode = Self.preferredDisplayMode
            isLiveLoading = false
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
            runState = .idle
            renderMessage = nil
            renderImage = nil
            diagnostics = nil
            performanceSummary = nil
        }
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
        guard let hostExecutableURL = EditorPreviewHostExecutableResolver.resolve() else {
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

        Task {
            do {
                let nextSession = try await engine.startPreview(selectedPreview)
                session = nextSession
                await syncSessionState(from: nextSession)
                await applyPreferredDisplayModeIfNeeded()
            } catch let error as PreviewError {
                runState = .failed(Self.message(for: error))
            } catch {
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

        Task {
            do {
                try await engine.refreshPreview(session)
                await syncSessionState(from: session)
            } catch let error as PreviewError {
                runState = .failed(Self.message(for: error))
            } catch {
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
