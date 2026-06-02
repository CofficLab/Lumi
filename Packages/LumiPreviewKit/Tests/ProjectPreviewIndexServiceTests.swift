import Foundation
import LumiPreviewKit
import Testing

@Suite("ProjectPreviewIndexService", .serialized)
@MainActor
struct ProjectPreviewIndexServiceTests {
    @Test("1.1 prepareIndex reports previews in package tree")
    func prepareIndexFindsPreviews() async throws {
        let root = try TemporaryProjectFixtures.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let (packageDirectory, sourceFiles) = try TemporaryProjectFixtures.makeSPMPackage(
            in: root,
            previewFiles: [
                ("ContentView", "Main"),
                ("DetailView", "Detail"),
            ]
        )
        let preferred = try #require(sourceFiles.first)

        let service = LumiPreviewFacade.ProjectPreviewIndexService()
        let snapshots = SnapshotCollector()
        service.onSnapshotChanged = { snapshots.append($0) }

        service.prepareIndex(projectRootPath: packageDirectory.path, currentFileURL: preferred)
        let snapshot = try await snapshots.waitForSnapshot(timeoutNanoseconds: 15_000_000_000)

        #expect((snapshot?.previewCount ?? 0) >= 2)
        #expect((snapshot?.scannedFileCount ?? 0) >= 2)
    }

    @Test("1.1b prepareIndex finds previews in UTF-16 Swift files")
    func prepareIndexFindsUTF16Previews() async throws {
        let root = try TemporaryProjectFixtures.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let (packageDirectory, sourceFiles) = try TemporaryProjectFixtures.makeSPMPackage(
            in: root,
            previewFiles: [("ContentView", "Main")]
        )
        let fileURL = try #require(sourceFiles.first)
        let sourceText = try String(contentsOf: fileURL, encoding: .utf8)
        try sourceText.write(to: fileURL, atomically: true, encoding: .utf16)

        let service = LumiPreviewFacade.ProjectPreviewIndexService()
        let snapshots = SnapshotCollector()
        service.onSnapshotChanged = { snapshots.append($0) }

        service.prepareIndex(projectRootPath: packageDirectory.path, currentFileURL: fileURL)
        let snapshot = try await snapshots.waitForSnapshot(timeoutNanoseconds: 3_000_000_000)

        #expect((snapshot?.previewCount ?? 0) >= 1)
        #expect(service.bestPrewarmCandidate(preferredFileURL: fileURL)?.title == "Main")
    }

