import Foundation

enum RClickPluginRuntimeBridge {
    nonisolated(unsafe) static var dataRootDirectory: URL?
    static var fallbackRootDirectory: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory }
}
