import Foundation
import ImageIO
import Testing
@testable import AppStorePromoKit

@Suite("App Store promo documents")
struct AppStorePromoKitTests {
    @Test func displayPresetsAreUniqueAndValid() {
        let presets = AppStorePromoDisplaySpec.presets
        #expect(Set(presets.map(\.displayType)).count == presets.count)
        #expect(presets.allSatisfy { $0.width > 0 && $0.height > 0 })
        #expect(AppStorePromoDisplaySpec.preset(for: "APP_DESKTOP")?.width == 1280)
    }

    @Test func linterRejectsRemoteAndExecutableHTML() {
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width"></head>
        <body style="background: white; overflow: hidden"><script></script><img src="https://example.com/a.png"></body></html>
        """
        let report = AppStorePromoHTMLLinter().lint(html: html)
        #expect(report.errors.map(\.code).contains("script_forbidden"))
        #expect(report.errors.map(\.code).contains("remote_resource"))
    }

    @Test func storeCreatesPersistsAndAtomicallyPatchesPage() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = AppStorePromoDocumentStore(relativeRoot: ".lumi/test-promo")
        _ = try store.createProject(
            projectPath: root.path,
            slug: "launch-art",
            title: "Launch",
            appName: "Lumi",
            deviceFamily: .iphone,
            localeIdentifier: "en-US"
        )
        let page = try store.createPage(
            projectPath: root.path,
            projectSlug: "launch-art",
            pageSlug: "fast-chat",
            title: "Fast Chat"
        )
        #expect(page.html.contains("Fast Chat"))

        let patched = try store.patchHTML(
            operations: [.init(oldText: "<h1>Fast Chat</h1>", newText: "<h1>Ship Faster</h1>")],
            projectPath: root.path,
            projectSlug: "launch-art",
            pageSlug: "fast-chat"
        )
        #expect(patched.html.contains("Ship Faster"))
        #expect(try store.readProject(projectPath: root.path, projectSlug: "launch-art").pages.count == 1)
    }

    @Test func patchBatchRollsBackWhenAnyMatchIsMissing() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = AppStorePromoDocumentStore(relativeRoot: ".lumi/test-promo")
        _ = try store.createProject(projectPath: root.path, slug: "promo", title: "Promo", appName: "Lumi", deviceFamily: .mac, localeIdentifier: "en-US")
        let page = try store.createPage(projectPath: root.path, projectSlug: "promo", pageSlug: "one", title: "Original")
        #expect(throws: AppStorePromoStoreError.self) {
            try store.patchHTML(
                operations: [
                    .init(oldText: "Original", newText: "Changed"),
                    .init(oldText: "Never present", newText: "No"),
                ],
                projectPath: root.path,
                projectSlug: "promo",
                pageSlug: "one"
            )
        }
        #expect(try store.readPage(projectPath: root.path, projectSlug: "promo", pageSlug: "one").html == page.html)
    }

    @Test func pathAccessUsesDirectoryBoundaries() {
        #expect(AppStorePromoDocumentStore.isPathAllowed("/tmp/project/a", allowedDirectories: ["/tmp/project"]))
        #expect(!AppStorePromoDocumentStore.isPathAllowed("/tmp/project-copy", allowedDirectories: ["/tmp/project"]))
    }

    @MainActor
    @Test func exporterProducesExactViewportPixels() async throws {
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width">
        <style>html,body{width:100%;height:100%;margin:0;overflow:hidden;background:#7138f4}</style>
        </head><body></body></html>
        """
        let preset = AppStorePromoDisplayPreset(displayType: "TEST", family: .mac, width: 320, height: 200)
        let data = try await AppStorePromoHTMLExporter.exportPNG(html: html, fileURL: nil, preset: preset)
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == 320)
        #expect(properties[kCGImagePropertyPixelHeight] as? Int == 200)
    }
}
