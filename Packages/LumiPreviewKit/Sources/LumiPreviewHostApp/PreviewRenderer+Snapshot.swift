import AppKit
import Foundation

extension PreviewRenderer {
    func snapshotPNGBase64() -> String? {
        guard let previewView else { return nil }
        return snapshotPNGBase64(for: previewView)
    }

    func snapshotPNGBase64(for view: NSView) -> String? {
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
}
