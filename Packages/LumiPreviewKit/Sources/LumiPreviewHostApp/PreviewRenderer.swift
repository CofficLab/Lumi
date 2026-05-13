import AppKit
import Darwin
import Foundation
import LumiPreviewKit
import SwiftUI

@MainActor
final class PreviewRenderer {
    static let fallbackSnapshotSize = NSSize(width: 320, height: 180)
    static let maximumSnapshotSize = NSSize(width: 2_400, height: 2_400)

    var previewView: NSView?
    var renderWindow: NSWindow?
    var liveWindow: LivePreviewWindow?
    var currentDiscovery: LumiPreviewPackage.PreviewDiscovery?
    var currentConfiguration: LumiPreviewPackage.PreviewRenderConfiguration = .empty
    var loadedHandles: [UnsafeMutableRawPointer] = []
    var currentDynamicPreviewTitle: String?
    var isLivePreviewEnabled = false

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
        NSApplication.shared.finishLaunching()
    }

    func render(
        discovery: LumiPreviewPackage.PreviewDiscovery,
        configuration: LumiPreviewPackage.PreviewRenderConfiguration
    ) -> LumiPreviewPackage.RenderResponse {
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

        return LumiPreviewPackage.RenderResponse(
            success: true,
            previewID: discovery.id,
            message: Self.renderedMessage(discovery: discovery, configuration: configuration),
            previewImagePNGBase64: snapshotPNGBase64()
        )
    }

    func refresh() -> LumiPreviewPackage.RenderResponse {
        previewView?.needsLayout = true
        if let currentDiscovery {
            return LumiPreviewPackage.RenderResponse(
                success: true,
                previewID: currentDiscovery.id,
                message: "Refreshed \(currentDiscovery.title)",
                previewImagePNGBase64: snapshotPNGBase64()
            )
        }

        if let currentDynamicPreviewTitle {
            return LumiPreviewPackage.RenderResponse(
                success: true,
                previewID: currentDynamicPreviewTitle,
                message: "Refreshed \(currentDynamicPreviewTitle)",
                previewImagePNGBase64: snapshotPNGBase64()
            )
        }

        return LumiPreviewPackage.RenderResponse(
            success: false,
            message: "No preview has been rendered."
        )
    }

    func loadDylib(atPath path: String, previewEntrySymbol: String?) -> LumiPreviewPackage.RenderResponse {
        guard FileManager.default.fileExists(atPath: path) else {
            return LumiPreviewPackage.RenderResponse(success: false, message: "Dylib does not exist: \(path)")
        }

        guard let handle = dlopen(path, RTLD_NOW | RTLD_LOCAL) else {
            let errorMessage = dlerror().map { String(cString: $0) } ?? "Unknown dlopen error."
            return LumiPreviewPackage.RenderResponse(success: false, message: errorMessage)
        }

        loadedHandles.append(handle)

        if let previewEntrySymbol {
            return renderPreviewEntry(symbolName: previewEntrySymbol, from: handle)
        }

        return LumiPreviewPackage.RenderResponse(success: true, message: "Loaded \(URL(fileURLWithPath: path).lastPathComponent)")
    }

    private static func renderedMessage(
        discovery: LumiPreviewPackage.PreviewDiscovery,
        configuration: LumiPreviewPackage.PreviewRenderConfiguration
    ) -> String {
        guard configuration.hasEnvironmentInjections else {
            return "Rendered \(discovery.title)"
        }

        return "Rendered \(discovery.title) with \(configuration.environmentInjections.count) environment injection(s)"
    }
}
