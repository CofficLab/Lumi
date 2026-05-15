import AppKit
import Darwin
import Foundation
import LumiPreviewKit

extension HotPreviewRenderer {
    func startLivePreview() -> LumiPreviewFacade.RenderResponse {
        guard isLivePreviewEnabled, let previewView else {
            return LumiPreviewFacade.RenderResponse(
                success: false,
                message: "Live preview is not available: no real NSView entry loaded."
            )
        }

        if liveWindow != nil {
            return LumiPreviewFacade.RenderResponse(
                success: true,
                message: "Live preview already running.",
                livePreviewEnabled: true,
                liveWindowNumber: liveWindow?.windowNumber
            )
        }

        let frame = NSRect(x: 0, y: 0, width: 320, height: 180)
        let window = HotLivePreviewWindow(contentRect: frame)
        window.contentView = previewView
        window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))

        liveWindow = window

        return LumiPreviewFacade.RenderResponse(
            success: true,
            message: "Live preview started.",
            livePreviewEnabled: true,
            liveWindowNumber: window.windowNumber
        )
    }

    func updateLiveFrame(x: Double, y: Double, width: Double, height: Double, scale: Double) -> LumiPreviewFacade.RenderResponse {
        guard let liveWindow else {
            return LumiPreviewFacade.RenderResponse(success: false, message: "No live window to update.")
        }

        let frame = LumiPreviewFacade.PreviewFrameAlignment.pixelAlignedFrame(
            NSRect(x: x, y: y, width: width, height: height),
            scale: scale
        )
        liveWindow.setFrame(frame, display: true)

        return LumiPreviewFacade.RenderResponse(
            success: true,
            message: "Live frame updated to (\(x), \(y), \(width)x\(height)).",
            livePreviewEnabled: true,
            liveWindowNumber: liveWindow.windowNumber
        )
    }

    func showLivePreview() -> LumiPreviewFacade.RenderResponse {
        guard let liveWindow else {
            return LumiPreviewFacade.RenderResponse(success: false, message: "No live window to show.")
        }
        guard liveWindow.contentView != nil else {
            return LumiPreviewFacade.RenderResponse(success: false, message: "No live preview content to show.")
        }

        liveWindow.orderFront(nil)

        return LumiPreviewFacade.RenderResponse(
            success: true,
            message: "Live preview shown.",
            livePreviewEnabled: true,
            liveWindowNumber: liveWindow.windowNumber
        )
    }

    func hideLivePreview() -> LumiPreviewFacade.RenderResponse {
        guard let liveWindow else {
            return LumiPreviewFacade.RenderResponse(success: false, message: "No live window to hide.")
        }

        hideLiveWindow(liveWindow)

        return LumiPreviewFacade.RenderResponse(
            success: true,
            message: "Live preview hidden.",
            livePreviewEnabled: true,
            liveWindowNumber: liveWindow.windowNumber
        )
    }

    func reloadLivePreview(dylibPath: String, previewEntrySymbol: String?) -> LumiPreviewFacade.RenderResponse {
        guard FileManager.default.fileExists(atPath: dylibPath) else {
            return LumiPreviewFacade.RenderResponse(success: false, message: "Dylib does not exist: \(dylibPath)")
        }

        guard let handle = dlopen(dylibPath, RTLD_NOW | RTLD_LOCAL) else {
            let errorMessage = dlerror().map { String(cString: $0) } ?? "Unknown dlopen error."
            return LumiPreviewFacade.RenderResponse(success: false, message: errorMessage)
        }

        loadedHandles.append(handle)

        guard let previewEntrySymbol else {
            return LumiPreviewFacade.RenderResponse(success: false, message: "Reload requires previewEntrySymbol.")
        }

        let descriptor = previewEntryDescriptor(symbolName: previewEntrySymbol, from: handle)
        if let symbol = dlsym(handle, LumiPreviewFacade.PreviewEntryBuilder.viewSymbolName) {
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
                liveWindow?.contentView = view
                if let liveFrame {
                    liveWindow?.setFrame(liveFrame, display: true)
                }
                if wasVisible {
                    liveWindow?.orderFront(nil)
                }

                return LumiPreviewFacade.RenderResponse(
                    success: true,
                    message: "Reloaded live preview view entry \(title)",
                    previewImagePNGBase64: snapshot.pngBase64,
                    surfaceFrame: snapshot.surfaceFrame,
                    livePreviewEnabled: true,
                    liveWindowNumber: liveWindow?.windowNumber
                )
            }
        }

        return LumiPreviewFacade.RenderResponse(
            success: false,
            message: "Reload failed: could not create NSView from new dylib."
        )
    }

    func stopLivePreview() -> LumiPreviewFacade.RenderResponse {
        if let liveWindow {
            hideLiveWindow(liveWindow)
        }
        liveWindow?.contentView = nil
        liveWindow?.close()
        liveWindow = nil

        return LumiPreviewFacade.RenderResponse(
            success: true,
            message: "Live preview stopped."
        )
    }

    private func hideLiveWindow(_ liveWindow: HotLivePreviewWindow) {
        liveWindow.orderOut(nil)
    }
}
