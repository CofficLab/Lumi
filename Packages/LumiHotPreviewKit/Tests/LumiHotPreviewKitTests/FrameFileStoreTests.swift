import Foundation
import Testing
@testable import LumiHotPreviewKit

@Suite("FrameFileStore")
struct FrameFileStoreTests {
    @Test("writes decoded PNG data to a file")
    func writesDecodedPNGDataToFile() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LumiHotPreviewPackage.FrameFileStore(directory: directory)
        let expected = Data([0x89, 0x50, 0x4E, 0x47])

        let fileURL = try store.writePNG(
            base64EncodedPNG: expected.base64EncodedString(),
            previewID: "My Preview"
        )

        #expect(FileManager.default.fileExists(atPath: fileURL.path))
        #expect(try Data(contentsOf: fileURL) == expected)
        #expect(fileURL.lastPathComponent.hasPrefix("My-Preview-"))
    }

    @Test("rejects invalid base64 payloads")
    func rejectsInvalidBase64Payloads() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LumiHotPreviewPackage.FrameFileStore(directory: directory)

        #expect(throws: Error.self) {
            _ = try store.writePNG(base64EncodedPNG: "%%%")
        }
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiHotPreviewKitTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
