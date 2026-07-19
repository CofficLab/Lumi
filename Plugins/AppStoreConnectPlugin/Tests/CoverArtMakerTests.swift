import Foundation
import LumiKernel
import Testing
@testable import AppStoreConnectPlugin

@Suite("Cover art maker", .serialized)
struct CoverArtMakerTests {
    @Test("ScreenshotDisplaySpec returns sizes for known types")
    func displaySpecProvidesKnownSizes() {
        #expect(ScreenshotDisplaySpec.size(for: "APP_IPHONE_65") == .init(width: 1284, height: 2778))
        #expect(ScreenshotDisplaySpec.size(for: "APP_DESKTOP") == .init(width: 1280, height: 800))
    }

    @Test("ScreenshotDisplaySpec groups preview sizes by device family")
    func previewSizesByFamily() {
        let iphoneSizes = ScreenshotDisplaySpec.previewSizes(for: .iphone)
        #expect(iphoneSizes.count == 3)
        #expect(iphoneSizes.contains { $0.displayType == "APP_IPHONE_67" && $0.width == 1290 })

        let macSizes = ScreenshotDisplaySpec.previewSizes(for: .mac)
        #expect(macSizes.count == 1)
        #expect(macSizes.first?.displayType == "APP_DESKTOP")
    }

    @Test("CoverArtTemplateFactory uses responsive layout")
    func templateIsResponsive() {
        let html = CoverArtTemplateFactory.html(title: "Lumi", deviceFamily: .iphone)
        #expect(html.contains("width: 100%"))
        #expect(html.contains("height: 100%"))
        #expect(html.contains("data-device-family=\"iphone\""))
        #expect(html.contains("28vmin"))
    }

    @Test("CoverArtDocumentStore round-trips create read update delete")
    func documentStoreRoundTrip() throws {
        let root = makeTemporaryProjectDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = CoverArtDocumentStore()
        let created = try store.create(
            projectPath: root.path,
            appID: "app-1",
            slug: "launch-cover",
            title: "Launch",
            deviceFamily: .iphone
        )
        #expect(created.manifest.title == "Launch")
        #expect(created.manifest.deviceFamily == .iphone)
        #expect(created.html.contains("Launch"))

        let listed = try store.list(projectPath: root.path, appID: "app-1")
        #expect(listed.count == 1)
        #expect(listed.first?.id == "launch-cover")

        let updatedHTML = "<!DOCTYPE html><html><body>Updated</body></html>"
        let updated = try store.writeHTML(
            updatedHTML,
            projectPath: root.path,
            appID: "app-1",
            slug: "launch-cover"
        )
        #expect(updated.html == updatedHTML)

        let readBack = try store.read(projectPath: root.path, appID: "app-1", slug: "launch-cover")
        #expect(readBack.html == updatedHTML)

        try store.delete(projectPath: root.path, appID: "app-1", slug: "launch-cover")
        #expect(try store.list(projectPath: root.path, appID: "app-1").isEmpty)
    }

    @Test("CoverArt slug validator rejects invalid values")
    func slugValidation() {
        #expect(CoverArtSlugValidator.normalize("launch-cover") == "launch-cover")
        #expect(CoverArtSlugValidator.normalize("../escape") == nil)
        #expect(CoverArtSlugValidator.normalize("Bad Slug") == nil)
    }

    @Test("Cover art agent tools create read and update")
    func coverArtToolsWorkflow() async throws {
        let root = makeTemporaryProjectDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let context = LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "tool-1",
            toolName: "app-store-connect.create-cover-art",
            currentProjectPath: root.path,
            allowedDirectories: [root.path]
        )

        let createResult = try await CreateAppStoreConnectCoverArtTool().execute(
            arguments: [
                "appID": .string("app-1"),
                "slug": .string("hero"),
                "title": .string("Hero"),
                "deviceFamily": .string("mac")
            ],
            context: context
        )
        #expect(createResult.contains("Cover art created"))
        #expect(createResult.contains("slug=hero"))
        #expect(createResult.contains("deviceFamily=mac"))

        let readResult = try await ReadAppStoreConnectCoverArtTool().execute(
            arguments: [
                "appID": .string("app-1"),
                "slug": .string("hero")
            ],
            context: context
        )
        #expect(readResult.contains("index.html"))
        #expect(readResult.contains("deviceFamily=mac"))

        let updateResult = try await UpdateAppStoreConnectCoverArtTool().execute(
            arguments: [
                "appID": .string("app-1"),
                "slug": .string("hero"),
                "html": .string("<!DOCTYPE html><html><body><h1>Updated</h1></body></html>")
            ],
            context: context
        )
        #expect(updateResult.contains("Cover art updated"))

        let listResult = try await ListAppStoreConnectCoverArtTool().execute(
            arguments: ["appID": .string("app-1")],
            context: context
        )
        #expect(listResult.contains("slug=hero"))
    }

    @Test("LocalStore persists selected cover art slug")
    func localStorePersistsSelectedSlug() {
        let directory = makeTemporaryPluginDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AppStoreConnectPluginLocalStore(pluginDirectory: directory)

        store.setSelectedCoverArtSlug("hero", appID: "app-1")
        #expect(store.selectedCoverArtSlug(appID: "app-1") == "hero")
    }

    private func makeTemporaryProjectDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-cover-art-project-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func makeTemporaryPluginDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-cover-art-store-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
