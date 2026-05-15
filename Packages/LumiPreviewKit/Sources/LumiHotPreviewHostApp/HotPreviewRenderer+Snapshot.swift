import AppKit
import CoreGraphics
import Foundation
import IOSurface
import LumiPreviewKit

extension HotPreviewRenderer {
    struct SnapshotFrame {
        let pngBase64: String?
        let surfaceFrame: LumiPreviewPackage.PreviewSurfaceFrame?
    }

    private static let bgraPixelFormat: UInt32 =
        UInt32(UInt8(ascii: "B")) << 24 |
        UInt32(UInt8(ascii: "G")) << 16 |
        UInt32(UInt8(ascii: "R")) << 8 |
        UInt32(UInt8(ascii: "A"))

    func snapshotFrame(includePNG: Bool = true, includeSurface: Bool = true) -> SnapshotFrame {
        guard let previewView else {
            return SnapshotFrame(pngBase64: nil, surfaceFrame: nil)
        }
        return snapshotFrame(for: previewView, includePNG: includePNG, includeSurface: includeSurface)
    }

    func snapshotFrame(for view: NSView, includePNG: Bool = true, includeSurface: Bool = true) -> SnapshotFrame {
        guard let snapshot = snapshotBitmap(for: view) else {
            return SnapshotFrame(pngBase64: nil, surfaceFrame: nil)
        }

        let pngBase64 = includePNG
            ? snapshot.bitmap.representation(using: .png, properties: [:])?.base64EncodedString()
            : nil
        let surfaceFrame = includeSurface
            ? snapshotSurfaceFrame(for: snapshot.image, pointsSize: snapshot.pointsSize)
            : nil
        return SnapshotFrame(pngBase64: pngBase64, surfaceFrame: surfaceFrame)
    }

    func snapshotPNGBase64() -> String? {
        guard let previewView else { return nil }
        return snapshotPNGBase64(for: previewView)
    }

    func snapshotPNGBase64(for view: NSView) -> String? {
        snapshotFrame(for: view, includePNG: true, includeSurface: false).pngBase64
    }

    func snapshotBitmap(for view: NSView) -> (bitmap: NSBitmapImageRep, image: CGImage, pointsSize: CGSize)? {
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
        guard let image = bitmap.cgImage else { return nil }
        return (bitmap, image, bounds.size)
    }

    private func snapshotSurfaceFrame(for image: CGImage, pointsSize: CGSize) -> LumiPreviewPackage.PreviewSurfaceFrame? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }

        let bytesPerRow = width * 4
        let properties: [CFString: Any] = [
            kIOSurfaceWidth: width,
            kIOSurfaceHeight: height,
            kIOSurfaceBytesPerElement: 4,
            kIOSurfaceBytesPerRow: bytesPerRow,
            kIOSurfacePixelFormat: Self.bgraPixelFormat,
            kIOSurfaceIsGlobal: true
        ]

        guard let surface = IOSurfaceCreate(properties as CFDictionary) else {
            return nil
        }

        var seed: UInt32 = 0
        let baseAddress = IOSurfaceGetBaseAddress(surface)
        guard IOSurfaceLock(surface, [], &seed) == KERN_SUCCESS,
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
              ) else {
            _ = IOSurfaceUnlock(surface, [], &seed)
            return nil
        }

        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        _ = IOSurfaceUnlock(surface, [], &seed)

        retainRecentSurface(surface)
        let scale = pointsSize.width > 0 ? Double(width) / Double(pointsSize.width) : 1
        return LumiPreviewPackage.PreviewSurfaceFrame(
            surfaceID: UInt32(IOSurfaceGetID(surface)),
            width: width,
            height: height,
            scale: scale,
            pixelFormat: "BGRA",
            bytesPerRow: bytesPerRow
        )
    }

    private func retainRecentSurface(_ surface: IOSurfaceRef) {
        recentSurfaces.append(surface)
        if recentSurfaces.count > recentSurfaceLimit {
            recentSurfaces.removeFirst(recentSurfaces.count - recentSurfaceLimit)
        }
    }

    func prepareViewForSnapshot(_ view: NSView, preferredSize: NSSize? = nil) -> NSRect {
        let size = preferredSize ?? Self.snapshotSize(for: view)
        let frame = NSRect(origin: .zero, size: Self.clampedSnapshotSize(size))

        if let window = view.window, window !== renderWindow {
            if window === liveWindow {
                liveWindow?.setContentSize(frame.size)
            }

            view.frame = frame
            view.needsLayout = true
            view.needsDisplay = true
            view.layoutSubtreeIfNeeded()
            view.displayIfNeeded()

            return view.bounds.isEmpty ? frame : view.bounds
        }

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

    func flushPreviewRendering() {
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
