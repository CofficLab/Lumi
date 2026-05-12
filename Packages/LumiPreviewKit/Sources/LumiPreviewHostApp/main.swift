import Foundation
import LumiPreviewKit
import AppKit
import SwiftUI
import Darwin

/// 独立预览宿主程序入口。
///
/// 使用后台线程处理 stdin/stdout JSON 通信，让主线程保留给 AppKit run loop。
@main
struct LumiPreviewHostApp {
    @MainActor
    static func main() {
        let host = StdioPreviewHost()
        host.run()
    }
}

@MainActor
private final class StdioPreviewHost {
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let renderer = PreviewRenderer()
    private var requestReader: HostRequestReader?

    func run() {
        let requestReader = HostRequestReader(host: self)
        self.requestReader = requestReader
        requestReader.start()
        NSApplication.shared.run()
    }

    fileprivate func handleLine(_ line: String) -> Data {
        guard let data = line.data(using: .utf8) else {
            return encoded(ErrorResponse(message: "Request is not valid UTF-8."))
        }

        do {
            let request = try decoder.decode(RenderRequest.self, from: data)
            return encoded(handle(request))
        } catch {
            return encoded(ErrorResponse(message: "Invalid request: \(error.localizedDescription)"))
        }
    }

    private func encoded<Response: Encodable>(_ response: Response) -> Data {
        do {
            return try encoder.encode(response)
        } catch {
            return Data(#"{"message":"Failed to encode response."}"#.utf8)
        }
    }

    private func handle(_ request: RenderRequest) -> RenderResponse {
        switch request.command {
        case .render:
            guard let discovery = request.discovery else {
                return RenderResponse(success: false, message: "Render request is missing discovery.")
            }
            return renderer.render(discovery: discovery, configuration: request.configuration)
        case .refresh:
            return renderer.refresh()
        case .loadDylib:
            guard let dylibPath = request.dylibPath else {
                return RenderResponse(success: false, message: "Dylib load request is missing dylibPath.")
            }
            return renderer.loadDylib(atPath: dylibPath, previewEntrySymbol: request.previewEntrySymbol)
        case .startLivePreview:
            return renderer.startLivePreview()
        case .updateLiveFrame:
            guard let liveFrame = request.liveFrame else {
                return RenderResponse(success: false, message: "Update live frame request is missing liveFrame.")
            }
            return renderer.updateLiveFrame(
                x: liveFrame.x,
                y: liveFrame.y,
                width: liveFrame.width,
                height: liveFrame.height,
                scale: liveFrame.scale
            )
        case .showLivePreview:
            return renderer.showLivePreview()
        case .hideLivePreview:
            return renderer.hideLivePreview()
        case .reloadLivePreview:
            guard let dylibPath = request.dylibPath else {
                return RenderResponse(success: false, message: "Reload live preview request is missing dylibPath.")
            }
            return renderer.reloadLivePreview(
                dylibPath: dylibPath,
                previewEntrySymbol: request.previewEntrySymbol
            )
        case .stopLivePreview:
            return renderer.stopLivePreview()
        }
    }
}

private final class HostRequestReader: @unchecked Sendable {
    private weak var host: StdioPreviewHost?

    init(host: StdioPreviewHost) {
        self.host = host
    }

    func start() {
        Thread.detachNewThread { [weak self] in
            self?.readLoop()
        }
    }

    private func readLoop() {
        while let line = readLine() {
            let result = ResponseDataBox()
            let semaphore = DispatchSemaphore(value: 0)

            Task { @MainActor [weak self] in
                if let host = self?.host {
                    result.data = host.handleLine(line)
                } else {
                    result.data = Data(#"{"message":"Preview host is no longer available."}"#.utf8)
                }
                semaphore.signal()
            }

            semaphore.wait()
            FileHandle.standardOutput.write(result.data)
            FileHandle.standardOutput.write(Data([0x0A]))
        }

        Task { @MainActor in
            NSApplication.shared.terminate(nil)
        }
    }
}

private final class ResponseDataBox: @unchecked Sendable {
    var data = Data()
}

@MainActor
private final class PreviewRenderer {
    private static let fallbackSnapshotSize = NSSize(width: 320, height: 180)
    private static let maximumSnapshotSize = NSSize(width: 2_400, height: 2_400)

