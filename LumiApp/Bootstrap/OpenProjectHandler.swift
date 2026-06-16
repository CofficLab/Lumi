import Foundation
import LumiCoreKit

@MainActor
final class OpenProjectHandler {
    static let shared = OpenProjectHandler()

    private init() {}

    func requestOpen(path: String) {
        let normalized = OpenProjectPathResolver.normalizePath(path)
        guard !normalized.isEmpty else { return }

        guard FileManager.default.fileExists(atPath: normalized) else {
            return
        }

        RootContainer.shared.projectPathStore.setCurrentProjectPath(normalized)
        NotificationCenter.default.post(
            name: .lumiOpenExternalProject,
            object: nil,
            userInfo: [LumiOpenProjectUserInfoKey.path: normalized]
        )
    }
}
