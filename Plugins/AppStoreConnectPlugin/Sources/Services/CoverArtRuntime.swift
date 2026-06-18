import Foundation

@MainActor
enum CoverArtRuntime {
    static var currentProjectPathProvider: (@MainActor @Sendable () -> String)?

    static var currentProjectPath: String {
        currentProjectPathProvider?() ?? ""
    }
}
