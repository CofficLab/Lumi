import AppKit
import Foundation

/// 快速启动器管理器：负责管理应用启动
@MainActor
class QuickLauncherManager: SuperLog {
    nonisolated static let emoji = "🎯"
    nonisolated static let verbose: Bool = false

    // MARK: - Singleton

    static let shared = QuickLauncherManager()

    // MARK: - 应用分类

    /// 系统应用项目
    struct AppItem: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        let bundleIdentifier: String?
        let url: URL?

        /// 通过 bundleIdentifier 启动
        init(name: String, icon: String, bundleIdentifier: String) {
            self.name = name
            self.icon = icon
            self.bundleIdentifier = bundleIdentifier
            self.url = nil
        }

        /// 通过 URL 启动（系统偏好设置等）
        init(name: String, icon: String, url: URL) {
            self.name = name
            self.icon = icon
            self.bundleIdentifier = nil
            self.url = url
        }
    }

    /// 快捷操作项目
    struct QuickAction: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        let color: String
        let action: () -> Void
    }

    // MARK: - 系统应用列表

    /// 系统工具
    let systemTools: [AppItem] = [
        AppItem(name: "Activity Monitor", icon: "waveform.path.ecg", bundleIdentifier: "com.apple.ActivityMonitor"),
        AppItem(name: "Terminal", icon: "terminal", bundleIdentifier: "com.apple.Terminal"),
        AppItem(name: "Disk Utility", icon: "internaldrive", bundleIdentifier: "com.apple.DiskUtility"),
        AppItem(name: "Console", icon: "text.book.closed", bundleIdentifier: "com.apple.Console"),
        AppItem(name: "Keychain Access", icon: "key", bundleIdentifier: "com.apple.keychainaccess"),
        AppItem(name: "System Information", icon: "info.circle", bundleIdentifier: "com.apple.SystemProfiler"),
    ]

    /// 开发者工具
    let developerTools: [AppItem] = [
        AppItem(name: "Xcode", icon: "hammer", bundleIdentifier: "com.apple.dt.Xcode"),
        AppItem(name: "Instruments", icon: "chart.line.uptrend.xyaxis", bundleIdentifier: "com.apple.dt.Instruments"),
        AppItem(name: "Simulator", icon: "iphone", bundleIdentifier: "com.apple.iphonesimulator"),
        AppItem(name: "Accessibility Inspector", icon: "hand.raised", bundleIdentifier: "com.apple.AccessibilityInspector"),
    ]

    /// 常用应用
    let commonApps: [AppItem] = [
        AppItem(name: "Finder", icon: "folder", bundleIdentifier: "com.apple.finder"),
        AppItem(name: "Safari", icon: "safari", bundleIdentifier: "com.apple.Safari"),
        AppItem(name: "Calculator", icon: "calculator", bundleIdentifier: "com.apple.calculator"),
        AppItem(name: "Preview", icon: "photo", bundleIdentifier: "com.apple.Preview"),
        AppItem(name: "TextEdit", icon: "doc.text", bundleIdentifier: "com.apple.TextEdit"),
        AppItem(name: "Notes", icon: "note.text", bundleIdentifier: "com.apple.Notes"),
        AppItem(name: "Calendar", icon: "calendar", bundleIdentifier: "com.apple.iCal"),
        AppItem(name: "Reminders", icon: "checklist", bundleIdentifier: "com.apple.reminders"),
    ]

    /// 系统设置
    let settingsItems: [AppItem] = [
        AppItem(name: "System Settings", icon: "gear", url: URL(string: "x-apple.systempreferences:")!),
        AppItem(name: "Network", icon: "network", url: URL(string: "x-apple.systempreferences:com.apple.preference.network")!),
        AppItem(name: "Sound", icon: "speaker.wave.2", url: URL(string: "x-apple.systempreferences:com.apple.preference.sound")!),
        AppItem(name: "Displays", icon: "display", url: URL(string: "x-apple.systempreferences:com.apple.preference.displays")!),
        AppItem(name: "Battery", icon: "battery.100", url: URL(string: "x-apple.systempreferences:com.apple.preference.Battery")!),
        AppItem(name: "Keyboard", icon: "keyboard", url: URL(string: "x-apple.systempreferences:com.apple.preference.keyboard")!),
        AppItem(name: "Mouse", icon: "cursorarrow", url: URL(string: "x-apple.systempreferences:com.apple.preference.mouse")!),
        AppItem(name: "Privacy & Security", icon: "lock.shield", url: URL(string: "x-apple.systempreferences:com.apple.preference.security")!),
    ]

    // MARK: - 快捷操作

    /// 快捷操作列表
    lazy var quickActions: [QuickAction] = [
        QuickAction(name: "Show Hidden Files", icon: "eye.slash", color: "0A84FF") { [weak self] in
            self?.toggleHiddenFiles()
        },
        QuickAction(name: "Empty Trash", icon: "trash", color: "FF453A") { [weak self] in
            self?.emptyTrash()
        },
        QuickAction(name: "Force Quit", icon: "xmark.circle", color: "FF9F0A") { [weak self] in
            self?.showForceQuit()
        },
        QuickAction(name: "Screen Saver", icon: "rectangle.on.rectangle", color: "30D158") { [weak self] in
            self?.startScreenSaver()
        },
        QuickAction(name: "Lock Screen", icon: "lock", color: "7C6FFF") { [weak self] in
            self?.lockScreen()
        },
        QuickAction(name: "Sleep", icon: "moon.zzz", color: "64D2FF") { [weak self] in
            self?.sleepComputer()
        },
    ]

    // MARK: - 初始化

    private init() {
        if Self.verbose {
            QuickLauncherPlugin.logger.info("\(self.t)QuickLauncherManager initialized")
        }
    }

    // MARK: - 应用启动方法

    /// 启动应用
    /// - Parameter item: 应用项目
    func launchApp(_ item: AppItem) {
        if let bundleId = item.bundleIdentifier {
            launchAppByBundleIdentifier(bundleId)
        } else if let url = item.url {
            openURL(url)
        }
    }

    /// 通过 Bundle Identifier 启动应用
    private func launchAppByBundleIdentifier(_ bundleIdentifier: String) {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, error in
                if let error = error {
                    QuickLauncherPlugin.logger.error("Failed to launch app: \(error.localizedDescription)")
                }
            }
        } else {
            // 尝试使用 open -b 命令
            let task = Process()
            task.launchPath = "/usr/bin/open"
            task.arguments = ["-b", bundleIdentifier]
            do {
                try task.run()
            } catch {
                QuickLauncherPlugin.logger.error("Failed to launch app via open command: \(error.localizedDescription)")
            }
        }
    }

    /// 打开 URL
    private func openURL(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    // MARK: - 快捷操作实现

    /// 切换显示隐藏文件
    private func toggleHiddenFiles() {
        let task = Process()
        task.launchPath = "/usr/bin/defaults"
        task.arguments = ["write", "com.apple.finder", "AppleShowAllFiles", "-bool", "TRUE"]

        // 获取当前状态
        let readTask = Process()
        let pipe = Pipe()
        readTask.standardOutput = pipe
        readTask.launchPath = "/usr/bin/defaults"
        readTask.arguments = ["read", "com.apple.finder", "AppleShowAllFiles"]

        do {
            try readTask.run()
            readTask.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let currentValue = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)

            let newValue = (currentValue == "1" || currentValue == "TRUE") ? "FALSE" : "TRUE"

            let writeTask = Process()
            writeTask.launchPath = "/usr/bin/defaults"
            writeTask.arguments = ["write", "com.apple.finder", "AppleShowAllFiles", newValue]
            try writeTask.run()
            writeTask.waitUntilExit()

            // 重启 Finder
            let killTask = Process()
            killTask.launchPath = "/usr/bin/killall"
            killTask.arguments = ["Finder"]
            try killTask.run()

            if Self.verbose {
                QuickLauncherPlugin.logger.info("Toggled hidden files: \(newValue)")
            }
        } catch {
            QuickLauncherPlugin.logger.error("Failed to toggle hidden files: \(error.localizedDescription)")
        }
    }

    /// 清空废纸篓
    private func emptyTrash() {
        let script = "tell application \"Finder\" to empty trash"
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let error = error {
                QuickLauncherPlugin.logger.error("Failed to empty trash: \(error)")
            }
        }
    }

    /// 显示强制退出对话框
    private func showForceQuit() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.forcequit")!)
    }

    /// 启动屏幕保护
    private func startScreenSaver() {
        let script = "tell application \"System Events\" to start current screen saver"
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }

    /// 锁定屏幕
    private func lockScreen() {
        let script = """
        tell application "System Events"
            keystroke "q" using {command down, control down}
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }

    /// 休眠电脑
    private func sleepComputer() {
        let script = "tell application \"Finder\" to sleep"
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
}
