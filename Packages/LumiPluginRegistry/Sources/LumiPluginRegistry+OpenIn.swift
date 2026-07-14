// MARK: - Open In Plugins Imports
import OpenInAntigravityPlugin
import OpenInCursorPlugin
import OpenInFinderPlugin
import OpenInGitHubDesktopPlugin
import OpenInGitOKPlugin
import OpenInXcodePlugin
import OpenRemotePlugin

// MARK: - Open In Plugins Extension

extension LumiPluginRegistry {
    /// Open In 插件数组，包含所有"在其他应用中打开"相关的插件。
    ///
    /// 包含：在 Xcode、Cursor、Antigravity、Finder、GitHub Desktop、GitOK、Remote 中打开
    public static let openInPlugins: [any LumiPlugin.Type] = [
        // MARK: - IDE / Editor

        AgentOpenInXcodePlugin.self,
        AgentOpenInCursorPlugin.self,
        AgentOpenInAntigravityPlugin.self,

        // MARK: - File Manager

        AgentOpenInFinderPlugin.self,

        // MARK: - Git Tools

        AgentOpenInGitHubDesktopPlugin.self,
        AgentOpenInGitOKPlugin.self,

        // MARK: - Remote

        AgentOpenRemotePlugin.self,
    ]
}
