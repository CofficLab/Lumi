import AgentToolKit
import Foundation
import LumiCoreKit
import SuperLogKit
import os

/// GitHub CLI detection plugin.
///
/// The package owns the tool and service implementation; the app keeps only
/// a registration adapter while runtime plugin discovery is still module-based.
public actor GitHubCLIDetectPlugin: SuperPlugin, SuperLog {
    public nonisolated static let policy: PluginPolicy = .disabled
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.github-cli-detect")
    public nonisolated static let emoji = "🐚"
    public nonisolated static let verbose: Bool = false

    public static let id: String = "GitHubCLIDetect"
    public static let displayName: String = PluginGitHubCLIDetectLocalization.string("GitHub CLI Detect")
    public static let description: String = PluginGitHubCLIDetectLocalization.string("检测系统是否安装了 GitHub CLI (gh) 命令行工具。")

    public static func description(for language: LanguagePreference) -> String {
        PluginGitHubCLIDetectLocalization.string("检测系统是否安装了 GitHub CLI (gh) 命令行工具。", for: language)
    }
    public static let iconName: String = "terminal"
    public static var category: PluginCategory { .general }
    public static var order: Int { 16 }

    public static let shared = GitHubCLIDetectPlugin()

    private init() {}

    @MainActor
    public func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [GitHubCLICheckTool()]
    }
}

enum PluginGitHubCLIDetectLocalization {
    static let table = "Localizable"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: .module, comment: "")
    }

    static func string(_ key: String, for language: LanguagePreference) -> String {
        PackageStringLocalization.string(key, table: table, bundle: bundle, language: language)
    }
}
