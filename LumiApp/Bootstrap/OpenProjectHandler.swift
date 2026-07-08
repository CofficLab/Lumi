import Foundation
import LumiCoreKit
import SuperLogKit
import os

@MainActor
final class OpenProjectHandler: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "bootstrap.open-project")
    nonisolated static let emoji = "📂"
    nonisolated static let verbose = false

    static let shared = OpenProjectHandler()

    private init() {}

    func requestOpen(path: String) {
        let normalized = Self.normalizePath(path)
        guard !normalized.isEmpty else {
            Self.logger.warning("\(Self.t)路径为空或无效: \(path)")
            return
        }

        guard FileManager.default.fileExists(atPath: normalized) else {
            Self.logger.warning("\(Self.t)文件不存在: \(normalized)")
            return
        }

        guard Self.verbose else {
            LumiCore.projectState?.setCurrentProjectPath(normalized)
            return
        }

        Self.logger.info("\(Self.t)外部打开项目: \(normalized)")
        LumiCore.projectState?.setCurrentProjectPath(normalized)
    }

    private static func normalizePath(_ path: String) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
            .resolvingSymlinksInPath()
            .standardizedFileURL
        return url.path
    }
}
