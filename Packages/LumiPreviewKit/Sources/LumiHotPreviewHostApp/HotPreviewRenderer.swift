import AppKit
import Darwin
import Foundation
import IOSurface
import LumiPreviewKit
import SwiftUI

@MainActor
final class HotPreviewRenderer {
    static let fallbackSnapshotSize = NSSize(width: 320, height: 180)
    static let maximumSnapshotSize = NSSize(width: 2_400, height: 2_400)

    var previewView: NSView?
    var renderWindow: NSWindow?
    var liveWindow: HotLivePreviewWindow?
    var currentDiscovery: LumiPreviewFacade.PreviewDiscovery?
    var currentConfiguration: LumiPreviewFacade.PreviewRenderConfiguration = .empty
    var loadedHandles: [UnsafeMutableRawPointer] = []
    var currentDynamicPreviewTitle: String?
    var isLivePreviewEnabled = false
    var recentSurfaces: [IOSurfaceRef] = []
    let recentSurfaceLimit = 4

    private let interposingLoader = LumiPreviewFacade.InterposingDylibLoader()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
        NSApplication.shared.finishLaunching()
    }

    func render(
        discovery: LumiPreviewFacade.PreviewDiscovery,
        configuration: LumiPreviewFacade.PreviewRenderConfiguration
    ) -> LumiPreviewFacade.RenderResponse {
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
        let snapshot = snapshotFrame(includePNG: true, includeSurface: true)

        return LumiPreviewFacade.RenderResponse(
            success: true,
            previewID: discovery.id,
            message: Self.renderedMessage(discovery: discovery, configuration: configuration),
            previewImagePNGBase64: snapshot.pngBase64,
            surfaceFrame: snapshot.surfaceFrame
        )
    }

    func refresh() -> LumiPreviewFacade.RenderResponse {
        previewView?.needsLayout = true
        let snapshot = snapshotFrame(includePNG: true, includeSurface: true)
        if let currentDiscovery {
            return LumiPreviewFacade.RenderResponse(
                success: true,
                previewID: currentDiscovery.id,
                message: "Refreshed \(currentDiscovery.title)",
                previewImagePNGBase64: snapshot.pngBase64,
                surfaceFrame: snapshot.surfaceFrame
            )
        }

        if let currentDynamicPreviewTitle {
            return LumiPreviewFacade.RenderResponse(
                success: true,
                previewID: currentDynamicPreviewTitle,
                message: "Refreshed \(currentDynamicPreviewTitle)",
                previewImagePNGBase64: snapshot.pngBase64,
                surfaceFrame: snapshot.surfaceFrame
            )
        }

        return LumiPreviewFacade.RenderResponse(
            success: false,
            message: "No preview has been rendered."
        )
    }

    func captureFrame(includeImageFallback: Bool = true) -> LumiPreviewFacade.RenderResponse {
        guard previewView != nil else {
            return LumiPreviewFacade.RenderResponse(
                success: false,
                message: "No preview has been rendered."
            )
        }

        let snapshot = snapshotFrame(includePNG: includeImageFallback, includeSurface: true)

        return LumiPreviewFacade.RenderResponse(
            success: true,
            previewID: currentDiscovery?.id ?? currentDynamicPreviewTitle,
            message: "Captured current preview frame.",
            previewImagePNGBase64: snapshot.pngBase64,
            surfaceFrame: snapshot.surfaceFrame,
            livePreviewEnabled: isLivePreviewEnabled,
            liveWindowNumber: liveWindow?.windowNumber
        )
    }

    func loadDylib(atPath path: String, previewEntrySymbol: String?) -> LumiPreviewFacade.RenderResponse {
        guard FileManager.default.fileExists(atPath: path) else {
            return LumiPreviewFacade.RenderResponse(success: false, message: "Dylib does not exist: \(path)")
        }

        guard let handle = dlopen(path, RTLD_NOW | RTLD_LOCAL) else {
            let errorMessage = dlerror().map { String(cString: $0) } ?? "Unknown dlopen error."
            return LumiPreviewFacade.RenderResponse(success: false, message: errorMessage)
        }

        loadedHandles.append(handle)

        if let previewEntrySymbol {
            return renderPreviewEntry(symbolName: previewEntrySymbol, from: handle)
        }

        return LumiPreviewFacade.RenderResponse(
            success: true,
            message: "Loaded \(URL(fileURLWithPath: path).lastPathComponent)"
        )
    }

    func interposeDylib(
        atPath path: String,
        previewEntrySymbol: String?
    ) async -> LumiPreviewFacade.RenderResponse {
        do {
            _ = try await interposingLoader.load(
                dylibPath: path,
                symbolName: previewEntrySymbol,
                mode: RTLD_NOW | RTLD_GLOBAL
            )
        } catch {
            return LumiPreviewFacade.RenderResponse(
                success: false,
                previewID: currentDiscovery?.id ?? currentDynamicPreviewTitle,
                message: error.localizedDescription
            )
        }

        previewView?.needsLayout = true
        previewView?.needsDisplay = true
        liveWindow?.contentView?.needsLayout = true
        liveWindow?.contentView?.needsDisplay = true

        let snapshot = snapshotFrame(includePNG: true, includeSurface: true)
        return LumiPreviewFacade.RenderResponse(
            success: true,
            previewID: currentDiscovery?.id ?? currentDynamicPreviewTitle ?? previewEntrySymbol,
            message: "Interposed preview dylib.",
            previewImagePNGBase64: snapshot.pngBase64,
            surfaceFrame: snapshot.surfaceFrame,
            livePreviewEnabled: isLivePreviewEnabled,
            liveWindowNumber: liveWindow?.windowNumber
        )
    }

    private static func renderedMessage(
        discovery: LumiPreviewFacade.PreviewDiscovery,
        configuration: LumiPreviewFacade.PreviewRenderConfiguration
    ) -> String {
        guard configuration.hasEnvironmentInjections else {
            return "Rendered \(discovery.title)"
        }

        return "Rendered \(discovery.title) with \(configuration.environmentInjections.count) environment injection(s)"
    }
}