    @Test("1.2 switching project root clears snapshot before re-indexing")
    func switchingProjectRootResetsSnapshot() async throws {
        let firstRoot = try TemporaryProjectFixtures.makeTemporaryDirectory()
        let secondRoot = try TemporaryProjectFixtures.makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: firstRoot)
            try? FileManager.default.removeItem(at: secondRoot)
        }
        let (firstPackage, firstFiles) = try TemporaryProjectFixtures.makeSPMPackage(in: firstRoot)
        let (secondPackage, secondFiles) = try TemporaryProjectFixtures.makeSPMPackage(
            in: secondRoot,
            previewFiles: [("OnlyView", "Only")]
        )

        let service = LumiPreviewFacade.ProjectPreviewIndexService()
        let snapshots = SnapshotCollector()
        service.onSnapshotChanged = { snapshots.append($0) }

        service.prepareIndex(projectRootPath: firstPackage.path, currentFileURL: firstFiles.first)
        _ = try await snapshots.waitForSnapshot(timeoutNanoseconds: 3_000_000_000)

        snapshots.clear()
        service.prepareIndex(projectRootPath: secondPackage.path, currentFileURL: secondFiles.first)
        let cleared = snapshots.snapshots.contains(where: { $0 == nil })
        let finalSnapshot = try await snapshots.waitForSnapshot(timeoutNanoseconds: 3_000_000_000)

        #expect(cleared || snapshots.snapshots.count >= 2)
        #expect((finalSnapshot?.previewCount ?? 0) >= 1)
    }

    @Test("1.3 prepareIndex with nil paths resets service")
    func prepareIndexWithNilPathsResets() async throws {
        let root = try TemporaryProjectFixtures.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let (packageDirectory, sourceFiles) = try TemporaryProjectFixtures.makeSPMPackage(in: root)
        let fileURL = try #require(sourceFiles.first)

        let service = LumiPreviewFacade.ProjectPreviewIndexService()
        let snapshots = SnapshotCollector()
        service.onSnapshotChanged = { snapshots.append($0) }

        service.prepareIndex(projectRootPath: packageDirectory.path, currentFileURL: fileURL)
        _ = try await snapshots.waitForSnapshot(timeoutNanoseconds: 3_000_000_000)

        snapshots.clear()
        service.prepareIndex(projectRootPath: nil, currentFileURL: nil)
        let resetSnapshot = try await snapshots.waitForSnapshot(timeoutNanoseconds: 1_000_000_000)

        #expect(resetSnapshot == nil)
        #expect(service.cachedPreviews(for: fileURL) == nil)
    }

    @Test("1.4 refreshCurrentFile updates cached previews immediately")
    func refreshCurrentFileUpdatesCache() async throws {
        let root = try TemporaryProjectFixtures.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fileURL = root.appendingPathComponent("Sources/App/Live.swift")
        try TemporaryProjectFixtures.writeSwiftFileWithPreview(at: fileURL, previewLabel: "Live")

        let service = LumiPreviewFacade.ProjectPreviewIndexService()
        service.prepareIndex(projectRootPath: root.path, currentFileURL: fileURL)

        let scanner = LumiPreviewFacade.PreviewScanner()
        let sourceText = try String(contentsOf: fileURL, encoding: .utf8)
        let previews = scanner.scan(fileURL: fileURL, sourceText: sourceText)
        service.refreshCurrentFile(fileURL: fileURL, sourceText: sourceText, previews: previews)

        let cached = service.cachedPreviews(for: fileURL)
        #expect(cached?.count == previews.count)
        #expect(cached?.first?.title == "Live")
    }

    @Test("1.5 cached previews invalidate when file metadata changes")
    func cachedPreviewsInvalidateOnMetadataChange() async throws {
        let root = try TemporaryProjectFixtures.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fileURL = root.appendingPathComponent("Mutable.swift")
        try TemporaryProjectFixtures.writeSwiftFileWithPreview(at: fileURL, previewLabel: "Mutable")

        let service = LumiPreviewFacade.ProjectPreviewIndexService()
        service.prepareIndex(projectRootPath: root.path, currentFileURL: fileURL)

        let scanner = LumiPreviewFacade.PreviewScanner()
        let sourceText = try String(contentsOf: fileURL, encoding: .utf8)
        let previews = scanner.scan(fileURL: fileURL, sourceText: sourceText)
        service.refreshCurrentFile(fileURL: fileURL, sourceText: sourceText, previews: previews)
        #expect(service.cachedPreviews(for: fileURL) != nil)

        let updatedText = sourceText + "\n// changed"
        try updatedText.write(to: fileURL, atomically: true, encoding: .utf8)
        let updatedPreviews = scanner.scan(fileURL: fileURL, sourceText: updatedText)
        service.refreshCurrentFile(fileURL: fileURL, sourceText: updatedText, previews: updatedPreviews)
        #expect(service.cachedPreviews(for: fileURL)?.count == updatedPreviews.count)
    }

    @Test("1.6 ignores non-swift and out-of-root refresh")
    func ignoresInvalidRefreshTargets() async throws {
        let root = try TemporaryProjectFixtures.makeTemporaryDirectory()
        let siblingRoot = URL(fileURLWithPath: root.path + "2", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: siblingRoot)
        }
        let fileURL = root.appendingPathComponent("Sources/App/Valid.swift")
        try TemporaryProjectFixtures.writeSwiftFileWithPreview(at: fileURL, previewLabel: "Valid")

        let service = LumiPreviewFacade.ProjectPreviewIndexService()
        service.prepareIndex(projectRootPath: root.path, currentFileURL: fileURL)

        let outsideURL = FileManager.default.temporaryDirectory.appendingPathComponent("Outside.swift")
        try TemporaryProjectFixtures.writeSwiftFileWithPreview(at: outsideURL, previewLabel: "Outside")
        defer { try? FileManager.default.removeItem(at: outsideURL) }
        let siblingURL = siblingRoot.appendingPathComponent("Sources/App/Sibling.swift")
        try TemporaryProjectFixtures.writeSwiftFileWithPreview(at: siblingURL, previewLabel: "Sibling")

        service.refreshCurrentFile(
            fileURL: outsideURL,
            sourceText: try String(contentsOf: outsideURL, encoding: .utf8),
            previews: []
        )
        service.refreshCurrentFile(
            fileURL: root.appendingPathComponent("README.md"),
            sourceText: "# Preview",
            previews: []
        )
        service.refreshCurrentFile(
            fileURL: siblingURL,
            sourceText: try String(contentsOf: siblingURL, encoding: .utf8),
            previews: LumiPreviewFacade.PreviewScanner().scan(
                fileURL: siblingURL,
                sourceText: try String(contentsOf: siblingURL, encoding: .utf8)
            )
        )

        #expect(service.cachedPreviews(for: outsideURL) == nil)
        #expect(service.cachedPreviews(for: siblingURL) == nil)
    }

    @Test("1.7 bestPrewarmCandidate prefers current file")
    func bestPrewarmCandidatePrefersCurrentFile() async throws {
        let root = try TemporaryProjectFixtures.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let (packageDirectory, sourceFiles) = try TemporaryProjectFixtures.makeSPMPackage(
            in: root,
            previewFiles: [
                ("ContentView", "Main"),
                ("DetailView", "Detail"),
            ]
        )
        let preferred = try #require(sourceFiles.first)

        let service = LumiPreviewFacade.ProjectPreviewIndexService()
        service.prepareIndex(projectRootPath: packageDirectory.path, currentFileURL: preferred)

        for fileURL in sourceFiles {
            let sourceText = try String(contentsOf: fileURL, encoding: .utf8)
            let previews = LumiPreviewFacade.PreviewScanner().scan(fileURL: fileURL, sourceText: sourceText)
            service.refreshCurrentFile(fileURL: fileURL, sourceText: sourceText, previews: previews)
        }

        let candidate = service.bestPrewarmCandidate(preferredFileURL: preferred)
        #expect(candidate?.sourceFileURL == preferred)
        #expect(candidate?.title == "Main")
    }

    @Test("1.8 prewarmCandidates deduplicates and respects limit")
    func prewarmCandidatesRespectLimit() async throws {
        let root = try TemporaryProjectFixtures.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let (packageDirectory, sourceFiles) = try TemporaryProjectFixtures.makeSPMPackage(
            in: root,
            previewFiles: [
                ("ContentView", "Main"),
                ("DetailView", "Detail"),
            ]
        )

        let service = LumiPreviewFacade.ProjectPreviewIndexService()
        service.prepareIndex(projectRootPath: packageDirectory.path, currentFileURL: sourceFiles.first)

        for fileURL in sourceFiles {
            let sourceText = try String(contentsOf: fileURL, encoding: .utf8)
            let previews = LumiPreviewFacade.PreviewScanner().scan(fileURL: fileURL, sourceText: sourceText)
            service.refreshCurrentFile(fileURL: fileURL, sourceText: sourceText, previews: previews)
        }

        let preferred = try #require(sourceFiles.first)
        let candidates = service.prewarmCandidates(preferredFileURL: preferred, limit: 1)
        #expect(candidates.count == 1)

        let again = service.prewarmCandidates(preferredFileURL: preferred, limit: 3)
        let uniqueIDs = Set(again.map(\.id))
        #expect(uniqueIDs.count == again.count)
        #expect(again.count <= 3)
    }

    @Test("1.9 skips oversized swift files during indexing")
    func skipsOversizedSwiftFiles() async throws {
        let root = try TemporaryProjectFixtures.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let fileURL = root.appendingPathComponent("Huge.swift")
        var hugeBody = "import SwiftUI\n"
        hugeBody.append(String(repeating: "// padding\n", count: 200_000))
        hugeBody.append(
            """
            #Preview("Huge") {
                Text("Huge")
            }
            """
        )
        try hugeBody.write(to: fileURL, atomically: true, encoding: .utf8)

        let service = LumiPreviewFacade.ProjectPreviewIndexService()
        let snapshots = SnapshotCollector()
        service.onSnapshotChanged = { snapshots.append($0) }

        service.prepareIndex(projectRootPath: root.path, currentFileURL: fileURL)
        let snapshot = try await snapshots.waitForSnapshot(timeoutNanoseconds: 3_000_000_000)

        #expect((snapshot?.previewCount ?? 0) == 0)
    }

    @Test("1.10 incremental index updates when a new swift file is added")
    func incrementalIndexUpdatesOnNewFile() async throws {
        let root = try TemporaryProjectFixtures.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let (packageDirectory, sourceFiles) = try TemporaryProjectFixtures.makeSPMPackage(
            in: root,
            previewFiles: [("ContentView", "Main")]
        )

        let service = LumiPreviewFacade.ProjectPreviewIndexService()
        let snapshots = SnapshotCollector()
        service.onSnapshotChanged = { snapshots.append($0) }

        service.prepareIndex(projectRootPath: packageDirectory.path, currentFileURL: sourceFiles.first)
        _ = try await snapshots.waitForSnapshot(timeoutNanoseconds: 3_000_000_000)
        let initialCount = snapshots.snapshots.compactMap { $0 }.last?.previewCount

        let newFile = packageDirectory
            .appendingPathComponent("Sources/App/NewView.swift")
        try TemporaryProjectFixtures.writeSwiftFileWithPreview(at: newFile, previewLabel: "New")

        try await Task.sleep(nanoseconds: 1_200_000_000)
        let finalCount = snapshots.snapshots.compactMap { $0 }.last?.previewCount

        #expect((finalCount ?? 0) >= (initialCount ?? 0) + 1)
    }
}

@MainActor
private final class SnapshotCollector {
    private(set) var snapshots: [LumiPreviewFacade.ProjectPreviewIndexService.Snapshot?] = []

    func append(_ snapshot: LumiPreviewFacade.ProjectPreviewIndexService.Snapshot?) {
        snapshots.append(snapshot)
    }

    func clear() {
        snapshots.removeAll()
    }

    func waitForSnapshot(timeoutNanoseconds: UInt64) async throws -> LumiPreviewFacade.ProjectPreviewIndexService.Snapshot? {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if let latest = snapshots.compactMap({ $0 }).last {
                return latest
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        return snapshots.compactMap { $0 }.last
    }
}
