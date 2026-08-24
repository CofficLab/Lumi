import Foundation
import Testing
@testable import PluginFileLog

@Test func preparesLogDirectory() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("PluginFileLogTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    try FileLogCoordinator.prepareLogsDirectory(directory)
    #expect(FileManager.default.fileExists(atPath: directory.path))
}
