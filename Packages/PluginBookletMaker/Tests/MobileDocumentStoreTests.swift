import CoreGraphics
import Foundation
import XCTest
@testable import BookletMakerPlugin

@MainActor
final class MobileDocumentStoreTests: XCTestCase {

    func testImportCopiesInspectsAndCommitsWithOriginalName() async throws {
        let sourceURL = try makeSourcePDF(pageCount: 5, name: "我的文档")
        defer { try? FileManager.default.removeItem(at: sourceURL) }
        let store = MobileDocumentStore()
        defer {
            store.clearSession()
            MobileDocumentStore.cleanupStaleSessions()
        }

        let document = try await store.importPDF(from: sourceURL)

        XCTAssertFalse(document.isDemo)
        XCTAssertEqual(document.pageCount, 5)
        XCTAssertTrue(FileManager.default.fileExists(atPath: document.url.path))
        // The committed copy keeps the user's original file name.
        XCTAssertEqual(document.url.lastPathComponent, "我的文档.pdf")
        XCTAssertTrue(document.url.path.hasPrefix(store.inboxDirectory.path))
    }

    func testImportOfCorruptFileFailsAndLeavesNoResidue() async throws {
        let corruptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("corrupt-\(UUID().uuidString).pdf")
        try Data("this is not a pdf".utf8).write(to: corruptURL)
        defer { try? FileManager.default.removeItem(at: corruptURL) }

        let store = MobileDocumentStore()
        defer {
            store.clearSession()
            MobileDocumentStore.cleanupStaleSessions()
        }

        do {
            _ = try await store.importPDF(from: corruptURL)
            XCTFail("Expected corrupt PDF to be rejected")
        } catch {
            XCTAssertTrue(error is MobileDocumentStore.ImportError)
        }

        // No candidate residue remains in the inbox.
        let remaining = try FileManager.default.contentsOfDirectory(atPath: store.inboxDirectory.path)
        XCTAssertTrue(remaining.isEmpty, "Expected empty inbox, found \(remaining)")
    }

    func testImportOfMissingFileFailsAndLeavesNoResidue() async throws {
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).pdf")

        let store = MobileDocumentStore()
        defer {
            store.clearSession()
            MobileDocumentStore.cleanupStaleSessions()
        }

        do {
            _ = try await store.importPDF(from: missingURL)
            XCTFail("Expected missing file to be rejected")
        } catch {
            XCTAssertTrue(error is MobileDocumentStore.ImportError)
        }

        let remaining = try FileManager.default.contentsOfDirectory(atPath: store.inboxDirectory.path)
        XCTAssertTrue(remaining.isEmpty, "Expected empty inbox, found \(remaining)")
    }

    func testClearSessionRemovesCommittedCopyAndOutput() async throws {
        let sourceURL = try makeSourcePDF(pageCount: 3)
        defer { try? FileManager.default.removeItem(at: sourceURL) }
        let store = MobileDocumentStore()
        defer { MobileDocumentStore.cleanupStaleSessions() }

        let document = try await store.importPDF(from: sourceURL)
        try FileManager.default.createDirectory(at: store.outputDirectory, withIntermediateDirectories: true)
        let resultFile = store.outputDirectory.appendingPathComponent("result.pdf")
        try Data("result".utf8).write(to: resultFile)

        store.clearSession()

        XCTAssertFalse(FileManager.default.fileExists(atPath: document.url.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: resultFile.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.outputDirectory.path))
    }

    func testCleanupStaleSessionsKeepsActiveSession() async throws {
        let sourceURL = try makeSourcePDF(pageCount: 2)
        defer { try? FileManager.default.removeItem(at: sourceURL) }
        let store = MobileDocumentStore()

        // Simulate an active session that has been used, plus a stale
        // sibling session directory that must be removed.
        let base = store.sessionDirectory.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: store.sessionDirectory, withIntermediateDirectories: true)
        let stale = base.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: stale, withIntermediateDirectories: true)

        MobileDocumentStore.cleanupStaleSessions(keeping: store)

        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.sessionDirectory.path))

        store.clearSession()
        try? FileManager.default.removeItem(at: store.sessionDirectory)
        MobileDocumentStore.cleanupStaleSessions()
    }

    // MARK: - Helpers

    private func makeSourcePDF(pageCount: Int, name: String = "source") throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name).pdf")
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let consumer = CGDataConsumer(data: data),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw NSError(domain: "MobileDocumentStoreTests", code: 1)
        }
        for _ in 0..<pageCount {
            context.beginPDFPage(nil)
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(mediaBox)
            context.endPDFPage()
        }
        context.closePDF()
        try (data as Data).write(to: url, options: .atomic)
        return url
    }
}
