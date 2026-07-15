import Foundation
import LumiCoreKit
import SuperLogKit
import os

@MainActor
public final class OpenProjectHandler: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "bootstrap.open-project")
    nonisolated public static let emoji = "📂"
    nonisolated static let verbose = false

    public static let shared = OpenProjectHandler()

    /// 由 `WindowMain` 初始化后注入；未注入时 `requestOpen` 静默返回。
    /// 保留可空,是因为 `OpenProjectHandler` 是单例,
    /// 而 `LumiCore` 实例是 App 启动后期才创建。
    private weak var lumiCore: LumiCore?

    private init() {}

    /// 由 `WindowMain.initializeContainer` 在拿到 `RootContainer` 后调用。
    public func configure(lumiCore: LumiCore) {
        self.lumiCore = lumiCore
    }

    public func requestOpen(path: String) {
        let normalized = Self.normalizePath(path)
        guard !normalized.isEmpty else {
            Self.logger.warning("\(Self.t)路径为空或无效: \(path)")
            return
        }

        guard FileManager.default.fileExists(atPath: normalized) else {
            Self.logger.warning("\(Self.t)文件不存在: \(normalized)")
            return
        }

        guard let projectState = lumiCore?.projectState else {
            Self.logger.warning("\(Self.t)LumiCore 未就绪,无法切换项目: \(normalized)")
            return
        }

        if Self.verbose {
            Self.logger.info("\(Self.t)外部打开项目: \(normalized)")
        }
        projectState.setCurrentProjectPath(normalized)
    }

    private static func normalizePath(_ path: String) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
            .resolvingSymlinksInPath()
            .standardizedFileURL
        return url.path
    }
}
