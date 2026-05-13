import AppKit
import Darwin
import Foundation
import LumiPreviewKit

extension PreviewRenderer {
    func startLivePreview() -> LumiPreviewPackage.RenderResponse {
        guard isLivePreviewEnabled, let previewView else {
            return LumiPreviewPackage.RenderResponse(
                success: false,
                message: "Live preview is not available: no real NSView entry loaded."
            )
        }

        if liveWindow != nil {
            return LumiPreviewPackage.RenderResponse(
                success: true,
                message: "Live preview already running.",
                livePreviewEnabled: true,
                liveWindowNumber: liveWindow?.windowNumber
            )
        }

        let frame = NSRect(x: 0, y: 0, width: 320, height: 180)
        let window = LivePreviewWindow(contentRect: frame)
        window.contentView = previewView
        // Position off-screen until updateLiveFrame positions it correctly.
        window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))

        liveWindow = window

        return LumiPreviewPackage.RenderResponse(
            success: true,
            message: "Live preview started.",
            livePreviewEnabled: true,
            liveWindowNumber: window.windowNumber
        )
    }

    func updateLiveFrame(x: Double, y: Double, width: Double, height: Double, scale: Double) -> LumiPreviewPackage.RenderResponse {
        guard let liveWindow else {
            return LumiPreviewPackage.RenderResponse(success: false, message: "No live window to update.")
        }

        let frame = LumiPreviewPackage.LivePreviewFrameAlignment.pixelAlignedFrame(
            NSRect(x: x, y: y, width: width, height: height),
            scale: scale
        )
        liveWindow.setFrame(frame, display: true)

        return LumiPreviewPackage.RenderResponse(
            success: true,
            message: "Live frame updated to (\(x), \(y), \(width)x\(height)).",
            livePreviewEnabled: true,
            liveWindowNumber: liveWindow.windowNumber
        )
    }

    func showLivePreview() -> LumiPreviewPackage.RenderResponse {
        guard let liveWindow else {
            return LumiPreviewPackage.RenderResponse(success: false, message: "No live window to show.")
        }
        guard liveWindow.contentView != nil else {
            return LumiPreviewPackage.RenderResponse(success: false, message: "No live preview content to show.")
        }

        // The host app stays in accessory/background mode, so a normal orderFront
        // is not always enough to surface the overlay above Lumi's active window.
        // Keep the panel at normal level, but force this specific show operation.
        liveWindow.orderFrontRegardless()

        return LumiPreviewPackage.RenderResponse(
            success: true,
            message: "Live preview shown.",
            livePreviewEnabled: true,
            liveWindowNumber: liveWindow.windowNumber
        )
    }

    func hideLivePreview() -> LumiPreviewPackage.RenderResponse {
        guard let liveWindow else {
            return LumiPreviewPackage.RenderResponse(success: false, message: "No live window to hide.")
        }

        hideLiveWindow(liveWindow)

        return LumiPreviewPackage.RenderResponse(
            success: true,
            message: "Live preview hidden.",
            livePreviewEnabled: true,
            liveWindowNumber: liveWindow.windowNumber
        )
    }

    func reloadLivePreview(dylibPath: String, previewEntrySymbol: String?) -> LumiPreviewPackage.RenderResponse {
        guard FileManager.default.fileExists(atPath: dylibPath) else {
            return LumiPreviewPackage.RenderResponse(success: false, message: "Dylib does not exist: \(dylibPath)")
        }

        guard let handle = dlopen(dylibPath, RTLD_NOW | RTLD_LOCAL) else {
            let errorMessage = dlerror().map { String(cString: $0) } ?? "Unknown dlopen error."
            return LumiPreviewPackage.RenderResponse(success: false, message: errorMessage)
        }

        loadedHandles.append(handle)

        guard let previewEntrySymbol else {
            return LumiPreviewPackage.RenderResponse(success: false, message: "Reload requires previewEntrySymbol.")
        }

        let descriptor = previewEntryDescriptor(symbolName: previewEntrySymbol, from: handle)
        if let symbol = dlsym(handle, LumiPreviewPackage.PreviewEntryBuilder.viewSymbolName) {
            typealias PreviewNSViewFunction = @convention(c) () -> UnsafeMutableRawPointer?
            let viewFunction = unsafeBitCast(symbol, to: PreviewNSViewFunction.self)
            if let viewPointer = viewFunction() {
                let view = Unmanaged<NSView>.fromOpaque(viewPointer).takeRetainedValue()
                if view.frame.isEmpty {
                    view.frame = NSRect(x: 0, y: 0, width: 320, height: 180)
                }
                let title = descriptor?.title ?? previewEntrySymbol

                let snapshot = snapshotFrame(for: view, includePNG: true, includeSurface: true)

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
                    liveWindow?.orderFrontRegardless()
                }

                return LumiPreviewPackage.RenderResponse(
                    success: true,
                    message: "Reloaded live preview view entry \(title)",
                    previewImagePNGBase64: snapshot.pngBase64,
                    surfaceFrame: snapshot.surfaceFrame,
                    livePreviewEnabled: true,
                    liveWindowNumber: liveWindow?.windowNumber
                )
            }
        }

        return LumiPreviewPackage.RenderResponse(
            success: false,
            message: "Reload failed: could not create NSView from new dylib."
        )
    }

    func stopLivePreview() -> LumiPreviewPackage.RenderResponse {
        if let liveWindow {
            hideLiveWindow(liveWindow)
        }
        liveWindow?.contentView = nil
        liveWindow?.close()
        liveWindow = nil

        return LumiPreviewPackage.RenderResponse(
            success: true,
            message: "Live preview stopped."
        )
    }

    private func hideLiveWindow(_ liveWindow: LivePreviewWindow) {
        liveWindow.orderOut(nil)
    }
}
