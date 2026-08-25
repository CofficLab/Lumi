import AppKit
import Foundation
import KitAgentTool
import ProviderProject

/// 在外部应用中打开路径的工具。
///
/// 复刻自旧版 `OpenIn*Plugin` 系列（Finder / Xcode / Cursor / VSCode /
/// Antigravity / GitHub Desktop / GitOK / 远程），新版统一为一个泛型工具：
/// - 接收可选 `path` 参数（默认当前项目路径）；
/// - 用 `NSWorkspace` 在指定应用中打开。
public struct OpenInTool: SuperAgentTool, @unchecked Sendable {
    /// 应用配置。
    public struct AppConfig: Sendable {
        public let toolName: String
        public let displayName: String
        public let systemImage: String
        /// 用于 `NSWorkspace.urlForApplication(withBundleIdentifier:)` 的 bundle id；
        /// nil 时回退 `fallbackPath`。
        public let bundleIdentifier: String?
        /// bundle id 解析失败时的回退应用路径。
        public let fallbackPath: String
        /// 打开方式：`openURLs`（把 URL 交给应用）或 `activateApp`（仅激活应用）。
        public let opensURLs: Bool

        public init(
            toolName: String,
            displayName: String,
            systemImage: String,
            bundleIdentifier: String?,
            fallbackPath: String,
            opensURLs: Bool = true
        ) {
            self.toolName = toolName
            self.displayName = displayName
            self.systemImage = systemImage
            self.bundleIdentifier = bundleIdentifier
            self.fallbackPath = fallbackPath
            self.opensURLs = opensURLs
        }
    }

    public let config: AppConfig
    /// 当前项目路径提供者（用于默认 path）。
    private let project: (any ProjectProviding)?

    public init(config: AppConfig, project: (any ProjectProviding)?) {
        self.config = config
        self.project = project
    }

    public var name: String { config.toolName }

    public func description(for language: LanguagePreference) -> String {
        "Open the current project (or the given path) in \(config.displayName)."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": "Optional absolute path to open. Defaults to the current project path.",
                ],
            ],
        ]
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        if let path = arguments["path"]?.value as? String, !path.isEmpty {
            return "在 \(config.displayName) 中打开 \(path)"
        }
        return "在 \(config.displayName) 中打开当前项目"
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let path = await resolvedPath(arguments), !path.isEmpty else {
            return "## Open in \(config.displayName) ❌\n\n**Status**: No project is open and no path was provided."
        }
        let url = URL(fileURLWithPath: path)

        if config.opensURLs {
            let workspace = NSWorkspace.shared
            let appURL = config.bundleIdentifier
                .flatMap { workspace.urlForApplication(withBundleIdentifier: $0) }
                ?? URL(fileURLWithPath: config.fallbackPath)
            let configuration = NSWorkspace.OpenConfiguration()
            try await workspace.open([url], withApplicationAt: appURL, configuration: configuration)
        } else {
            try await NSWorkspace.shared.openApplication(
                at: URL(fileURLWithPath: config.fallbackPath),
                configuration: NSWorkspace.OpenConfiguration()
            )
        }

        return """
        ## Open in \(config.displayName) ✅

        **Path**: `\(path)`
        """
    }

    /// 解析目标路径：显式参数 > 当前项目路径。ProjectProviding 是 MainActor
    /// 隔离，经 MainActor.run 跳回主线程读取。
    private func resolvedPath(_ arguments: [String: ToolArgument]) async -> String? {
        if let path = arguments["path"]?.value as? String, !path.isEmpty {
            return path
        }
        return await MainActor.run { project?.currentProject?.path }
    }
}

// MARK: - 预置配置

public enum OpenInApps {
    public static let finder = OpenInTool.AppConfig(
        toolName: "open_in_finder",
        displayName: "Finder",
        systemImage: "folder",
        bundleIdentifier: "com.apple.finder",
        fallbackPath: "/System/Library/CoreServices/Finder.app"
    )
    public static let xcode = OpenInTool.AppConfig(
        toolName: "open_in_xcode",
        displayName: "Xcode",
        systemImage: "hammer",
        bundleIdentifier: "com.apple.dt.Xcode",
        fallbackPath: "/Applications/Xcode.app"
    )
    public static let cursor = OpenInTool.AppConfig(
        toolName: "open_in_cursor",
        displayName: "Cursor",
        systemImage: "cursorarrow",
        bundleIdentifier: "com.todesktop.230313mzl4w4u92",
        fallbackPath: "/Applications/Cursor.app"
    )
    public static let vscode = OpenInTool.AppConfig(
        toolName: "open_in_vscode",
        displayName: "VS Code",
        systemImage: "chevron.left.slash.chevron.right",
        bundleIdentifier: "com.microsoft.VSCode",
        fallbackPath: "/Applications/Visual Studio Code.app"
    )
    public static let antigravity = OpenInTool.AppConfig(
        toolName: "open_in_antigravity",
        displayName: "Antigravity",
        systemImage: "paperplane",
        bundleIdentifier: "com.antigravity.Antigravity",
        fallbackPath: "/Applications/Antigravity.app"
    )
    public static let gitHubDesktop = OpenInTool.AppConfig(
        toolName: "open_in_github_desktop",
        displayName: "GitHub Desktop",
        systemImage: "chevron.left",
        bundleIdentifier: "com.github.GitHubClient",
        fallbackPath: "/Applications/GitHub Desktop.app"
    )
    public static let gitOK = OpenInTool.AppConfig(
        toolName: "open_in_gitok",
        displayName: "GitOK",
        systemImage: "arrow.triangle.branch",
        bundleIdentifier: "com.bytedance.GitOK",
        fallbackPath: "/Applications/GitOK.app"
    )
}
