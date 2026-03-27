import AppKit
import MagicKit
import SwiftUI

/// 在 GitHub Desktop 中打开项目插件
///
/// 在 Agent 模式的 header 右侧添加一个按钮，点击后在 GitHub Desktop 中打开当前项目。
/// 
/// ## 实现方式
///
/// 使用 MagicKit 提供的 `URL.openInGitHubDesktop()` 方法：
/// - 首选 URL Scheme: `github-desktop://openLocalRepo?path=...`
/// - 回退方案: 通过 Bundle ID `com.github.GitHubClient` 打开应用
///
/// ## 注意事项
///
/// 如果用户未安装 GitHub Desktop，按钮会被禁用或无响应。
actor AgentOpenInGitHubDesktopPlugin: SuperPlugin {
    nonisolated static let emoji = "🐙"
    nonisolated static let verbose = false

    static let id = "AgentOpenInGitHubDesktop"
    static let displayName = String(localized: "Open in GitHub Desktop", table: "AgentOpenInGitHubDesktop")
    static let description = String(localized: "Open current project in GitHub Desktop", table: "AgentOpenInGitHubDesktop")
    static let iconName = "desktopcomputer"
    static var order: Int { 97 }

    /// 用户可在设置中启用/禁用此插件
    static var isConfigurable: Bool { true }

    static let enable: Bool = true

    static let shared = AgentOpenInGitHubDesktopPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    @MainActor
    func addRightHeaderTrailingItems() -> [AnyView] {
        [AnyView(OpenInGitHubDesktopButton())]
    }
}