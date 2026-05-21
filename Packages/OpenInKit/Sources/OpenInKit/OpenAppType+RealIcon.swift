#if os(macOS)
import AppKit

public extension OpenAppType {
    /// 已安装应用的真实图标；未安装或不可解析时返回 `nil`。
    func realIcon(useRealIcon: Bool = true) -> NSImage? {
        guard useRealIcon else { return nil }

        let appURL: URL?
        if let bundleId {
            appURL = WorkspaceEnvironment.workspace.urlForApplication(bundleIdentifier: bundleId)
        } else if self == .finder {
            appURL = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
        } else {
            return nil
        }

        guard let appURL else { return nil }
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }
}
#endif
