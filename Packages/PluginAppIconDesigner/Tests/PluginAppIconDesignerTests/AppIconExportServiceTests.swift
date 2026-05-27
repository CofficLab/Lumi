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
