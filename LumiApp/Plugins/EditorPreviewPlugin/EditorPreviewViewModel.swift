#if canImport(LumiPreviewKit)
import Foundation
import LumiPreviewKit
import AppKit

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

    @Published private(set) var previews: [PreviewDiscovery] = []
    @Published var selectedPreviewID: String?
    @Published private(set) var runState: RunState = .idle
    @Published private(set) var renderMessage: String?
    @Published private(set) var renderImage: NSImage?
    @Published private(set) var performanceSummary: String?

    private let scanner = PreviewScanner()
    private var session: (any PreviewSession)?
    private var engine: LivePreviewEngine?

    var selectedPreview: PreviewDiscovery? {
        if let selectedPreviewID,
           let selected = previews.first(where: { $0.id == selectedPreviewID }) {
            return selected
        }
        return previews.first
    }

    var canStart: Bool {
        selectedPreview != nil && runState != .starting
    }

    var canRefresh: Bool {
        session != nil && runState == .running
    }

    var canStop: Bool {
        session != nil
    }

    func update(sourceText: String?, fileURL: URL?) {
        guard let sourceText,
              let fileURL,
              fileURL.pathExtension == "swift" else {
            previews = []
            selectedPreviewID = nil
            runState = .idle
            renderMessage = nil
            renderImage = nil
            performanceSummary = nil
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
            performanceSummary = nil
        }
    }

    func startSelectedPreview() {
        guard let selectedPreview else { return }
        guard let hostExecutableURL = EditorPreviewHostExecutableResolver.resolve() else {
            runState = .hostMissing
            return
        }

        let engine = LivePreviewEngine(hostExecutableURL: hostExecutableURL)
        self.engine = engine
        runState = .starting

        Task {
            do {
                let nextSession = try await engine.startPreview(selectedPreview)
                session = nextSession

                await updateRenderSurface(from: nextSession)
            } catch let error as PreviewError {
                runState = .failed(Self.message(for: error))
            } catch {
                runState = .failed(error.localizedDescription)
            }
        }
    }

    func refreshPreview() {
        guard let session, let engine else { return }
        runState = .starting

        Task {
            do {
                try await engine.refreshPreview(session)
                await updateRenderSurface(from: session)
            } catch let error as PreviewError {
                runState = .failed(Self.message(for: error))
            } catch {
                runState = .failed(error.localizedDescription)
            }
        }
    }

    func stopPreview() {
        guard let session, let engine else {
            runState = .stopped
            return
        }

        Task {
            await engine.stopPreview(session)
            self.session = nil
            self.engine = nil
            runState = .stopped
            renderMessage = nil
            renderImage = nil
            performanceSummary = nil
        }
    }

    private func updateRenderSurface(from session: any PreviewSession) async {
        if let response = await session.lastRenderResponse {
            renderMessage = response.message
            renderImage = Self.image(from: response)
        }

        let metrics = await session.performanceMetrics
        performanceSummary = Self.performanceSummary(for: metrics)

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

    private static func message(for error: PreviewError) -> String {
        switch error {
        case .targetNotFound(let file):
            String(localized: "No build target found for %@", table: "EditorPreview", arguments: [URL(fileURLWithPath: file).lastPathComponent])
        case .unsupportedProjectType(let path):
            String(localized: "Unsupported project type: %@", table: "EditorPreview", arguments: [path])
        case .compilationFailed(let message):
            message
        case .buildProductNotFound:
            String(localized: "Build product was not found.", table: "EditorPreview")
        case .hostLaunchFailed(let message):
            message
        case .runtimeCrashed(let message):
            message
        case .timedOut(let seconds):
            String(localized: "Timed out after %lld seconds.", table: "EditorPreview", arguments: [Int(seconds)])
        case .missingDependency(let description):
            description
        }
    }

    private static func performanceSummary(for metrics: PreviewPerformanceMetrics) -> String? {
        var parts: [String] = []
        if let compileDuration = metrics.lastCompileDuration {
            let cacheSuffix = metrics.lastCompileUsedCache ? String(localized: " cached", table: "EditorPreview") : ""
            parts.append(String(localized: "Build %@%@", table: "EditorPreview", arguments: [format(seconds: compileDuration), cacheSuffix]))
        }
        if let refreshDuration = metrics.lastRefreshDuration {
            parts.append(String(localized: "Refresh %@", table: "EditorPreview", arguments: [format(seconds: refreshDuration)]))
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
