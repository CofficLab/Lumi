import AppKit
import Foundation
import Testing
@testable import LumiHotPreviewKit

@Suite("ImageFileLoader")
struct ImageFileLoaderTests {
    @Test("loads PNG files and caches them")
    func loadsPNGFilesAndCachesThem() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let imageURL = directory.appendingPathComponent("frame.png")
        try writePNG(at: imageURL, color: .systemRed)

        let loader = LumiHotPreviewPackage.ImageFileLoader(cacheLimit: 4)

        let first = try #require(loader.loadImage(at: imageURL))
        let second = try #require(loader.loadImage(at: imageURL))

        #expect(first === second)
        #expect(loader.cachedImageCount() == 1)
    }

    @Test("returns nil for missing or invalid files")
    func returnsNilForMissingOrInvalidFiles() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let invalidURL = directory.appendingPathComponent("frame.png")
        try Data("not a png".utf8).write(to: invalidURL)

        let loader = LumiHotPreviewPackage.ImageFileLoader()

        #expect(loader.loadImage(at: directory.appendingPathComponent("missing.png")) == nil)
        #expect(loader.loadImage(at: invalidURL) == nil)
    }

    @Test("evicts least recently used images")
    func evictsLeastRecentlyUsedImages() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let firstURL = directory.appendingPathComponent("first.png")
        let secondURL = directory.appendingPathComponent("second.png")
        try writePNG(at: firstURL, color: .systemRed)
        try writePNG(at: secondURL, color: .systemBlue)

        let loader = LumiHotPreviewPackage.ImageFileLoader(cacheLimit: 1)

        let first = try #require(loader.loadImage(at: firstURL))
        _ = try #require(loader.loadImage(at: secondURL))
        let reloadedFirst = try #require(loader.loadImage(at: firstURL))

        #expect(first !== reloadedFirst)
        #expect(loader.cachedImageCount() == 1)
    }

    @Test("loads images from shared memory and caches them")
    func loadsSharedMemoryImagesAndCachesThem() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let channel = LumiHotPreviewPackage.SharedMemoryFrameChannel(
            namePrefix: "lumi-hot-preview-loader-test-",
            directory: directory
        )
        let loader = LumiHotPreviewPackage.ImageFileLoader(
            cacheLimit: 4,
            sharedMemoryFrameChannel: channel
        )
        let tag = "frame-\(UUID().uuidString)"

        _ = try channel.writeFrame(
            tag: tag,
            bytes: Data([0x00, 0x00, 0xFF, 0xFF]),
            width: 1,
            height: 1,
            bytesPerRow: 4
        )
        defer { try? channel.removeFrame(tag: tag) }

        let first = try #require(loader.loadSharedMemoryImage(
            tag: tag,
            width: 1,
            height: 1,
            bytesPerRow: 4
        ))
        let second = try #require(loader.loadSharedMemoryImage(
            tag: tag,
            width: 1,
            height: 1,
            bytesPerRow: 4
        ))

        #expect(first === second)
        #expect(loader.cachedImageCount() == 1)
        let remainingFiles = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        #expect(remainingFiles.isEmpty)
    }

    @Test("removes expired frame files")
    func removesExpiredFrameFiles() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let oldURL = directory.appendingPathComponent("old.png")
        let newURL = directory.appendingPathComponent("new.png")
        try writePNG(at: oldURL, color: .systemRed)
        try writePNG(at: newURL, color: .systemBlue)

        let now = Date()
        try FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-7_200)],
            ofItemAtPath: oldURL.path
        )
        try FileManager.default.setAttributes(
            [.modificationDate: now],
            ofItemAtPath: newURL.path
        )

        let removed = LumiHotPreviewPackage.ImageFileLoader.removeExpiredFrames(
            in: directory,
            olderThan: 3_600,
            now: now
        )

        #expect(removed == 1)
        #expect(!FileManager.default.fileExists(atPath: oldURL.path))
        #expect(FileManager.default.fileExists(atPath: newURL.path))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiHotPreviewKitTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writePNG(at url: URL, color: NSColor) throws {
        let image = NSImage(size: NSSize(width: 2, height: 2))
        image.lockFocus()
        color.setFill()
        NSRect(x: 0, y: 0, width: 2, height: 2).fill()
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try png.write(to: url)
    }
}
