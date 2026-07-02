import Foundation
import SwiftUI

@MainActor
public enum LumiCore {
    private static var configuration: LumiCoreConfiguration?

    // MARK: - 配置

    public static func configure(dataRootDirectory: URL) {
        let directory = dataRootDirectory.standardizedFileURL
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        configuration = LumiCoreConfiguration(dataRootDirectory: directory)
    }

    public static var dataRootDirectory: URL {
        guard let configuration else {
            fatalError("LumiCore.configure(dataRootDirectory:) must be called before using LumiCore storage APIs.")
        }

        return configuration.dataRootDirectory
    }

    public static var coreDataDirectory: URL {
        directory(named: "Core", under: dataRootDirectory)
    }

    public static func pluginDataDirectory(for pluginName: String) -> URL {
        directory(named: sanitizeDirectoryName(pluginName, fallback: "Plugin"), under: dataRootDirectory)
    }

    private static func directory(named name: String, under root: URL) -> URL {
        let directory = root.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return directory
    }

    private static func sanitizeDirectoryName(_ name: String, fallback: String) -> String {
        let sanitized = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")

        return sanitized.isEmpty ? fallback : sanitized
    }
}
