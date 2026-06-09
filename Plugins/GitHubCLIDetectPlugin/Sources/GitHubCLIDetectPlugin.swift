import AgentToolKit
import Foundation
import LumiCoreKit
import SuperLogKit
import os

/// GitHub CLI detection plugin.
///
/// The package owns the tool and service implementation; the app keeps only
/// a registration adapter while runtime plugin discovery is still module-based.
public enum GitHubCLIDetectPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .optIn
    public static let category: LumiPluginCategory = .general
    public static let iconName = "terminal"
    public static var verbose: Bool { false }
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.github-cli-detect")

    public static let info = LumiPluginInfo(
        id: "GitHubCLIDetect",
        displayName: PluginGitHubCLIDetectLocalization.string("GitHub CLI Detect"),
        description: PluginGitHubCLIDetectLocalization.string("检测系统是否安装了 GitHub CLI (gh) 命令行工具。"),
        order: 16
    )

    public static var id: String { info.id }
    public static var displayName: String { info.displayName }
    public static var order: Int { info.order }

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        [GitHubCLICheckTool().asLumiAgentTool()]
    }
}

enum PluginGitHubCLIDetectLocalization {
    static let table = "Localizable"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: .module, comment: "")
    }
}
