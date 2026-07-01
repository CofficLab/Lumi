import Foundation
import LumiCoreKit
import SuperLogKit
import os

@MainActor
final class OpenProjectHandler: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "bootstrap.open-project")
    nonisolated static let emoji = "📂"
    nonisolated static let verbose = true

    static let shared = OpenProjectHandler()

    private init() {}

    func requestOpen(path: String) {
        let normalized = OpenProjectPathResolver.normalizePath(path)
        guard !normalized.isEmpty else {
            Self.logger.warning("\(Self.t)路径为空或无效: \(path)")
            return
        }

        guard FileManager.default.fileExists(atPath: normalized) else {
            Self.logger.warning("\(Self.t)文件不存在: \(normalized)")
            return
        }

        guard Self.verbose else {
            RootContainer.shared.projectPathStore.setCurrentProjectPath(normalized, reason: "外部打开项目")
            NotificationCenter.default.post(
                name: .lumiOpenExternalProject,
                object: nil,
                userInfo: [LumiOpenProjectUserInfoKey.path: normalized]
            )
            return
        }

        Self.logger.info("\(Self.t)外部打开项目: \(normalized)")
        RootContainer.shared.projectPathStore.setCurrentProjectPath(normalized, reason: "外部打开项目")
        NotificationCenter.default.post(
            name: .lumiOpenExternalProject,
            object: nil,
            userInfo: [LumiOpenProjectUserInfoKey.path: normalized]
        )
    }
}
