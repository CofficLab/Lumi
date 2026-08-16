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

    @Test func storeCreatesPersistsAndAtomicallyPatchesTaskImage() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = AppStorePromoDocumentStore()
        _ = try store.createTask(
            storagePath: root.path,
            slug: "launch-art",
            title: "Launch",
            appName: "Lumi",
            deviceFamily: .iphone,
            localeIdentifier: "en-US"
        )
        let image = try store.createImage(
            storagePath: root.path,
            taskSlug: "launch-art",
            imageSlug: "fast-chat",
            title: "Fast Chat"
        )
        #expect(image.html.contains("Fast Chat"))

        let patched = try store.patchHTML(
            operations: [.init(oldText: "<h1>Fast Chat</h1>", newText: "<h1>Ship Faster</h1>")],
            storagePath: root.path,
            taskSlug: "launch-art",
            imageSlug: "fast-chat"
        )
        #expect(patched.html.contains("Ship Faster"))
        #expect(try store.readTask(storagePath: root.path, taskSlug: "launch-art").images.count == 1)
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("tasks/launch-art/images/fast-chat/index.html").path))
    }

    @Test func patchBatchRollsBackWhenAnyMatchIsMissing() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = AppStorePromoDocumentStore()
        _ = try store.createTask(storagePath: root.path, slug: "promo", title: "Promo", appName: "Lumi", deviceFamily: .mac, localeIdentifier: "en-US")
        let image = try store.createImage(storagePath: root.path, taskSlug: "promo", imageSlug: "one", title: "Original")
        #expect(throws: AppStorePromoStoreError.self) {
            try store.patchHTML(
                operations: [
                    .init(oldText: "Original", newText: "Changed"),
                    .init(oldText: "Never present", newText: "No"),
                ],
                storagePath: root.path,
                taskSlug: "promo",
                imageSlug: "one"
            )
        }
        #expect(try store.readImage(storagePath: root.path, taskSlug: "promo", imageSlug: "one").html == image.html)
    }

    @Test func imageLanguageVersionsAreIndependentAndLegacySafe() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = AppStorePromoDocumentStore()
        _ = try store.createTask(
            storagePath: root.path,
            slug: "localized",
            title: "Localized",
            appName: "Lumi",
            deviceFamily: .mac,
            localeIdentifier: "en-US"
        )
        let primary = try store.createImage(
            storagePath: root.path,
            taskSlug: "localized",
            imageSlug: "hero",
            title: "Hello"
        )
        #expect(primary.image.localeIdentifiers == ["en-US"])

        let chinese = try store.addLocalization(
            "zh-hans",
            copying: "en-US",
            storagePath: root.path,
            taskSlug: "localized",
            imageSlug: "hero"
        )
        #expect(chinese.localeIdentifier == "zh-Hans")
        #expect(chinese.image.localeIdentifiers == ["en-US", "zh-Hans"])
        #expect(chinese.html == primary.html)

        let localizedHTML = primary.html.replacingOccurrences(of: "Hello", with: "你好")
        _ = try store.replaceHTML(
            localizedHTML,
            storagePath: root.path,
            taskSlug: "localized",
            imageSlug: "hero",
            localeIdentifier: "zh-Hans"
        )
        let english = try store.readImage(
            storagePath: root.path,
            taskSlug: "localized",
            imageSlug: "hero",
            localeIdentifier: "en-US"
        )
        let readChinese = try store.readImage(
            storagePath: root.path,
            taskSlug: "localized",
            imageSlug: "hero",
            localeIdentifier: "zh-Hans"
        )
        #expect(english.html.contains("Hello"))
        #expect(readChinese.html.contains("你好"))
        #expect(english.htmlURL.lastPathComponent == "index.html")
        #expect(readChinese.htmlURL.lastPathComponent == "zh-Hans.html")
    }

    @Test func legacyImageWithoutLocalesUsesTaskLocale() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let imageDirectory = root.appendingPathComponent("tasks/legacy/images/hero", isDirectory: true)
        try FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let json = """
        {
          "schemaVersion": 1,
          "id": "legacy",
          "title": "Legacy",
          "appName": "Lumi",
          "deviceFamily": "mac",
          "localeIdentifier": "ja",
          "images": [{
            "id": "hero",
            "title": "Hero",
            "order": 0,
            "htmlFileName": "index.html",
            "createdAt": "2026-01-01T00:00:00Z",
            "updatedAt": "2026-01-01T00:00:00Z"
          }],
          "createdAt": "2026-01-01T00:00:00Z",
          "updatedAt": "2026-01-01T00:00:00Z"
        }
        """
        try Data(json.utf8).write(
            to: root.appendingPathComponent("tasks/legacy/manifest.json"),
            options: .atomic
        )
        try "<!doctype html><html><body>従来版</body></html>".write(
            to: imageDirectory.appendingPathComponent("index.html"),
            atomically: true,
            encoding: .utf8
        )

        let store = AppStorePromoDocumentStore()
        let task = try store.readTask(storagePath: root.path, taskSlug: "legacy")
        let image = try store.readImage(storagePath: root.path, taskSlug: "legacy", imageSlug: "hero")
        #expect(task.images[0].localeIdentifiers == ["ja"])
        #expect(image.localeIdentifier == "ja")
        #expect(image.html.contains("従来版"))
    }

    @Test func storeDeletesManagedImagesAndTasks() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = AppStorePromoDocumentStore()
        _ = try store.createTask(storagePath: root.path, slug: "campaign", title: "Campaign", appName: "Lumi", deviceFamily: .mac, localeIdentifier: "en-US")
        _ = try store.createImage(storagePath: root.path, taskSlug: "campaign", imageSlug: "one", title: "One")
        _ = try store.createImage(storagePath: root.path, taskSlug: "campaign", imageSlug: "two", title: "Two")

        try store.deleteImage(storagePath: root.path, taskSlug: "campaign", imageSlug: "one")
        let task = try store.readTask(storagePath: root.path, taskSlug: "campaign")
        #expect(task.images.map(\.id) == ["two"])
        #expect(task.images.first?.order == 0)

        try store.deleteTask(storagePath: root.path, taskSlug: "campaign")
        #expect(try store.listTasks(storagePath: root.path).isEmpty)
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

    @MainActor
    @Test func exporterLoadsFromDiskFileURL() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let fileURL = dir.appendingPathComponent("index.html")
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width">
        <style>html,body{width:100%;height:100%;margin:0;overflow:hidden;background:#22aa44}</style>
        </head><body></body></html>
        """
        try html.write(to: fileURL, atomically: true, encoding: .utf8)

        let preset = AppStorePromoDisplayPreset(displayType: "TEST", family: .mac, width: 200, height: 100)
        let data = try await AppStorePromoHTMLExporter.exportPNG(html: html, fileURL: fileURL, preset: preset)
        #expect(!data.isEmpty)
    }

    @MainActor
    @Test func exporterFailsWhenFileURLIsUnreachable() async {
        let preset = AppStorePromoDisplayPreset(displayType: "TEST", family: .mac, width: 200, height: 100)
        await #expect(throws: AppStorePromoExportError.loadTimedOut) {
            _ = try await AppStorePromoHTMLExporter.exportPNG(
                html: "",
                fileURL: URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)/index.html"),
                preset: preset,
                loadTimeout: 10
            )
        }
    }

    @MainActor
    @Test func exporterTimesOutWhenImagesNeverLoad() async throws {
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width">
        <style>html,body{width:100%;height:100%;margin:0;overflow:hidden;background:#7138f4}</style>
        </head><body><img src="definitely-missing.png" alt=""></body></html>
        """
        let preset = AppStorePromoDisplayPreset(displayType: "TEST", family: .mac, width: 200, height: 100)
        await #expect(throws: AppStorePromoExportError.resourcesTimedOut) {
            _ = try await AppStorePromoHTMLExporter.exportPNG(
                html: html,
                fileURL: nil,
                preset: preset,
                loadTimeout: 10,
                resourceTimeout: 0.5
            )
        }
    }

    @Test func exportErrorDescriptionsAreNonEmpty() {
        let errors: [AppStorePromoExportError] = [
            .loadTimedOut,
            .resourcesTimedOut,
            .unexpectedImageSize(expectedWidth: 1290, expectedHeight: 2796, actualWidth: 1, actualHeight: 2),
            .pngEncodingFailed,
        ]
        for error in errors {
            #expect(!(error.errorDescription ?? "").isEmpty)
        }
    }
}
