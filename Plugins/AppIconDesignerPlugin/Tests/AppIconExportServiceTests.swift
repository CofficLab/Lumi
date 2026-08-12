import AppKit
import Testing
import Foundation
@testable import AppIconDesignerPlugin

@MainActor
@Suite("PluginAppIconDesigner")
struct AppIconExportServiceTests {
    @Test("exports an Xcode 26 Icon Composer package")
    func exportsIconComposerPackage() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginIconComposerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let document = IconDocument(
            title: "Cross-version Icon",
            background: .linearGradient(
                colors: ["#111827", "#2563eb"],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            layers: [
                IconLayer(
                    name: "Mark",
                    shape: .circle(cx: 512, cy: 512, radius: 240),
                    fill: .color("#ffffff")
                )
            ]
        )

        let result = try IconComposerExportService().export(
            document: document,
            outputDirectory: tempRoot
        )

        let manifestURL = result.iconURL.appendingPathComponent("icon.json")
        let artworkURL = result.iconURL.appendingPathComponent("Assets/Artwork.png")
        #expect(result.iconURL.lastPathComponent == "AppIcon.icon")
        #expect(FileManager.default.fileExists(atPath: manifestURL.path))
        #expect(FileManager.default.fileExists(atPath: artworkURL.path))

        let object = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as? [String: Any]
        )
        let platforms = try #require(object["supported-platforms"] as? [String: Any])
        #expect(platforms["squares"] as? [String] == ["macOS"])

        let groups = try #require(object["groups"] as? [[String: Any]])
        let layers = try #require(groups.first?["layers"] as? [[String: Any]])
        #expect(layers.first?["image-name"] as? String == "Artwork.png")

        let bitmap = try #require(NSBitmapImageRep(data: Data(contentsOf: artworkURL)))
        #expect(bitmap.pixelsWide == 1024)
        #expect(bitmap.pixelsHigh == 1024)
    }

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

    @Test("keeps previous appiconset when replacement fails")
    func keepsPreviousAppIconSetWhenReplacementFails() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginAppIconDesignerReplacementTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let sourceURL = tempRoot.appendingPathComponent("source.png")
        try makeSourceImage().write(to: sourceURL)

        let existingAppIconSetURL = tempRoot.appendingPathComponent("AppIcon.appiconset", isDirectory: true)
        try FileManager.default.createDirectory(at: existingAppIconSetURL, withIntermediateDirectories: true)
        let sentinelURL = existingAppIconSetURL.appendingPathComponent("existing.txt")
        try "keep me".write(to: sentinelURL, atomically: true, encoding: .utf8)

        let service = AppIconExportService(
            replaceItem: { _, _ in
                throw CocoaError(.fileWriteUnknown)
            }
        )

        #expect(throws: CocoaError.self) {
            _ = try service.exportAppIconSet(
                sourceImagePath: sourceURL.path,
                outputDirectory: tempRoot
            )
        }

        #expect(FileManager.default.fileExists(atPath: existingAppIconSetURL.path))
        #expect(FileManager.default.fileExists(atPath: sentinelURL.path))
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
    @Test("rejects blank export directory before writing appiconset")
    func rejectsBlankExportDirectory() async throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginAppIconDesignerBlankDirectoryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let sourceURL = tempRoot.appendingPathComponent("candidate.png")
        try makeSourceImage().write(to: sourceURL)

        let store = AppIconArtifactStore()
        try store.registerImage(path: sourceURL.path, title: "Candidate")
        let viewModel = AppIconDesignerViewModel(store: store)
        viewModel.exportDirectory = "   "

        await viewModel.exportSelected()

        #expect(store.lastError == AppIconExportDirectoryError.empty.localizedDescription)
        #expect(store.lastExportURL == nil)
    }

    @MainActor
    @Test("rejects file export path before writing appiconset")
    func rejectsFileExportPath() async throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginAppIconDesignerFileDirectoryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let sourceURL = tempRoot.appendingPathComponent("candidate.png")
        try makeSourceImage().write(to: sourceURL)
        let fileURL = tempRoot.appendingPathComponent("not-a-directory")
        try "file".write(to: fileURL, atomically: true, encoding: .utf8)

        let store = AppIconArtifactStore()
        try store.registerImage(path: sourceURL.path, title: "Candidate")
        let viewModel = AppIconDesignerViewModel(store: store)
        viewModel.exportDirectory = fileURL.path

        await viewModel.exportSelected()

        #expect(store.lastError == AppIconExportDirectoryError.notDirectory(fileURL.path).localizedDescription)
        #expect(store.lastExportURL == nil)
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
