import Foundation

/// 应用程序打开类型（与 MagicKit `OpenAppType` 行为一致）
public enum OpenAppType: String, Sendable, CaseIterable {
    case auto
    case xcode
    case vscode
    case cursor
    case trae
    case antigravity
    case chrome
    case safari
    case arc
    case firefox
    case edge
    case terminal
    case preview
    case textEdit
    case finder
    case browser
    case githubDesktop
    case kiro

    /// 获取应用程序的 Bundle ID；`auto` / `browser` / `finder` 无固定 bundleId
    public var bundleId: String? {
        switch self {
        case .auto, .browser, .finder:
            return nil
        case .xcode:
            return "com.apple.dt.Xcode"
        case .vscode:
            return "com.microsoft.VSCode"
        case .cursor:
            return "com.todesktop.230313mzl4w4u92"
        case .trae:
            return "com.trae.app"
        case .antigravity:
            return "com.google.antigravity"
        case .chrome:
            return "com.google.Chrome"
        case .safari:
            return "com.apple.Safari"
        case .arc:
            return "company.thebrowser.Browser"
        case .firefox:
            return "org.mozilla.firefox"
        case .edge:
            return "com.microsoft.edgemac"
        case .terminal:
            return "com.apple.Terminal"
        case .preview:
            return "com.apple.Preview"
        case .textEdit:
            return "com.apple.TextEdit"
        case .githubDesktop:
            return "com.github.GitHubClient"
        case .kiro:
            return "dev.kiro.desktop"
        }
    }

    /// SF Symbol 名称
    public var icon: String {
        switch self {
        case .auto:
            return "gearshape"
        case .browser:
            return "safari"
        case .finder:
            return "arrow.forward.circle"
        case .xcode:
            return "hammer.fill"
        case .vscode, .cursor, .trae, .antigravity, .kiro:
            return "chevron.left.forwardslash.chevron.right"
        case .chrome, .safari, .arc, .firefox, .edge:
            return "safari"
        case .terminal:
            return "terminal"
        case .preview:
            return "eye"
        case .textEdit:
            return "doc.text"
        case .githubDesktop:
            return "arrow.triangle.branch"
        }
    }

    /// 显示名称
    public var displayName: String {
        switch self {
        case .auto:
            return "智能打开"
        case .browser:
            return "在浏览器中打开"
        case .finder:
            return "在访达中显示"
        case .xcode:
            return "在 Xcode 中打开"
        case .vscode:
            return "在 VS Code 中打开"
        case .cursor:
            return "在 Cursor 中打开"
        case .trae:
            return "在 Trae 中打开"
        case .antigravity:
            return "在 Antigravity 中打开"
        case .chrome:
            return "在 Chrome 中打开"
        case .safari:
            return "在 Safari 中打开"
        case .arc:
            return "在 Arc 中打开"
        case .firefox:
            return "在 Firefox 中打开"
        case .edge:
            return "在 Edge 中打开"
        case .terminal:
            return "在终端中打开"
        case .preview:
            return "在预览中打开"
        case .textEdit:
            return "在文本编辑器中打开"
        case .githubDesktop:
            return "在 GitHub Desktop 中打开"
        case .kiro:
            return "在 Kiro 中打开"
        }
    }

    public func icon(for url: URL) -> String {
        if self == .auto {
            return url.isNetworkURL ? "safari" : "arrow.forward.circle"
        }
        return icon
    }

    public func displayName(for url: URL) -> String {
        if self == .auto {
            return url.isNetworkURL ? "在浏览器中打开" : "在访达中显示"
        }
        return displayName
    }

    public var isInstalled: Bool {
        if self == .auto || self == .browser {
            return true
        }
        guard let bundleId else { return false }
        return WorkspaceEnvironment.workspace.urlForApplication(bundleIdentifier: bundleId) != nil
    }
}
