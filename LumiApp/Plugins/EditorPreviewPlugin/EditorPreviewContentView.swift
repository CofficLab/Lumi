#if canImport(LumiPreviewKit)
import AppKit
import LumiPreviewKit
import SwiftUI

struct EditorPreviewContentView: View {
    @EnvironmentObject private var editorVM: EditorVM
    @EnvironmentObject private var themeVM: ThemeVM
    @StateObject private var viewModel = EditorPreviewViewModel()

    private var sourceText: String? {
        editorVM.service.content?.string
    }

    private var currentFileURL: URL? {
        editorVM.service.currentFileURL
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
        .background(themeVM.activeAppTheme.workspaceBackgroundColor())
        .onAppear {
            refreshScanAndStartIfNeeded()
        }
        .onDisappear {
            viewModel.liveCanvasDidDisappear()
        }
        .onChange(of: currentFileURL) { _, _ in
            viewModel.stopPreview()
            refreshScanAndStartIfNeeded()
        }
        .onChange(of: sourceText ?? "") { _, _ in
            refreshScanAndStartIfNeeded(allowsStopped: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            viewModel.lumiWindowDidResignKey()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.lumiWindowDidBecomeKey()
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.on.rectangle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())

            Text(String(localized: "Editor Preview", table: "EditorPreview"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(themeVM.activeAppTheme.workspaceTextColor())

            if let currentFileURL {
                Text(currentFileURL.lastPathComponent)
                    .font(.system(size: 11))
                    .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
            }

            Spacer(minLength: 0)

            displayModePicker

            statusBadge

            Button {
                viewModel.startSelectedPreview()
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canStart)
            .help(String(localized: "Start preview", table: "EditorPreview"))

            Button {
                viewModel.refreshPreview()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canRefresh)
            .help(String(localized: "Refresh preview", table: "EditorPreview"))

            Button {
                viewModel.stopPreview()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canStop)
            .help(String(localized: "Stop preview", table: "EditorPreview"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.05))
    }

    private var statusBadge: some View {
        Text(viewModel.runState.title)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(statusColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(statusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
    }

    private var statusColor: Color {
        switch viewModel.runState {
        case .running:
            .green
        case .failed, .hostMissing:
            .red
        case .starting:
            .orange
        case .idle, .stopped:
            themeVM.activeAppTheme.workspaceSecondaryTextColor()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.previews.isEmpty {
            emptyState
        } else {
            HStack(spacing: 0) {
                previewList
                    .frame(width: 240)
                Divider()
                previewDetail
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "number")
                .font(.system(size: 24, weight: .thin))
                .foregroundColor(themeVM.activeAppTheme.workspaceTertiaryTextColor())
            Text(String(localized: "No #Preview macros found", table: "EditorPreview"))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
    }

    private var previewList: some View {
        List(selection: $viewModel.selectedPreviewID) {
            ForEach(viewModel.previews, id: \.id) { preview in
                VStack(alignment: .leading, spacing: 4) {
                    Text(preview.title)
                        .font(.system(size: 12, weight: .semibold))
                    Text(String(format: String(localized: "Lines %lld-%lld", table: "EditorPreview"), preview.lineNumber, preview.endLineNumber))
                        .font(.system(size: 11))
                        .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                }
                .tag(preview.id)
                .padding(.vertical, 3)
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - Preview Detail

    private var previewDetail: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let preview = viewModel.selectedPreview {
                previewHeader(preview)

                if case .failed(let message) = viewModel.runState {
                    errorMessageView(message)
                } else if viewModel.runState == .hostMissing {
                    Text(String(localized: "Set LUMI_PREVIEW_HOST_EXECUTABLE or embed LumiPreviewHostApp in Contents/Helpers.", table: "EditorPreview"))
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .textSelection(.enabled)
                } else if let diagnostics = viewModel.diagnostics {
                    diagnosticsView(diagnostics)
                } else {
                    previewSurface(preview)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Display Mode Picker (toolbar)

    private var displayModePicker: some View {
        HStack(spacing: 0) {
            Button {
                viewModel.switchToImage()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "photo")
                        .font(.system(size: 9, weight: .medium))
                    Text("Image")
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    viewModel.displayMode == .image
                        ? themeVM.activeAppTheme.workspaceTextColor().opacity(0.12)
                        : Color.clear
                )
                .foregroundColor(
                    viewModel.displayMode == .image
                        ? themeVM.activeAppTheme.workspaceTextColor()
                        : themeVM.activeAppTheme.workspaceSecondaryTextColor()
                )
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.2))
                .frame(width: 1, height: 14)

            Button {
                if viewModel.canSwitchToLive {
                    viewModel.switchToLive()
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: viewModel.displayMode == .live ? "play.rectangle.fill" : "play.rectangle")
                        .font(.system(size: 9, weight: .medium))
                    Text("Live")
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    viewModel.displayMode == .live
                        ? themeVM.activeAppTheme.workspaceTextColor().opacity(0.12)
                        : Color.clear
                )
                .foregroundColor(liveTabColor)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canSwitchToLive && viewModel.displayMode != .live)
            .help(viewModel.liveUnavailableReason ?? String(localized: "Switch to Live mode", table: "EditorPreview"))
        }
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.15), lineWidth: 0.5)
        )
    }

    private var liveTabColor: Color {
        if viewModel.displayMode == .live {
            return .green
        }
        if viewModel.canSwitchToLive {
            return themeVM.activeAppTheme.workspaceSecondaryTextColor()
        }
        return themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.5)
    }

    // MARK: - Preview Header

    private func previewHeader(_ preview: PreviewDiscovery) -> some View {
        HStack(spacing: 8) {
            Text(preview.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(themeVM.activeAppTheme.workspaceTextColor())

            if let primaryTypeName = preview.primaryTypeName {
                Label(primaryTypeName, systemImage: "swift")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Error Message

    private func errorMessageView(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(.red)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Diagnostics

    private func diagnosticsView(_ diagnostics: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label(String(localized: "Preview build failed", table: "EditorPreview"), systemImage: "exclamationmark.triangle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.red)

                Spacer(minLength: 0)

                Button {
                    copyDiagnostics(diagnostics)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                .help(String(localized: "Copy error details", table: "EditorPreview"))
                .accessibilityLabel(String(localized: "Copy error details", table: "EditorPreview"))
            }

            ScrollView {
                Text(diagnostics)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(themeVM.activeAppTheme.workspaceTextColor())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.red.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red.opacity(0.22), lineWidth: 1)
        )
    }

    private func copyDiagnostics(_ diagnostics: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(diagnostics, forType: .string)
    }

    // MARK: - Preview Surface

    private func previewSurface(_ preview: PreviewDiscovery) -> some View {
        ZStack {
            if viewModel.displayMode == .live {
                liveCanvasSurface(preview)
            } else {
                imageCanvasSurface(preview)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Image Canvas

    private func imageCanvasSurface(_ preview: PreviewDiscovery) -> some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)

            if let renderImage = viewModel.renderImage {
                Image(nsImage: renderImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 420, maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.18), lineWidth: 1)
                    )
            } else {
                Image(systemName: surfaceIconName)
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(statusColor)
            }

            surfaceInfo(preview)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Live Canvas

    private func liveCanvasSurface(_ preview: PreviewDiscovery) -> some View {
        GeometryReader { geometry in
            ZStack {
                // Live canvas background
                RoundedRectangle(cornerRadius: 6)
                    .fill(themeVM.activeAppTheme.workspaceBackgroundColor())

                if viewModel.isLiveLoading {
                    // Loading overlay
                    VStack(spacing: 10) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(String(localized: "Starting Live Preview…", table: "EditorPreview"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Live fallback info (when live window hasn't attached yet)
                if !viewModel.isLiveLoading {
                    VStack(spacing: 8) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 20, weight: .light))
                            .foregroundColor(.green.opacity(0.6))

                        Text(String(localized: "Live Preview Active", table: "EditorPreview"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())

                        if let performanceSummary = viewModel.performanceSummary {
                            Text(performanceSummary)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(themeVM.activeAppTheme.workspaceTertiaryTextColor())
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(
                LiveCanvasFrameReporter { screenFrame in
                    viewModel.updateLiveCanvasRect(screenFrame)
                }
            )
            .onAppear {
                viewModel.liveCanvasDidAppear()
            }
            .onDisappear {
                viewModel.liveCanvasDidDisappear()
            }
            .onChange(of: geometry.size) { _, _ in
                LiveCanvasFrameReporter.scheduleFrameUpdate()
            }
        }
    }

    // MARK: - Surface Info

    private func surfaceInfo(_ preview: PreviewDiscovery) -> some View {
        VStack(spacing: 5) {
            Text(surfaceTitle(for: preview))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(themeVM.activeAppTheme.workspaceTextColor())
                .multilineTextAlignment(.center)

            if let renderMessage = viewModel.renderMessage {
                Text(renderMessage)
                    .font(.system(size: 11))
                    .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                    .multilineTextAlignment(.center)
            }

            if let performanceSummary = viewModel.performanceSummary {
                Text(performanceSummary)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(themeVM.activeAppTheme.workspaceTertiaryTextColor())
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: 360)
    }

    private var surfaceIconName: String {
        switch viewModel.runState {
        case .running:
            "play.rectangle.fill"
        case .starting:
            "hourglass"
        case .stopped:
            "stop.circle"
        case .idle:
            "play.rectangle"
        case .failed:
            "exclamationmark.triangle"
        case .hostMissing:
            "xmark.octagon"
        }
    }

    private func surfaceTitle(for preview: PreviewDiscovery) -> String {
        switch viewModel.runState {
        case .running:
            if viewModel.displayMode == .live {
                return String(format: String(localized: "Live preview of %@", table: "EditorPreview"), preview.title)
            }
            return String(format: String(localized: "Preview host rendered %@", table: "EditorPreview"), preview.title)
        case .starting:
            return String(localized: "Building preview", table: "EditorPreview")
        case .stopped:
            return String(localized: "Preview stopped", table: "EditorPreview")
        case .idle:
            return String(localized: "Ready to start preview", table: "EditorPreview")
        case .failed:
            return String(localized: "Preview failed", table: "EditorPreview")
        case .hostMissing:
            return String(localized: "Preview host missing", table: "EditorPreview")
        }
    }

    // MARK: - Helpers

    private func refreshScan() {
        viewModel.update(sourceText: sourceText, fileURL: currentFileURL)
    }

    private func refreshScanAndStartIfNeeded(allowsStopped: Bool = true) {
        refreshScan()
        viewModel.startSelectedPreviewIfNeeded(allowsStopped: allowsStopped)
    }
}

private let liveCanvasFrameReporterFrameUpdateNotification = Notification.Name("LiveCanvasFrameReporterFrameUpdate")

private struct LiveCanvasFrameReporter: NSViewRepresentable {
    let onFrameChange: (CGRect) -> Void

    static func scheduleFrameUpdate() {
        NotificationCenter.default.post(name: liveCanvasFrameReporterFrameUpdateNotification, object: nil)
    }

    func makeNSView(context: Context) -> ReportingView {
        let view = ReportingView()
        view.onFrameChange = onFrameChange
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: ReportingView, context: Context) {
        nsView.onFrameChange = onFrameChange
        nsView.reportFrameSoon()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        private var observers: [NSObjectProtocol] = []

        func attach(to view: ReportingView) {
            observers.forEach(NotificationCenter.default.removeObserver)
            observers = [
                NotificationCenter.default.addObserver(
                    forName: NSWindow.didMoveNotification,
                    object: nil,
                    queue: .main
                ) { [weak view] _ in
                    Task { @MainActor in
                        view?.reportFrameSoon()
                    }
                },
                NotificationCenter.default.addObserver(
                    forName: NSWindow.didResizeNotification,
                    object: nil,
                    queue: .main
                ) { [weak view] _ in
                    Task { @MainActor in
                        view?.reportFrameSoon()
                    }
                },
                NotificationCenter.default.addObserver(
                    forName: liveCanvasFrameReporterFrameUpdateNotification,
                    object: nil,
                    queue: .main
                ) { [weak view] _ in
                    Task { @MainActor in
                        view?.reportFrameSoon()
                    }
                }
            ]
        }

        deinit {
            observers.forEach(NotificationCenter.default.removeObserver)
        }
    }

    final class ReportingView: NSView {
        var onFrameChange: ((CGRect) -> Void)?
        private var lastReportedFrame: CGRect = .null

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            reportFrameSoon()
        }

        override func setFrameSize(_ newSize: NSSize) {
            super.setFrameSize(newSize)
            reportFrameSoon()
        }

        func reportFrameSoon() {
            DispatchQueue.main.async { [weak self] in
                self?.reportFrame()
            }
        }

        private func reportFrame() {
            guard let window, !bounds.isEmpty else { return }
            let windowRect = convert(bounds, to: nil)
            let screenRect = window.convertToScreen(windowRect).standardized
            guard screenRect != lastReportedFrame else { return }
            lastReportedFrame = screenRect
            onFrameChange?(screenRect)
        }
    }
}
#else
import SwiftUI

struct EditorPreviewContentView: View {
    var body: some View {
        EmptyView()
    }
}
#endif
