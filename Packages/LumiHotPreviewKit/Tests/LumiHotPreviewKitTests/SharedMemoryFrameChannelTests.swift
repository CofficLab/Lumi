import AppKit
import Foundation
import Testing
@testable import LumiHotPreviewKit

@Suite("SharedMemoryFrameChannel")
struct SharedMemoryFrameChannelTests {
    @Test("writes and maps frame bytes through shared memory")
    func writesAndMapsFrameBytes() throws {
        let channel = LumiHotPreviewPackage.SharedMemoryFrameChannel(
            namePrefix: "/lumi-hot-preview-test-"
        )
        #expect(channel.preferredBackend == .automatic)
        #expect(channel.backendKind == .mach)
        #expect(channel.usedFallbackBackend == false)
        #expect(channel.backendResolution == .init(
            requested: .automatic,
            effective: .mach,
            usedFallbackBackend: false,
            reason: nil
        ))
        let tag = "frame-\(UUID().uuidString)"
        let bytes = Data([0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88])

        let descriptor = try channel.writeFrame(
            tag: tag,
            bytes: bytes,
            width: 2,
            height: 1,
            bytesPerRow: 8
        )
        defer { try? channel.removeFrame(tag: tag) }

        #expect(descriptor.tag == tag)
        #expect(descriptor.byteCount == bytes.count)

        let mapped = try channel.mapFrame(
            tag: tag,
            width: 2,
            height: 1,
            bytesPerRow: 8
        )
        let roundTrip = mapped.withUnsafeBytes { Data($0) }
        #expect(roundTrip == bytes)
    }

    @Test("mach backend preference uses shared memory backend")
    func machPreferenceUsesMachBackend() {
        let channel = LumiHotPreviewPackage.SharedMemoryFrameChannel(
            namePrefix: "/lumi-hot-preview-test-",
            preferredBackend: .mach
        )

        #expect(channel.preferredBackend == .mach)
        #expect(channel.backendKind == .mach)
        #expect(channel.usedFallbackBackend == false)
        #expect(channel.backendResolution == .init(
            requested: .mach,
            effective: .mach,
            usedFallbackBackend: false,
            reason: nil
        ))
    }

    @Test("reports mach backend availability state")
    func reportsMachBackendAvailabilityState() {
        #expect(
            LumiHotPreviewPackage.SharedMemoryFrameChannel.machBackendAvailability ==
            .available
        )
    }

    @Test("environment override selects backend preference")
    func environmentOverrideSelectsBackendPreference() {
        let channel = LumiHotPreviewPackage.SharedMemoryFrameChannel(
            namePrefix: "/lumi-hot-preview-test-",
            preferredBackend: .automatic,
            environment: [
                LumiHotPreviewPackage.SharedMemoryFrameChannel.backendOverrideEnvironmentKey: "mappedfile"
            ]
        )

        #expect(channel.preferredBackend == .mappedFile)
        #expect(channel.backendKind == .mappedFile)
        #expect(channel.usedFallbackBackend == false)
        #expect(channel.backendResolution == .init(
            requested: .mappedFile,
            effective: .mappedFile,
            usedFallbackBackend: false,
            reason: nil
        ))
    }

    @Test("creates an image from mapped BGRA frame bytes")
    func createsImageFromMappedFrame() throws {
        let channel = LumiHotPreviewPackage.SharedMemoryFrameChannel(
            namePrefix: "/lumi-hot-preview-test-"
        )
        let tag = "image-\(UUID().uuidString)"
        let bytes = Data([0x00, 0x00, 0xFF, 0xFF])

        _ = try channel.writeFrame(
            tag: tag,
            bytes: bytes,
            width: 1,
            height: 1,
            bytesPerRow: 4
        )
        defer { try? channel.removeFrame(tag: tag) }

        let mapped = try channel.mapFrame(
            tag: tag,
            width: 1,
            height: 1,
            bytesPerRow: 4
        )
        let image = mapped.makeImage()

        #expect(image != nil)
        #expect(image?.size.width == 1)
        #expect(image?.size.height == 1)
    }

    @Test("rejects invalid frame dimensions")
    func rejectsInvalidDimensions() {
        let channel = LumiHotPreviewPackage.SharedMemoryFrameChannel(
            namePrefix: "/lumi-hot-preview-test-"
        )

        #expect(throws: LumiHotPreviewPackage.SharedMemoryFrameChannel.ChannelError.invalidDimensions) {
            try channel.writeFrame(
                tag: "invalid",
                bytes: Data([0x00]),
                width: 0,
                height: 1,
                bytesPerRow: 4
            )
        }
    }

    @Test("removes expired shared frame files")
    func removesExpiredSharedFrames() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let oldURL = directory.appendingPathComponent("old-frame")
        let newURL = directory.appendingPathComponent("new-frame")
        FileManager.default.createFile(atPath: oldURL.path, contents: Data([0x00]))
        FileManager.default.createFile(atPath: newURL.path, contents: Data([0x00]))

        let now = Date()
        try FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-7_200)],
            ofItemAtPath: oldURL.path
        )
        try FileManager.default.setAttributes(
            [.modificationDate: now],
            ofItemAtPath: newURL.path
        )

        let removed = LumiHotPreviewPackage.SharedMemoryFrameChannel.removeExpiredFrames(
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
            .appendingPathComponent("LumiHotPreviewSharedMemoryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
