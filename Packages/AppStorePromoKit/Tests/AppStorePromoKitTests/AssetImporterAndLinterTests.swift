import Foundation
import ImageIO
import Testing
@testable import AppStorePromoKit

@Suite("Asset importer")
struct AppStorePromoAssetImporterTests {
    private func makePNG(width: Int = 4, height: Int = 3) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("sample.png")

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = ctx.makeImage()!
        let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
        return url
    }

    @Test func importsImageAndReportsPixelSize() throws {
        let source = try makePNG()
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }
        let destDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: destDir) }

        let asset = try AppStorePromoAssetImporter().importImage(
            sourceURL: source, destinationDirectory: destDir, preferredFileName: "hero art.png"
        )
        #expect(asset.pixelWidth == 4)
        #expect(asset.pixelHeight == 3)
        #expect(asset.relativePath == "./assets/hero-art.png")
        #expect(FileManager.default.fileExists(atPath: asset.fileURL.path))
    }

    @Test func collidingFileNamesGetSuffix() throws {
        let source = try makePNG()
        defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }
        let destDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: destDir) }

        let first = try AppStorePromoAssetImporter().importImage(
            sourceURL: source, destinationDirectory: destDir, preferredFileName: "hero.png"
        )
        let second = try AppStorePromoAssetImporter().importImage(
            sourceURL: source, destinationDirectory: destDir, preferredFileName: "hero.png"
        )
        #expect(first.fileURL.lastPathComponent == "hero.png")
        #expect(second.fileURL.lastPathComponent == "hero-2.png")
    }

    @Test func missingSourceThrows() {
        #expect(throws: AppStorePromoAssetError.sourceNotFound("/nonexistent/a.png")) {
            _ = try AppStorePromoAssetImporter().importImage(
                sourceURL: URL(fileURLWithPath: "/nonexistent/a.png"),
                destinationDirectory: FileManager.default.temporaryDirectory
            )
        }
    }

    @Test func nonImageThrowsUnsupported() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("notes.txt")
        try Data("not an image".utf8).write(to: file)

        #expect(throws: AppStorePromoAssetError.unsupportedImage(file.path)) {
            _ = try AppStorePromoAssetImporter().importImage(
                sourceURL: file, destinationDirectory: dir
            )
        }
    }
}

@Suite("HTML linter edge cases")
struct AppStorePromoHTMLLinterTests {
    private func minimalHTML(body: String = "") -> String {
        """
        <!doctype html><html><head><meta name="viewport" content="width=device-width"></head>
        <body style="background-color: white; overflow: hidden">\(body)</body></html>
        """
    }

    @Test func acceptsMinimalDocument() {
        let report = AppStorePromoHTMLLinter().lint(html: minimalHTML())
        #expect(report.isValid)
        #expect(report.warnings.isEmpty)
    }

    @Test func oversizedHTMLFails() {
        let big = minimalHTML(body: String(repeating: "x", count: 1_100_000))
        let report = AppStorePromoHTMLLinter(maximumUTF8Bytes: 1_000_000).lint(html: big)
        #expect(report.errors.map(\.code).contains("html_too_large"))
    }

    @Test func missingViewportAndDoctypeFail() {
        let report = AppStorePromoHTMLLinter().lint(html: "<html><body></body></html>")
        #expect(report.errors.map(\.code).contains("incomplete_document"))
        #expect(report.errors.map(\.code).contains("missing_viewport"))
    }

    @Test func iframeAndCSSImportFail() {
        let html = minimalHTML(body: "<iframe src='x.html'></iframe><style>@import 'a.css';</style>")
        let report = AppStorePromoHTMLLinter().lint(html: html)
        #expect(report.errors.map(\.code).contains("iframe_forbidden"))
        #expect(report.errors.map(\.code).contains("css_import_forbidden"))
    }

    @Test func animationAndMissingBackgroundWarn() {
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width"></head>
        <body style="overflow: hidden; animation: none"><style>div { transition: all 1s; }</style></body></html>
        """
        let report = AppStorePromoHTMLLinter().lint(html: html)
        #expect(report.warnings.map(\.code).contains("motion_disabled"))
        #expect(report.warnings.map(\.code).contains("background_missing"))
        #expect(report.isValid)
    }

    @Test func absoluteAndParentPathsAreUnsafe() {
        let html = minimalHTML(body: #"<img src="/etc/passwd"><img src="../outside.png">"#)
        let report = AppStorePromoHTMLLinter().lint(html: html)
        let unsafe = report.errors.filter { $0.code == "unsafe_asset_path" }
        #expect(unsafe.count == 2)
    }

    @Test func missingLocalAssetFailsWhenDirectoryProvided() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data([0xFF]).write(to: dir.appendingPathComponent("real.png"))

        let html = minimalHTML(body: #"<img src="./real.png"><img src="./ghost.png">"#)
        let report = AppStorePromoHTMLLinter().lint(html: html, documentDirectory: dir)
        #expect(report.errors.map(\.code).contains("missing_asset"))
        #expect(!report.errors.map(\.code).contains("unsafe_asset_path"))
    }

    @Test func dataURIsAreSkipped() {
        let html = minimalHTML(body: #"<img src="data:image/png;base64,AAAA">"#)
        let report = AppStorePromoHTMLLinter().lint(html: html, documentDirectory: FileManager.default.temporaryDirectory)
        #expect(!report.errors.map(\.code).contains("missing_asset"))
    }
}
