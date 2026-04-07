import AppKit
import MagicKit
import SwiftUI

/// 在 GitOK 中打开项目插件
///
/// 在 Agent 模式的 header 右侧添加一个按钮，点击后在 GitOK 中打开当前项目。
/// 
/// ## 实现方式
///
/// 使用 NSWorkspace 通过 GitOK 的 Bundle ID (com.yueyi.GitOK) 打开应用。
/// 
/// ## 注意事项
///
/// GitOK 必须已安装在系统中。如果未安装，按钮点击后会有错误日志输出。
actor AgentOpenInGitOKPlugin: SuperPlugin {
    nonisolated static let emoji = "✅"
    nonisolated static let verbose = true

    static let id = "AgentOpenInGitOK"
    static let displayName = String(localized: "Open in GitOK", table: "AgentOpenInGitOK")
    static let description = String(localized: "Open current project in GitOK", table: "AgentOpenInGitOK")
    static let iconName = "point.topleft.down.curvedto.point.filled.bottomright.up"
    static var order: Int { 98 }

    /// 用户可在设置中启用/禁用此插件
    static var isConfigurable: Bool { true }

    static let enable: Bool = true

    static let shared = AgentOpenInGitOKPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    @MainActor
    func addRightHeaderTrailingItems() -> [AnyView] {
        [AnyView(OpenInGitOKButton())]
    }
}