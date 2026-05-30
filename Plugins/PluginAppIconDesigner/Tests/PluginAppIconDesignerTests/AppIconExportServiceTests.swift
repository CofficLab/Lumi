import AppKit
import Testing
import Foundation
@testable import PluginAppIconDesigner

@Suite("PluginAppIconDesigner")
struct AppIconExportServiceTests {
    @Test("exports macOS appiconset")
    func exportsAppIconSet() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginAppIconDesignerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let sourceURL = tempRoot.appendingPathComponent("source.png")
        try makeSourceImage().write(to: sourceURL)

        let result = try AppIconExportService().exportAppIconSet(
            sourceImagePath: sourceURL.path,
            outputDirectory: tempRoot
        )

        #expect(FileManager.default.fileExists(atPath: result.appIconSetURL.path))
        #expect(FileManager.default.fileExists(atPath: result.appIconSetURL.appendingPathComponent("Contents.json").path))
        #expect(result.imageCount == 10)
    }

    @Test("sanitizes appiconset names")
    func sanitizesAppIconSetNames() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginAppIconDesignerSafeNameTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let sourceURL = tempRoot.appendingPathComponent("source.png")
        try makeSourceImage().write(to: sourceURL)

        let result = try AppIconExportService().exportAppIconSet(
            sourceImagePath: sourceURL.path,
            outputDirectory: tempRoot,
            setName: "../Bad Name"
        )

        #expect(result.appIconSetURL.deletingLastPathComponent() == tempRoot)
        #expect(result.appIconSetURL.lastPathComponent == "Bad-Name.appiconset")
    }

    @MainActor
    @Test("registers generated artifact")
    func registersArtifact() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginAppIconDesignerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let sourceURL = tempRoot.appendingPathComponent("candidate.png")
        try makeSourceImage().write(to: sourceURL)

        let store = AppIconArtifactStore()
        let artifact = try store.registerImage(path: sourceURL.path, title: "Candidate", prompt: "blue icon")

        #expect(artifact.title == "Candidate")
        #expect(store.selectedArtifactId == artifact.id)
        #expect(store.artifacts.count == 1)
    }

    @MainActor
    @Test("exports SwiftUI document appiconset")
    func exportsSwiftUIDocumentAppIconSet() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginAppIconDesignerDocumentTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let document = IconDocument(
            title: "SwiftUI Icon",
            background: .linearGradient(
                colors: ["#111827", "#2563eb", "#38bdf8"],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            layers: [
                IconLayer(
                    name: "Sparkles",
                    shape: .symbol(name: "sparkles", x: 512, y: 512, size: 420, weight: "semibold"),
                    fill: .color("#ffffff"),
                    shadow: IconShadow(color: "#00000055", radius: 32, x: 0, y: 18)
                )
            ]
        )

        let result = try AppIconExportService().exportAppIconSet(
            document: document,
            outputDirectory: tempRoot
        )

        #expect(FileManager.default.fileExists(atPath: result.appIconSetURL.path))
        #expect(FileManager.default.fileExists(atPath: result.appIconSetURL.appendingPathComponent("icon_512x512@2x.png").path))
        #expect(result.imageCount == 10)

        let largeIconURL = result.appIconSetURL.appendingPathComponent("icon_512x512@2x.png")
        let bitmap = try #require(NSBitmapImageRep(data: try Data(contentsOf: largeIconURL)))
        #expect(bitmap.pixelsWide == 1024)
        #expect(bitmap.pixelsHigh == 1024)

        let center = try #require(bitmap.colorAt(x: 512, y: 512))
        let corner = try #require(bitmap.colorAt(x: 16, y: 16))
        #expect(center.alphaComponent > 0.95)
        #expect(corner.alphaComponent > 0.95)
        #expect(abs(center.redComponent - corner.redComponent) > 0.05 || abs(center.greenComponent - corner.greenComponent) > 0.05 || abs(center.blueComponent - corner.blueComponent) > 0.05)
    }

    @Test("lints document quality")
    func lintsDocumentQuality() {
        let document = IconDocument(
            width: 1024,
            height: 800,
            layers: [
                IconLayer(
                    name: "Tiny Text",
                    shape: .text(value: "LONGTEXT", x: 512, y: 512, size: 32, weight: "regular"),
                    fill: .color("#ffffff")
                )
            ]
        )

        let report = IconDocumentLinter().lint(document)

        #expect(report.isExportable)
        #expect(report.warnings.contains { $0.message.contains("not square") })
        #expect(report.warnings.contains { $0.message.contains("unreadable") })
        #expect(report.warnings.contains { $0.message.contains("very small") })
    }

    @MainActor
    @Test("blocks non exportable document appiconset")
    func blocksNonExportableDocumentAppIconSet() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginAppIconDesignerBlockedExportTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let document = IconDocument(
            layers: [
                IconLayer(
                    name: "Zero Line",
                    shape: .line(x1: 512, y1: 512, x2: 512, y2: 512),
                    fill: .color("#ffffff"),
                    stroke: IconStroke(color: "#ffffff", width: 24)
                )
            ]
        )

        #expect(throws: IconDocumentLintError.self) {
            _ = try AppIconExportService().exportAppIconSet(document: document, outputDirectory: tempRoot)
        }
    }

    private func makeSourceImage() throws -> Data {
        let image = NSImage(size: NSSize(width: 1024, height: 1024))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: 256, y: 256, width: 512, height: 512)).fill()
        image.unlockFocus()

        guard
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let data = bitmap.representation(using: .png, properties: [:])
        else {
            throw TestImageError.renderFailed
        }
        return data
    }
}

private enum TestImageError: Error {
    case renderFailed
}
