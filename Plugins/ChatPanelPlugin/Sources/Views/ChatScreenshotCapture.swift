import AppKit
import CoreGraphics
import ScreenCaptureKit
import SwiftUI
import LumiKernel

extension Notification.Name {
    static let screenshotCaptured = Notification.Name("screenshotCaptured")
}

@MainActor
final class ChatScreenshotState: ObservableObject {
    static let shared = ChatScreenshotState()

    @Published private(set) var isCapturing = false
    @Published private(set) var isPreparing = false
    @Published fileprivate var selectionRect: CGRect = .zero

    private var overlayWindows: [ChatScreenshotOverlayWindow] = []
    private var captureImage: CGImage?
    private var captureFrame: CGRect = .zero

    private init() {}

    func startCapture() {
        guard !isCapturing else { return }

        guard Self.hasScreenCapturePermission() else {
            presentPermissionAlert()
            return
        }

        isCapturing = true
        isPreparing = true

        Task {
            do {
                let capture = try await Self.captureAllScreens()
                captureImage = capture.image
                captureFrame = capture.frame
                selectionRect = .zero
                isPreparing = false

                overlayWindows = Self.makeOverlayWindows(state: self)
                overlayWindows.forEach { $0.orderFront(nil) }
                overlayWindows.first?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            } catch {
                endCapture()
                presentCaptureFailureAlert(error: error)
            }
        }
    }

    func endCapture() {
        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows.removeAll()
        captureImage = nil
        selectionRect = .zero
        isPreparing = false
        isCapturing = false
    }

    fileprivate func updateSelection(_ rect: CGRect) {
        selectionRect = rect.standardized
    }

    fileprivate func completeCapture(selection: CGRect) {
        let normalizedSelection = selection.standardized.integral
        defer { endCapture() }

        guard normalizedSelection.width >= 10,
              normalizedSelection.height >= 10,
              let image = captureImage,
              let cropped = Self.crop(image: image, captureFrame: captureFrame, selection: normalizedSelection),
              let pngData = NSBitmapImageRep(cgImage: cropped).representation(using: .png, properties: [:])
        else {
            return
        }

        NotificationCenter.default.post(
            name: .screenshotCaptured,
            object: nil,
            userInfo: ["data": pngData]
        )
    }

    fileprivate nonisolated static func captureAllScreens() async throws -> (image: CGImage, frame: CGRect) {
        let frame = NSScreen.screens.reduce(CGRect.null) { partial, screen in
            partial.union(screen.frame)
        }
        guard !frame.isNull else {
            throw ScreenshotError.noScreens
        }

        let image: CGImage
        if #available(macOS 15.2, *) {
            image = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CGImage, Error>) in
                SCScreenshotManager.captureImage(in: frame) { image, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let image {
                        continuation.resume(returning: image)
                    } else {
                        continuation.resume(throwing: ScreenshotError.captureFailed)
                    }
                }
            }
        } else if let fallbackImage = CGWindowListCreateImage(
            frame,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        ) {
            image = fallbackImage
        } else {
            throw ScreenshotError.captureFailed
        }
        return (image, frame)
    }

    /// Crop a captured image to a selection rect in screen space.
    ///
    /// Pure geometry: maps the screen-space `selection` into image space via the
    /// capture's scale factors, applies a Y-axis flip, integral+intersection
    /// clamping, and a 1px minimum guard. Promoted to `internal` for unit testing.
    nonisolated static func crop(image: CGImage, captureFrame: CGRect, selection: CGRect) -> CGImage? {
        let scaleX = CGFloat(image.width) / captureFrame.width
        let scaleY = CGFloat(image.height) / captureFrame.height
        let relativeX = selection.minX - captureFrame.minX
        let relativeY = selection.minY - captureFrame.minY
        let cropRect = CGRect(
            x: relativeX * scaleX,
            y: (captureFrame.height - relativeY - selection.height) * scaleY,
            width: selection.width * scaleX,
            height: selection.height * scaleY
        )
        .integral
        .intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))

        guard cropRect.width >= 1, cropRect.height >= 1 else { return nil }
        return image.cropping(to: cropRect)
    }

    private static func makeOverlayWindows(state: ChatScreenshotState) -> [ChatScreenshotOverlayWindow] {
        NSScreen.screens.map { screen in
            ChatScreenshotOverlayWindow(screenFrame: screen.frame, state: state)
        }
    }

    private nonisolated static func hasScreenCapturePermission() -> Bool {
        if #available(macOS 10.15, *) {
            return CGPreflightScreenCaptureAccess()
        }
        return true
    }

    private func presentPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = LumiPluginLocalization.string("Screen Recording Permission Required", bundle: .module)
        alert.informativeText = LumiPluginLocalization.string("Screen Recording Permission Required Hint", bundle: .module)
        alert.alertStyle = .warning
        alert.addButton(withTitle: LumiPluginLocalization.string("Open System Settings", bundle: .module))
        alert.addButton(withTitle: LumiPluginLocalization.string("Cancel", bundle: .module))

        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    private func presentCaptureFailureAlert(error: Error) {
        let alert = NSAlert()
        alert.messageText = LumiPluginLocalization.string("Screenshot Failed", bundle: .module)
        alert.informativeText = captureFailureMessage(for: error)
        alert.alertStyle = .warning
        alert.addButton(withTitle: LumiPluginLocalization.string("OK", bundle: .module))
        alert.runModal()
    }

    private func captureFailureMessage(for error: Error) -> String {
        switch error {
        case ScreenshotError.noScreens:
            return LumiPluginLocalization.string("Screenshot Failed No Screens", bundle: .module)
        case ScreenshotError.captureFailed:
            return LumiPluginLocalization.string("Screenshot Failed No Image", bundle: .module)
        default:
            let prefix = LumiPluginLocalization.string("Screenshot Failed Generic", bundle: .module)
            return "\(prefix)\n\n\(error.localizedDescription)"
        }
    }

    private enum ScreenshotError: Error {
        case noScreens
        case captureFailed
    }
}

