import Foundation
import LumiKernel

@MainActor
enum AppStorePromoRuntime {
    static var currentProjectPathProvider: (@MainActor @Sendable () -> String)?
    static var allowedDirectoriesProvider: (@MainActor @Sendable () -> [String])?

    static var currentProjectPath: String {
        currentProjectPathProvider?() ?? ""
    }

    static var allowedDirectories: [String] {
        allowedDirectoriesProvider?() ?? []
    }

    static func configure(kernel: LumiKernel) {
        currentProjectPathProvider = { [weak kernel] in kernel?.currentProjectPath ?? "" }
        allowedDirectoriesProvider = { [weak kernel] in kernel?.allowedDirectories ?? [] }
    }
}
