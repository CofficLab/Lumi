import AppKit
import Darwin
import Foundation
import LumiPreviewKit
import SwiftUI

extension HotPreviewRenderer {
    func renderPreviewEntry(
        symbolName: String,
        from handle: UnsafeMutableRawPointer
    ) -> LumiPreviewPackage.RenderResponse {
        let descriptor = previewEntryDescriptor(symbolName: symbolName, from: handle)
        if let response = renderPreviewViewEntry(
            descriptor: descriptor,
            symbolName: LumiPreviewPackage.PreviewEntryBuilder.viewSymbolName,
            from: handle
        ) {
            return response
        }

        guard let symbol = dlsym(handle, symbolName) else {
            let errorMessage = dlerror().map { String(cString: $0) } ?? "Preview entry symbol not found."
            return LumiPreviewPackage.RenderResponse(success: false, message: errorMessage)
        }

        typealias PreviewEntryFunction = @convention(c) () -> UnsafePointer<CChar>?
        let entryFunction = unsafeBitCast(symbol, to: PreviewEntryFunction.self)
        guard let payloadPointer = entryFunction() else {
            return LumiPreviewPackage.RenderResponse(success: false, message: "Preview entry returned nil.")
        }

        let payload = String(cString: payloadPointer)
        if let descriptor = Self.previewEntryDescriptor(from: payload) {
            return renderPreviewEntry(descriptor: descriptor, symbolName: symbolName)
        }

        return renderLegacyPreviewEntry(title: payload, symbolName: symbolName)
    }

    func renderPreviewEntry(
        descriptor: LumiPreviewPackage.PreviewEntryDescriptor,
        symbolName: String
    ) -> LumiPreviewPackage.RenderResponse {
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

        return LumiPreviewPackage.RenderResponse(
            success: true,
            previewID: symbolName,
            message: "Loaded preview entry \(descriptor.title)",
            previewImagePNGBase64: snapshotPNGBase64(),
            diagnostics: descriptor.diagnostics,
            isFallback: descriptor.isFallback
        )
    }

    func renderPreviewViewEntry(
        descriptor: LumiPreviewPackage.PreviewEntryDescriptor?,
        symbolName: String,
        from handle: UnsafeMutableRawPointer
    ) -> LumiPreviewPackage.RenderResponse? {
        guard let symbol = dlsym(handle, symbolName) else {
            return nil
        }

        typealias PreviewNSViewFunction = @convention(c) () -> UnsafeMutableRawPointer?
        let viewFunction = unsafeBitCast(symbol, to: PreviewNSViewFunction.self)
        guard let viewPointer = viewFunction() else {
            return LumiPreviewPackage.RenderResponse(success: false, message: "Preview view entry returned nil.")
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

        return LumiPreviewPackage.RenderResponse(
            success: true,
            previewID: symbolName,
            message: "Loaded preview view entry \(title)",
            previewImagePNGBase64: snapshotPNGBase64(),
            livePreviewEnabled: true
        )
    }

    func renderLegacyPreviewEntry(title: String, symbolName: String) -> LumiPreviewPackage.RenderResponse {
        renderPreviewEntry(
            descriptor: LumiPreviewPackage.PreviewEntryDescriptor(
                title: title,
                subtitle: "Dynamic dylib preview"
            ),
            symbolName: symbolName
        )
    }

    static func previewEntryDescriptor(from payload: String) -> LumiPreviewPackage.PreviewEntryDescriptor? {
        guard let data = payload.data(using: .utf8) else {
            return nil
        }

        return try? JSONDecoder().decode(LumiPreviewPackage.PreviewEntryDescriptor.self, from: data)
    }

    func previewEntryDescriptor(
        symbolName: String,
        from handle: UnsafeMutableRawPointer
    ) -> LumiPreviewPackage.PreviewEntryDescriptor? {
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
}
