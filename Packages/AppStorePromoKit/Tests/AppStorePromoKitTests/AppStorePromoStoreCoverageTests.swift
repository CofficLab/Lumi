import Foundation
import Testing
@testable import AppStorePromoKit

@Suite("Document store validation and recovery")
struct AppStorePromoStoreCoverageTests {
    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test func invalidLocaleDoesNotLeaveTaskDirectoryBehind() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = AppStorePromoDocumentStore()

        #expect(throws: AppStorePromoStoreError.self) {
            try store.createTask(
                storagePath: root.path,
                slug: "recoverable",
                title: "Recoverable",
                appName: "Lumi",
                deviceFamily: .iphone,
                localeIdentifier: "not a locale!!"
            )
        }
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("tasks/recoverable").path))

        // Retry with a valid locale must succeed instead of hitting alreadyExists.
        let task = try store.createTask(
            storagePath: root.path,
            slug: "recoverable",
            title: "Recoverable",
            appName: "Lumi",
            deviceFamily: .iphone,
            localeIdentifier: "en-US"
        )
        #expect(task.localeIdentifier == "en-US")
    }

    @Test func invalidHTMLDoesNotLeaveImageDirectoryBehind() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = AppStorePromoDocumentStore()
        _ = try store.createTask(
            storagePath: root.path,
            slug: "task",
            title: "Task",
            appName: "Lumi",
            deviceFamily: .mac,
            localeIdentifier: "en-US"
        )

        let broken = "<p>no doctype, no viewport, no html element</p>"
        #expect(throws: AppStorePromoStoreError.self) {
            try store.createImage(
                storagePath: root.path,
                taskSlug: "task",
                imageSlug: "broken",
                title: "Broken",
                html: broken
            )
        }
        let imageDirectory = root.appendingPathComponent("tasks/task/images/broken")
        #expect(!FileManager.default.fileExists(atPath: imageDirectory.path))

        let retry = try store.createImage(
            storagePath: root.path,
            taskSlug: "task",
            imageSlug: "broken",
            title: "Fixed"
        )
        #expect(retry.image.title == "Fixed")
    }

    @Test func slugValidationRejectsBadInputButTrimsGoodInput() throws {
        #expect(throws: AppStorePromoStoreError.self) {
            try AppStorePromoDocumentStore.validatedSlug("Invalid Slug!")
        }
        #expect(try AppStorePromoDocumentStore.validatedSlug("  Launch-Art  ") == "launch-art")
    }

    @Test func emptyStoragePathThrowsInvalidStoragePath() {
        #expect(throws: AppStorePromoStoreError.invalidStoragePath) {
            _ = try AppStorePromoDocumentStore().rootURL(storagePath: "")
        }
    }

    @Test func duplicateTaskAndImageReportAlreadyExists() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = AppStorePromoDocumentStore()
        _ = try store.createTask(
            storagePath: root.path, slug: "dup", title: "Dup",
            appName: "Lumi", deviceFamily: .iphone, localeIdentifier: "en-US"
        )
        #expect(throws: AppStorePromoStoreError.self) {
            _ = try store.createTask(
                storagePath: root.path, slug: "dup", title: "Dup",
                appName: "Lumi", deviceFamily: .iphone, localeIdentifier: "en-US"
            )
        }

        _ = try store.createImage(storagePath: root.path, taskSlug: "dup", imageSlug: "img", title: "Img")
        #expect(throws: AppStorePromoStoreError.self) {
            _ = try store.createImage(storagePath: root.path, taskSlug: "dup", imageSlug: "img", title: "Img")
        }
    }

    @Test func missingTaskImageAndLocaleReportNotFound() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = AppStorePromoDocumentStore()
        _ = try store.createTask(
            storagePath: root.path, slug: "t", title: "T",
            appName: "Lumi", deviceFamily: .mac, localeIdentifier: "en-US"
        )
        _ = try store.createImage(storagePath: root.path, taskSlug: "t", imageSlug: "i", title: "I")

        #expect(throws: AppStorePromoStoreError.self) {
            _ = try store.readTask(storagePath: root.path, taskSlug: "missing")
        }
        #expect(throws: AppStorePromoStoreError.self) {
            _ = try store.readImage(storagePath: root.path, taskSlug: "t", imageSlug: "ghost")
        }
        #expect(throws: AppStorePromoStoreError.self) {
            _ = try store.readImage(
                storagePath: root.path, taskSlug: "t", imageSlug: "i", localeIdentifier: "fr-FR"
            )
        }
        #expect(throws: AppStorePromoStoreError.self) {
            _ = try store.readImage(
                storagePath: root.path, taskSlug: "t", imageSlug: "i", localeIdentifier: "12"
            )
        }
        #expect(throws: AppStorePromoStoreError.self) {
            _ = try store.deleteImage(storagePath: root.path, taskSlug: "t", imageSlug: "ghost")
        }
        #expect(throws: AppStorePromoStoreError.self) {
            try store.deleteTask(storagePath: root.path, taskSlug: "missing")
        }
    }

    @Test func duplicateLocalizationAndAmbiguousPatchAreRejected() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = AppStorePromoDocumentStore()
        _ = try store.createTask(
            storagePath: root.path, slug: "t", title: "T",
            appName: "Lumi", deviceFamily: .mac, localeIdentifier: "en-US"
        )
        _ = try store.createImage(storagePath: root.path, taskSlug: "t", imageSlug: "i", title: "Dup Word")

        #expect(throws: AppStorePromoStoreError.localeAlreadyExists("en-US")) {
            _ = try store.addLocalization(
                "EN-us", storagePath: root.path, taskSlug: "t", imageSlug: "i"
            )
        }
        #expect(throws: AppStorePromoStoreError.invalidLocale("nope")) {
            _ = try store.addLocalization(
                "nope", storagePath: root.path, taskSlug: "t", imageSlug: "i"
            )
        }
        #expect(throws: AppStorePromoStoreError.patchTextNotUnique("Dup")) {
            _ = try store.patchHTML(
                operations: [.init(oldText: "Dup", newText: "X")],
                storagePath: root.path, taskSlug: "t", imageSlug: "i"
            )
        }
        #expect(throws: AppStorePromoStoreError.patchTextMissing("absent")) {
            _ = try store.patchHTML(
                operations: [.init(oldText: "absent", newText: "X")],
                storagePath: root.path, taskSlug: "t", imageSlug: "i"
            )
        }
    }

    @Test func replaceHTMLRejectsInvalidMarkupWithoutTouchingStoredFile() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = AppStorePromoDocumentStore()
        _ = try store.createTask(
            storagePath: root.path, slug: "t", title: "T",
            appName: "Lumi", deviceFamily: .mac, localeIdentifier: "en-US"
        )
        let original = try store.createImage(storagePath: root.path, taskSlug: "t", imageSlug: "i", title: "I")

        #expect(throws: AppStorePromoStoreError.self) {
            _ = try store.replaceHTML("<script>a</script>", storagePath: root.path, taskSlug: "t", imageSlug: "i")
        }
        #expect(try store.readImage(storagePath: root.path, taskSlug: "t", imageSlug: "i").html == original.html)
    }

    @Test func lintImageReportsStoredMarkupState() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = AppStorePromoDocumentStore()
        _ = try store.createTask(
            storagePath: root.path, slug: "t", title: "T",
            appName: "Lumi", deviceFamily: .mac, localeIdentifier: "en-US"
        )
        _ = try store.createImage(storagePath: root.path, taskSlug: "t", imageSlug: "i", title: "I")
        let report = try store.lintImage(storagePath: root.path, taskSlug: "t", imageSlug: "i")
        #expect(report.isValid)
    }

    @Test func listTasksSortsByMostRecentlyUpdated() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = AppStorePromoDocumentStore()
        _ = try store.createTask(
            storagePath: root.path, slug: "older", title: "Older",
            appName: "Lumi", deviceFamily: .mac, localeIdentifier: "en-US"
        )
        let second = try store.createTask(
            storagePath: root.path, slug: "newer", title: "Newer",
            appName: "Lumi", deviceFamily: .mac, localeIdentifier: "en-US"
        )
        // Ensure the second task's updatedAt is strictly later, then verify ordering.
        var newer = second
        newer.updatedAt = second.updatedAt.addingTimeInterval(1)
        let newerManifest = root.appendingPathComponent("tasks/newer/manifest.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(newer).write(to: newerManifest, options: .atomic)

        let listed = try store.listTasks(storagePath: root.path)
        #expect(listed.map(\.id) == ["newer", "older"])
    }

    @Test func assetsDirectoryIsCreatedOnDemand() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = AppStorePromoDocumentStore()
        _ = try store.createTask(
            storagePath: root.path, slug: "t", title: "T",
            appName: "Lumi", deviceFamily: .mac, localeIdentifier: "en-US"
        )
        _ = try store.createImage(storagePath: root.path, taskSlug: "t", imageSlug: "i", title: "I")
        let assets = try store.assetsDirectoryURL(storagePath: root.path, taskSlug: "t", imageSlug: "i")
        #expect(FileManager.default.fileExists(atPath: assets.path))
        #expect(assets.lastPathComponent == "assets")
    }

    @Test func pathResolutionAndBoundaries() {
        #expect(AppStorePromoDocumentStore.isPathAllowed("/anything", allowedDirectories: []))
        #expect(AppStorePromoDocumentStore.resolvePath("~/tmp")
            == URL(fileURLWithPath: FileManager.default.homeDirectoryForCurrentUser.path + "/tmp")
                .resolvingSymlinksInPath().standardizedFileURL.path)
        #expect(AppStorePromoDocumentStore.isPathAllowed("/tmp/project", allowedDirectories: ["/tmp/project/"]))
    }

    @Test func storeErrorDescriptionsAreNonEmpty() {
        let issues = [AppStorePromoLintIssue(severity: .error, code: "code", message: "message")]
        let errors: [AppStorePromoStoreError] = [
            .invalidStoragePath,
            .invalidSlug("bad slug"),
            .alreadyExists("/tmp/a"),
            .notFound("/tmp/b"),
            .imageNotFound("img"),
            .invalidLocale("xx"),
            .localeNotFound("fr-FR"),
            .localeAlreadyExists("fr-FR"),
            .invalidHTML(issues),
            .patchTextMissing("old"),
            .patchTextNotUnique("old"),
            .pathNotAllowed("/etc"),
        ]
        for error in errors {
            #expect(!(error.errorDescription ?? "").isEmpty)
        }
    }

    @Test func readImageThrowsWhenHTMLFileIsMissingOnDisk() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = AppStorePromoDocumentStore()
        _ = try store.createTask(
            storagePath: root.path, slug: "t", title: "T",
            appName: "Lumi", deviceFamily: .mac, localeIdentifier: "en-US"
        )
        _ = try store.createImage(storagePath: root.path, taskSlug: "t", imageSlug: "i", title: "I")
        let htmlURL = root.appendingPathComponent("tasks/t/images/i/index.html")
        try FileManager.default.removeItem(at: htmlURL)

        #expect(throws: AppStorePromoStoreError.imageNotFound("i")) {
            _ = try store.readImage(storagePath: root.path, taskSlug: "t", imageSlug: "i")
        }
    }
}

@Suite("Template factory")
struct AppStorePromoTemplateFactoryTests {
    @Test func defaultsAndEscaping() {
        let html = AppStorePromoTemplateFactory.html(title: "", appName: "", family: .ipad)
        #expect(html.contains("A better way to work"))
        #expect(html.contains("Your App"))
        #expect(html.contains("data-device-family=\"ipad\""))

        let hostile = AppStorePromoTemplateFactory.html(
            title: "<script>alert(1)</script> & \"quotes\"",
            appName: "App",
            family: .mac
        )
        #expect(!hostile.contains("<script>alert"))
        #expect(hostile.contains("&lt;script&gt;"))
        #expect(hostile.contains("&amp;"))
        #expect(hostile.contains("&quot;quotes&quot;"))

        let report = AppStorePromoHTMLLinter().lint(html: html)
        #expect(report.isValid)
    }
}
