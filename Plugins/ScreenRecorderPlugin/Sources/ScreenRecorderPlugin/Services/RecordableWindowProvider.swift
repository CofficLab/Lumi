import AppKit
import CoreGraphics
import Foundation

/// 一个可录制的屏幕窗口（自包含，对齐 `ComputerUseWindow` 但独立于 ComputerUsePlugin）。
public struct RecordableWindow: Identifiable, Equatable, Sendable {
    public let id: CGWindowID
    public let processIdentifier: pid_t
    public let bundleIdentifier: String
    public let applicationName: String
    public let windowTitle: String
    public let frame: CGRect

    public init(
        id: CGWindowID,
        processIdentifier: pid_t,
        bundleIdentifier: String,
        applicationName: String,
        windowTitle: String,
        frame: CGRect
    ) {
        self.id = id
        self.processIdentifier = processIdentifier
        self.bundleIdentifier = bundleIdentifier
        self.applicationName = applicationName
        self.windowTitle = windowTitle
        self.frame = frame
    }
}

/// 枚举/选择可录制窗口，以及启动并聚焦目标 app。
///
/// 实现对照 `ComputerUseWindowProvider`，自包含不依赖 ComputerUsePlugin。
public enum RecordableWindowProvider {

    /// Lumi 自身的 bundleId，用于拒绝录制自身。
    public static var lumiBundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
    }

    /// 当前屏幕上所有常规 app 的可见窗口。
    @MainActor
    public static func availableWindows() -> [RecordableWindow] {
        guard let rawWindows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[CFString: Any]] else { return [] }

        let ownPID = ProcessInfo.processInfo.processIdentifier
        return rawWindows.compactMap { raw -> RecordableWindow? in
            guard let number = raw[kCGWindowNumber] as? NSNumber,
                  let pidNumber = raw[kCGWindowOwnerPID] as? NSNumber,
                  let layer = raw[kCGWindowLayer] as? NSNumber,
                  layer.intValue == 0,
                  let boundsValue = raw[kCGWindowBounds]
            else { return nil }
            guard let frame = CGRect(dictionaryRepresentation: boundsValue as! CFDictionary),
                  frame.width >= 80,
                  frame.height >= 60
            else { return nil }

            let pid = pid_t(pidNumber.int32Value)
            guard pid != ownPID,
                  let application = NSRunningApplication(processIdentifier: pid),
                  application.activationPolicy == .regular,
                  let bundleIdentifier = application.bundleIdentifier,
                  !bundleIdentifier.isEmpty
            else { return nil }

            let applicationName = application.localizedName
                ?? (raw[kCGWindowOwnerName] as? String)
                ?? bundleIdentifier
            let title = (raw[kCGWindowName] as? String) ?? ""
            return RecordableWindow(
                id: CGWindowID(number.uint32Value),
                processIdentifier: pid,
                bundleIdentifier: bundleIdentifier,
                applicationName: applicationName,
                windowTitle: title,
                frame: frame
            )
        }
    }

    /// 按应用名/bundleId 与窗口标题子串匹配选择一个窗口。
    @MainActor
    public static func select(
        from windows: [RecordableWindow],
        application: String?,
        windowTitle: String?,
        frontmostBundleIdentifier: String? = nil
    ) -> RecordableWindow? {
        let appQuery = application?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let titleQuery = windowTitle?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matches = windows.filter { window in
            let matchesApplication = appQuery.map { query in
                window.bundleIdentifier.lowercased() == query
                    || window.applicationName.lowercased().contains(query)
            } ?? true
            let matchesTitle = titleQuery.map { query in
                window.windowTitle.lowercased().contains(query)
            } ?? true
            return matchesApplication && matchesTitle
        }
        if appQuery == nil, titleQuery == nil, let frontmostBundleIdentifier,
           let frontmost = matches.first(where: { $0.bundleIdentifier == frontmostBundleIdentifier }) {
            return frontmost
        }
        return matches.first
    }

    /// 启动（若未运行）并尝试等待其窗口出现，最多等待 `timeout` 秒。
    ///
    /// - Returns: 启动后首个匹配的窗口；若 app 已有窗口则立即返回该窗口。
    @MainActor
    public static func launchIfNeeded(
        application: String,
        windowTitle: String?,
        timeout: TimeInterval = 6
    ) async throws -> RecordableWindow? {
        // 已有窗口则直接返回。
        if let existing = select(from: availableWindows(), application: application, windowTitle: windowTitle) {
            return existing
        }
        guard let url = applicationURL(for: application) else { return nil }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        _ = try? await NSWorkspace.shared.openApplication(at: url, configuration: config)

        // 轮询等待窗口出现。
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            try? await Task.sleep(for: .milliseconds(300))
            if let window = select(from: availableWindows(), application: application, windowTitle: windowTitle) {
                return window
            }
        }
        return nil
    }

    /// 把目标 app 带到前台。
    @MainActor
    public static func activate(_ window: RecordableWindow) {
        NSRunningApplication(processIdentifier: window.processIdentifier)?.activate()
    }

    /// 按 bundleId 或应用名解析 app 的 URL。
    private static func applicationURL(for query: String) -> URL? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // 1) 视为 bundleId。
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: trimmed) {
            return url
        }
        // 2) 在常用目录里按名称找 <query>.app。
        let candidates = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            "/Applications/Utilities",
            NSHomeDirectory() + "/Applications",
        ]
        let name = trimmed.hasSuffix(".app") ? trimmed : trimmed + ".app"
        for dir in candidates {
            let candidate = URL(fileURLWithPath: dir).appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }
}
