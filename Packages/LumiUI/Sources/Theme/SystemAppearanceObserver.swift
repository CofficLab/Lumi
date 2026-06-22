import AppKit
import Foundation

/// 监听 macOS 系统明暗切换，驱动 `.system` 主题刷新。
@MainActor
public final class SystemAppearanceObserver {
    public static let shared = SystemAppearanceObserver()

    private var distributedObserver: NSObjectProtocol?
    private var appearanceObservation: NSKeyValueObservation?

    private init() {
        distributedObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { _ in
            LumiUIThemeRegistry.shared.handleSystemAppearanceDidChange()
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didFinishLaunchingNotification,
            object: nil,
            queue: .main
        ) { _ in
            SystemAppearanceObserver.shared.startObservingApplicationAppearanceIfNeeded()
        }
    }

    /// 在宿主窗口就绪后补充 KVO（单元测试环境无 NSApplication 时跳过）。
    func startObservingApplicationAppearanceIfNeeded() {
        guard appearanceObservation == nil else { return }
        appearanceObservation = NSApplication.shared.observe(\.effectiveAppearance, options: [.new]) { _, _ in
            LumiUIThemeRegistry.shared.handleSystemAppearanceDidChange()
        }
    }
}
