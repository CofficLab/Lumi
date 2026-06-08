import Foundation
import LumiCoreKit
import Testing

@MainActor
@Test func pluginDataDirectoryUsesSanitizedNameUnderConfiguredRoot() {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)

    LumiCore.configure(dataRootDirectory: root)

    let directory = LumiCore.pluginDataDirectory(for: "Projects Plugin!")

    #expect(directory == root.appendingPathComponent("Projects_Plugin", isDirectory: true))
    #expect(FileManager.default.fileExists(atPath: directory.path))

    try? FileManager.default.removeItem(at: root)
}