    private var previewView: NSView?
    private var renderWindow: NSWindow?
    private var liveWindow: LivePreviewWindow?
    private var currentDiscovery: PreviewDiscovery?
    private var currentConfiguration: PreviewRenderConfiguration = .empty
    private var loadedHandles: [UnsafeMutableRawPointer] = []
    private var currentDynamicPreviewTitle: String?
    private var isLivePreviewEnabled = false

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
        NSApplication.shared.finishLaunching()
    }

    func render(
        discovery: PreviewDiscovery,
        configuration: PreviewRenderConfiguration
    ) -> RenderResponse {
        let previewView = AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Text(discovery.title)
                    .font(.headline)
                if let primaryTypeName = discovery.primaryTypeName {
                    Text(primaryTypeName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if configuration.hasEnvironmentInjections {
                    Text("\(configuration.environmentInjections.count) environment mock(s)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(minWidth: 320, minHeight: 180)
        )

        let hostingView = NSHostingView(rootView: previewView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 180)
        self.previewView = hostingView
        self.currentDiscovery = discovery
        self.currentConfiguration = configuration

        return RenderResponse(
            success: true,
            previewID: discovery.id,
            message: Self.renderedMessage(discovery: discovery, configuration: configuration),
            previewImagePNGBase64: snapshotPNGBase64()
        )
    }

    func refresh() -> RenderResponse {
        previewView?.needsLayout = true
        if let currentDiscovery {
            return RenderResponse(
                success: true,
                previewID: currentDiscovery.id,
                message: "Refreshed \(currentDiscovery.title)",
                previewImagePNGBase64: snapshotPNGBase64()
            )
        }

        if let currentDynamicPreviewTitle {
            return RenderResponse(
                success: true,
                previewID: currentDynamicPreviewTitle,
                message: "Refreshed \(currentDynamicPreviewTitle)",
                previewImagePNGBase64: snapshotPNGBase64()
            )
        }

        return RenderResponse(
            success: false,
            message: "No preview has been rendered."
        )
    }

    func loadDylib(atPath path: String, previewEntrySymbol: String?) -> RenderResponse {
        guard FileManager.default.fileExists(atPath: path) else {
            return RenderResponse(success: false, message: "Dylib does not exist: \(path)")
        }

        guard let handle = dlopen(path, RTLD_NOW | RTLD_LOCAL) else {
            let errorMessage = dlerror().map { String(cString: $0) } ?? "Unknown dlopen error."
            return RenderResponse(success: false, message: errorMessage)
        }

        loadedHandles.append(handle)

        if let previewEntrySymbol {
            return renderPreviewEntry(symbolName: previewEntrySymbol, from: handle)
        }

        return RenderResponse(success: true, message: "Loaded \(URL(fileURLWithPath: path).lastPathComponent)")
    }

    private func renderPreviewEntry(
        symbolName: String,
        from handle: UnsafeMutableRawPointer
    ) -> RenderResponse {
        let descriptor = previewEntryDescriptor(symbolName: symbolName, from: handle)
        if let response = renderPreviewViewEntry(
            descriptor: descriptor,
            symbolName: PreviewEntryBuilder.viewSymbolName,
            from: handle
        ) {
            return response
        }

        guard let symbol = dlsym(handle, symbolName) else {
            let errorMessage = dlerror().map { String(cString: $0) } ?? "Preview entry symbol not found."
            return RenderResponse(success: false, message: errorMessage)
        }

        typealias PreviewEntryFunction = @convention(c) () -> UnsafePointer<CChar>?
        let entryFunction = unsafeBitCast(symbol, to: PreviewEntryFunction.self)
        guard let payloadPointer = entryFunction() else {
            return RenderResponse(success: false, message: "Preview entry returned nil.")
        }

        let payload = String(cString: payloadPointer)
        if let descriptor = Self.previewEntryDescriptor(from: payload) {
            return renderPreviewEntry(descriptor: descriptor, symbolName: symbolName)
        }

        return renderLegacyPreviewEntry(title: payload, symbolName: symbolName)
    }

    private func renderPreviewEntry(
        descriptor: PreviewEntryDescriptor,
        symbolName: String
    ) -> RenderResponse {
        let previewView = AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Text(descriptor.title)
                    .font(.headline)
                if let subtitle = descriptor.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let body = descriptor.body {
                    Text(body)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(minWidth: 320, minHeight: 180)
        )

        let hostingView = NSHostingView(rootView: previewView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 180)
        self.previewView = hostingView
        self.currentDiscovery = nil
        self.currentDynamicPreviewTitle = descriptor.title

        return RenderResponse(
            success: true,
            previewID: symbolName,
            message: "Loaded preview entry \(descriptor.title)",
            previewImagePNGBase64: snapshotPNGBase64(),
            diagnostics: descriptor.diagnostics,
            isFallback: descriptor.isFallback
        )
    }

    private func renderPreviewViewEntry(
        descriptor: PreviewEntryDescriptor?,
        symbolName: String,
        from handle: UnsafeMutableRawPointer
    ) -> RenderResponse? {
        guard let symbol = dlsym(handle, symbolName) else {
            return nil
        }

        typealias PreviewNSViewFunction = @convention(c) () -> UnsafeMutableRawPointer?
        let viewFunction = unsafeBitCast(symbol, to: PreviewNSViewFunction.self)
        guard let viewPointer = viewFunction() else {
            return RenderResponse(success: false, message: "Preview view entry returned nil.")
        }

        let view = Unmanaged<NSView>.fromOpaque(viewPointer).takeRetainedValue()
        if view.frame.isEmpty {
            view.frame = NSRect(x: 0, y: 0, width: 320, height: 180)
        }
        previewView = view
        currentDiscovery = nil
        isLivePreviewEnabled = true

        let title = descriptor?.title ?? symbolName
        currentDynamicPreviewTitle = title

        return RenderResponse(
            success: true,
            previewID: symbolName,
            message: "Loaded preview view entry \(title)",
            previewImagePNGBase64: snapshotPNGBase64(),
            livePreviewEnabled: true
        )
    }

    private func renderLegacyPreviewEntry(title: String, symbolName: String) -> RenderResponse {
        renderPreviewEntry(
            descriptor: PreviewEntryDescriptor(
                title: title,
                subtitle: "Dynamic dylib preview"
            ),
            symbolName: symbolName
        )
    }

    private static func previewEntryDescriptor(from payload: String) -> PreviewEntryDescriptor? {
        guard let data = payload.data(using: .utf8) else {
            return nil
        }

        return try? JSONDecoder().decode(PreviewEntryDescriptor.self, from: data)
    }

    private func previewEntryDescriptor(
        symbolName: String,
        from handle: UnsafeMutableRawPointer
    ) -> PreviewEntryDescriptor? {
        guard let symbol = dlsym(handle, symbolName) else {
            return nil
        }

        typealias PreviewEntryFunction = @convention(c) () -> UnsafePointer<CChar>?
        let entryFunction = unsafeBitCast(symbol, to: PreviewEntryFunction.self)
        guard let payloadPointer = entryFunction() else {
            return nil
        }

        return Self.previewEntryDescriptor(from: String(cString: payloadPointer))
    }

    // MARK: - Live Preview

    func startLivePreview() -> RenderResponse {
        guard isLivePreviewEnabled, let previewView else {
            return RenderResponse(
                success: false,
                message: "Live preview is not available: no real NSView entry loaded."
            )
        }

        if liveWindow != nil {
            return RenderResponse(
                success: true,
                message: "Live preview already running.",
                livePreviewEnabled: true,
                liveWindowNumber: liveWindow?.windowNumber
            )
        }

        let frame = NSRect(x: 0, y: 0, width: 320, height: 180)
        let window = LivePreviewWindow(contentRect: frame)
        window.contentView = previewView
        // Position off-screen until updateLiveFrame positions it correctly
        window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))

        liveWindow = window

        return RenderResponse(
            success: true,
            message: "Live preview started.",
            livePreviewEnabled: true,
            liveWindowNumber: window.windowNumber
        )
    }

    func updateLiveFrame(x: Double, y: Double, width: Double, height: Double, scale: Double) -> RenderResponse {
        guard let liveWindow else {
            return RenderResponse(success: false, message: "No live window to update.")
        }

        let frame = LivePreviewFrameAlignment.pixelAlignedFrame(
            NSRect(x: x, y: y, width: width, height: height),
            scale: scale
        )
        liveWindow.setFrame(frame, display: true)

        return RenderResponse(
            success: true,
            message: "Live frame updated to (\(x), \(y), \(width)x\(height)).",
            livePreviewEnabled: true,
            liveWindowNumber: liveWindow.windowNumber
        )
    }

    func showLivePreview() -> RenderResponse {
        guard let liveWindow else {
            return RenderResponse(success: false, message: "No live window to show.")
        }
        guard liveWindow.contentView != nil else {
            return RenderResponse(success: false, message: "No live preview content to show.")
        }

        liveWindow.orderFront(nil)

        return RenderResponse(
            success: true,
            message: "Live preview shown.",
            livePreviewEnabled: true,
            liveWindowNumber: liveWindow.windowNumber
        )
    }

    func hideLivePreview() -> RenderResponse {
        guard let liveWindow else {
            return RenderResponse(success: false, message: "No live window to hide.")
        }

        liveWindow.orderOut(nil)

        return RenderResponse(
            success: true,
            message: "Live preview hidden.",
            livePreviewEnabled: true,
            liveWindowNumber: liveWindow.windowNumber
        )
    }

    func reloadLivePreview(dylibPath: String, previewEntrySymbol: String?) -> RenderResponse {
        guard FileManager.default.fileExists(atPath: dylibPath) else {
            return RenderResponse(success: false, message: "Dylib does not exist: \(dylibPath)")
        }

        guard let handle = dlopen(dylibPath, RTLD_NOW | RTLD_LOCAL) else {
            let errorMessage = dlerror().map { String(cString: $0) } ?? "Unknown dlopen error."
            return RenderResponse(success: false, message: errorMessage)
        }

        loadedHandles.append(handle)

        guard let previewEntrySymbol else {
            return RenderResponse(success: false, message: "Reload requires previewEntrySymbol.")
        }

        // Try loading NSView entry first
        let descriptor = previewEntryDescriptor(symbolName: previewEntrySymbol, from: handle)
        if let symbol = dlsym(handle, PreviewEntryBuilder.viewSymbolName) {
            typealias PreviewNSViewFunction = @convention(c) () -> UnsafeMutableRawPointer?
            let viewFunction = unsafeBitCast(symbol, to: PreviewNSViewFunction.self)
            if let viewPointer = viewFunction() {
                let view = Unmanaged<NSView>.fromOpaque(viewPointer).takeRetainedValue()
                if view.frame.isEmpty {
                    view.frame = NSRect(x: 0, y: 0, width: 320, height: 180)
                }
                let title = descriptor?.title ?? previewEntrySymbol

                let snapshot = snapshotPNGBase64(for: view)

                previewView = view
                isLivePreviewEnabled = true
                currentDynamicPreviewTitle = title

                let wasVisible = liveWindow?.isVisible == true
                let liveFrame = liveWindow?.frame
                // `snapshotPNGBase64(for:)` temporarily hosts the new view off-screen.
                // Only after that succeeds do we replace the visible live content.
                liveWindow?.contentView = view
                if let liveFrame {
                    liveWindow?.setFrame(liveFrame, display: true)
                }
                if wasVisible {
                    liveWindow?.orderFront(nil)
                }

                return RenderResponse(
                    success: true,
                    message: "Reloaded live preview view entry \(title)",
                    previewImagePNGBase64: snapshot,
                    livePreviewEnabled: true,
                    liveWindowNumber: liveWindow?.windowNumber
                )
            }
        }

        return RenderResponse(
            success: false,
            message: "Reload failed: could not create NSView from new dylib."
        )
    }

    func stopLivePreview() -> RenderResponse {
        liveWindow?.orderOut(nil)
        liveWindow?.contentView = nil
        liveWindow?.close()
        liveWindow = nil

        return RenderResponse(
            success: true,
            message: "Live preview stopped."
        )
    }

    // MARK: - Snapshot

    private func snapshotPNGBase64() -> String? {
        guard let previewView else { return nil }
        return snapshotPNGBase64(for: previewView)
    }

    private func snapshotPNGBase64(for view: NSView) -> String? {
        var bounds = prepareViewForSnapshot(view)
        flushPreviewRendering()

        let measuredSize = Self.snapshotSize(for: view)
        if !Self.isSameSize(bounds.size, measuredSize) {
            bounds = prepareViewForSnapshot(view, preferredSize: measuredSize)
            flushPreviewRendering()
        }

        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()

        guard !bounds.isEmpty,
              let bitmap = view.bitmapImageRepForCachingDisplay(in: bounds) else {
            return nil
        }

        bitmap.size = bounds.size
        view.cacheDisplay(in: bounds, to: bitmap)
        return bitmap.representation(using: .png, properties: [:])?.base64EncodedString()
    }

    private func prepareViewForSnapshot(_ view: NSView, preferredSize: NSSize? = nil) -> NSRect {
        let size = preferredSize ?? Self.snapshotSize(for: view)
        let frame = NSRect(origin: .zero, size: Self.clampedSnapshotSize(size))

        if renderWindow?.contentView !== view {
            renderWindow?.orderOut(nil)
            renderWindow?.contentView = nil
            renderWindow?.close()

            let window = NSWindow(
                contentRect: frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.backgroundColor = .clear
            window.ignoresMouseEvents = true
            window.setFrameOrigin(NSPoint(x: -100_000, y: -100_000))
            window.contentView = view
            window.orderFrontRegardless()
            renderWindow = window
        } else {
            renderWindow?.setContentSize(frame.size)
            renderWindow?.orderFrontRegardless()
        }

        view.frame = frame
        view.needsLayout = true
        view.needsDisplay = true
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()

        return view.bounds.isEmpty ? frame : view.bounds
    }

    private func flushPreviewRendering() {
        for _ in 0..<5 {
            _ = RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
    }

    private static func snapshotSize(for view: NSView) -> NSSize {
        view.layoutSubtreeIfNeeded()

        let candidates = [
            normalizedSnapshotSize(view.bounds.size),
            normalizedSnapshotSize(view.frame.size),
            normalizedSnapshotSize(view.intrinsicContentSize),
            normalizedSnapshotSize(view.fittingSize)
        ].compactMap { $0 }

        let width = candidates.map(\.width).max() ?? fallbackSnapshotSize.width
        let height = candidates.map(\.height).max() ?? fallbackSnapshotSize.height

        return clampedSnapshotSize(NSSize(
            width: max(width, fallbackSnapshotSize.width),
            height: max(height, fallbackSnapshotSize.height)
        ))
    }

    private static func normalizedSnapshotSize(_ size: NSSize) -> NSSize? {
        guard size.width.isFinite,
              size.height.isFinite,
              size.width > 1,
              size.height > 1 else {
            return nil
        }

        return NSSize(width: ceil(size.width), height: ceil(size.height))
    }

    private static func clampedSnapshotSize(_ size: NSSize) -> NSSize {
        NSSize(
            width: min(max(size.width, 1), maximumSnapshotSize.width),
            height: min(max(size.height, 1), maximumSnapshotSize.height)
        )
    }

    private static func isSameSize(_ lhs: NSSize, _ rhs: NSSize) -> Bool {
        abs(lhs.width - rhs.width) < 0.5 && abs(lhs.height - rhs.height) < 0.5
    }

    private static func renderedMessage(
        discovery: PreviewDiscovery,
        configuration: PreviewRenderConfiguration
    ) -> String {
        guard configuration.hasEnvironmentInjections else {
            return "Rendered \(discovery.title)"
        }

        return "Rendered \(discovery.title) with \(configuration.environmentInjections.count) environment injection(s)"
    }
}
