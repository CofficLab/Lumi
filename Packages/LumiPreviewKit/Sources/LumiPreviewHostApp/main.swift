import Foundation
import LumiPreviewKit
import AppKit
import SwiftUI
import Darwin

/// 独立预览宿主程序入口。
///
/// 当前阶段实现 stdin/stdout JSON 通信；真实 SwiftUI 视图装载会在后续引擎集成中接入。
@main
struct LumiPreviewHostApp {
    @MainActor
    static func main() {
        StdioPreviewHost().run()
    }
}

@MainActor
private struct StdioPreviewHost {
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let renderer = PreviewRenderer()

    func run() {
        while let line = readLine() {
            guard let data = line.data(using: .utf8) else {
                write(ErrorResponse(message: "Request is not valid UTF-8."))
                continue
            }

            do {
                let request = try decoder.decode(RenderRequest.self, from: data)
                write(handle(request))
            } catch {
                write(ErrorResponse(message: "Invalid request: \(error.localizedDescription)"))
            }
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
        }
    }

    private func write<Response: Encodable>(_ response: Response) {
        do {
            let data = try encoder.encode(response)
            if let string = String(data: data, encoding: .utf8) {
                print(string)
                fflush(stdout)
            }
        } catch {
            print(#"{"message":"Failed to encode response."}"#)
            fflush(stdout)
        }
    }
}

@MainActor
private final class PreviewRenderer {
    private var previewView: NSView?
    private var currentDiscovery: PreviewDiscovery?
    private var currentConfiguration: PreviewRenderConfiguration = .empty
    private var loadedHandles: [UnsafeMutableRawPointer] = []
    private var currentDynamicPreviewTitle: String?

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

        let title = descriptor?.title ?? symbolName
        currentDynamicPreviewTitle = title

        return RenderResponse(
            success: true,
            previewID: symbolName,
            message: "Loaded preview view entry \(title)",
            previewImagePNGBase64: snapshotPNGBase64()
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

    private func snapshotPNGBase64() -> String? {
        guard let previewView else { return nil }

        previewView.layoutSubtreeIfNeeded()
        let bounds = previewView.bounds
        guard !bounds.isEmpty,
              let bitmap = previewView.bitmapImageRepForCachingDisplay(in: bounds) else {
            return nil
        }

        previewView.cacheDisplay(in: bounds, to: bitmap)
        return bitmap.representation(using: .png, properties: [:])?.base64EncodedString()
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