private final class ChatScreenshotOverlayWindow: NSWindow {
    init(screenFrame: CGRect, state: ChatScreenshotState) {
        super.init(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        hasShadow = false
        contentView = NSHostingView(
            rootView: ChatScreenshotOverlayRepresentable(state: state, screenFrame: screenFrame)
        )
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private struct ChatScreenshotOverlayRepresentable: NSViewRepresentable {
    @ObservedObject var state: ChatScreenshotState
    let screenFrame: CGRect

    func makeNSView(context: Context) -> ChatScreenshotOverlayContentView {
        let view = ChatScreenshotOverlayContentView(screenFrame: screenFrame)
        view.onSelectionChanged = { [weak state] rect in
            Task { @MainActor in
                state?.updateSelection(rect)
            }
        }
        view.onSelectionCompleted = { [weak state] rect in
            Task { @MainActor in
                state?.completeCapture(selection: rect)
            }
        }
        view.onCancel = { [weak state] in
            Task { @MainActor in
                state?.endCapture()
            }
        }
        return view
    }

    func updateNSView(_ nsView: ChatScreenshotOverlayContentView, context: Context) {
        nsView.selectionRect = state.selectionRect
    }
}

private final class ChatScreenshotOverlayContentView: NSView {
    var onSelectionChanged: ((CGRect) -> Void)?
    var onSelectionCompleted: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    var selectionRect: CGRect = .zero {
        didSet { needsDisplay = true }
    }

    private var dragStart: CGPoint?
    private let screenFrame: CGRect

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { false }

    init(screenFrame: CGRect) {
        self.screenFrame = screenFrame
        super.init(frame: CGRect(origin: .zero, size: screenFrame.size))
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.setFillColor(NSColor.black.withAlphaComponent(0.48).cgColor)
        context.fill(bounds)

        if let localSelectionRect {
            context.clear(localSelectionRect)

            let borderPath = CGPath(rect: localSelectionRect.insetBy(dx: 1, dy: 1), transform: nil)
            context.addPath(borderPath)
            context.setStrokeColor(NSColor.controlAccentColor.cgColor)
            context.setLineWidth(2)
            context.strokePath()

            drawSizeLabel(for: localSelectionRect, globalRect: selectionRect)
        }

        drawHint()
    }

    override func mouseDown(with event: NSEvent) {
        let point = NSEvent.mouseLocation
        dragStart = point
        updateSelection(from: point, to: point)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStart else { return }
        updateSelection(from: dragStart, to: NSEvent.mouseLocation)
    }

    override func mouseUp(with event: NSEvent) {
        guard let dragStart else { return }
        let endPoint = NSEvent.mouseLocation
        self.dragStart = nil
        let rect = rectBetween(dragStart, endPoint)
        onSelectionChanged?(rect)
        onSelectionCompleted?(rect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }

    private func updateSelection(from start: CGPoint, to end: CGPoint) {
        let rect = rectBetween(start, end)
        selectionRect = rect
        onSelectionChanged?(rect)
    }

    private func rectBetween(_ start: CGPoint, _ end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    private var localSelectionRect: CGRect? {
        let intersection = selectionRect.intersection(screenFrame)
        guard !intersection.isNull, !intersection.isEmpty else { return nil }
        return intersection.offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY)
    }

    private func drawSizeLabel(for rect: CGRect, globalRect: CGRect) {
        guard screenFrame.contains(CGPoint(x: globalRect.minX, y: globalRect.minY)) else { return }

        let label = "\(Int(globalRect.width)) x \(Int(globalRect.height))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let attributed = NSAttributedString(string: label, attributes: attributes)
        let labelSize = attributed.size()
        let padding = CGSize(width: 8, height: 5)
        let bubbleSize = CGSize(
            width: labelSize.width + padding.width * 2,
            height: labelSize.height + padding.height * 2
        )
        let labelOrigin = CGPoint(
            x: max(8, min(rect.minX, bounds.maxX - bubbleSize.width - 8)),
            y: max(8, rect.minY - bubbleSize.height - 8)
        )
        let bubbleRect = CGRect(origin: labelOrigin, size: bubbleSize)

        NSColor.black.withAlphaComponent(0.72).setFill()
        NSBezierPath(roundedRect: bubbleRect, xRadius: 5, yRadius: 5).fill()
        attributed.draw(at: CGPoint(x: bubbleRect.minX + padding.width, y: bubbleRect.minY + padding.height))
    }

    private func drawHint() {
        let hint = String(
            localized: "Drag to select a screenshot region. Press ESC to cancel.",
            bundle: .module
        )
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.82),
        ]
        let attributed = NSAttributedString(string: hint, attributes: attributes)
        let size = attributed.size()
        attributed.draw(at: CGPoint(x: (bounds.width - size.width) / 2, y: 28))
    }
}
