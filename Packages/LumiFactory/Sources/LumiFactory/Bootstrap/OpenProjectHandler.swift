import Foundation
import LumiKernel
import SuperLogKit
import os

@MainActor
public final class OpenProjectHandler: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "bootstrap.open-project")
    nonisolated public static let emoji = "📂"
    nonisolated static let verbose = false

    public static let shared = OpenProjectHandler()

    /// Injected after `WindowMain` initializes the kernel. Kept optional because
    /// `OpenProjectHandler` is a singleton while `LumiKernel` is created late in
    /// the app launch sequence.
    private weak var kernel: LumiKernel?

    private init() {}

    /// Called by `WindowMain.initializeContainer` after obtaining the `LumiKernel`.
    public func configure(kernel: LumiKernel) {
        self.kernel = kernel
    }

    public func requestOpen(path: String) {
        let normalized = Self.normalizePath(path)
        guard !normalized.isEmpty else {
            Self.logger.warning("\(Self.t)Path is empty or invalid: \(path)")
            return
        }

        guard FileManager.default.fileExists(atPath: normalized) else {
            Self.logger.warning("\(Self.t)File does not exist: \(normalized)")
            return
        }

        guard let projectComponent = kernel?.project else {
            Self.logger.warning("\(Self.t)LumiKernel not ready, cannot switch project: \(normalized)")
            return
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)External open project: \(normalized)")
        }
        Task {
            try? await projectComponent.openProject(at: normalized)
        }
    }

    private static func normalizePath(_ path: String) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
            .resolvingSymlinksInPath()
            .standardizedFileURL
        return url.path
    }
}
