import AppKit
import SuperLogKit
import os

/// 启动器应用条目
public struct LauncherAppItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let path: String
    public let bundleIdentifier: String?

    public init(id: String, name: String, path: String, bundleIdentifier: String?) {
        self.id = id
        self.name = name
        self.path = path
        self.bundleIdentifier = bundleIdentifier
    }
}

/// 应用扫描服务：扫描标准应用目录并缓存
@MainActor
public final class AppSearchService: ObservableObject, SuperLog {
    public nonisolated static let emoji = "🚀"
    public nonisolated static let verbose: Bool = false

    public static let shared = AppSearchService()

    // MARK: - State

    /// 已扫描的应用（按名称排序）
    @Published public private(set) var apps: [LauncherAppItem] = []

    /// 是否正在扫描
    @Published public private(set) var isScanning = false

    /// 应用图标缓存（主线程访问）
    public func icon(for item: LauncherAppItem) -> NSImage {
        let key = item.id
        if let cached = iconCache[key] { return cached }
        let image = NSWorkspace.shared.icon(forFile: item.path)
        image.size = NSSize(width: 32, height: 32)
        iconCache[key] = image
        return image
    }

    private var iconCache: [String: NSImage] = [:]
    /// 目录修改时间戳，用于增量刷新判断
    private var lastScanStamps: [String: Date] = [:]

    /// 标准应用目录
    static let searchDirectories: [String] = [
        "/Applications",
        "/System/Applications",
        NSString(string: NSHomeDirectory()).appendingPathComponent("Applications"),
    ]

    // MARK: - Initialization

    private init() {}

    // MARK: - Scanning

    /// 扫描已安装应用（带目录 mtime 缓存判断，未变化时跳过）
    public func scanApplications(force: Bool = false) {
        if isScanning { return }
        isScanning = true
        Task { [weak self] in
            let dirs = Self.searchDirectories
            var stamps: [String: Date] = [:]
            var needsScan = force
            for dir in dirs {
                let url = URL(fileURLWithPath: dir)
                guard let resources = try? url.resourceValues(forKeys: [.contentModificationDateKey]) else { continue }
                stamps[dir] = resources.contentModificationDate
                if resources.contentModificationDate != self?.lastScanStamps[dir] {
                    needsScan = true
                }
            }
            guard needsScan else {
                await MainActor.run { self?.isScanning = false }
                return
            }

            let items = await Task.detached(priority: .userInitiated) {
                Self.scanDirectories(dirs)
            }.value

            await MainActor.run {
                self?.apps = items
                self?.lastScanStamps = stamps
                self?.isScanning = false
                if Self.verbose {
                    QuickLauncherPlugin.logger.info("\(self?.t ?? "")已扫描 \(items.count) 个应用")
                }
            }
        }
    }

    /// 后台扫描目录，返回排序去重后的应用列表
    nonisolated static func scanDirectories(_ directories: [String]) -> [LauncherAppItem] {
        var seen = Set<String>()
        var items: [LauncherAppItem] = []
        let fileManager = FileManager.default

        for dir in directories {
            guard let contents = try? fileManager.contentsOfDirectory(
                at: URL(fileURLWithPath: dir),
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for appURL in contents where appURL.pathExtension == "app" {
                let path = appURL.path
                guard !seen.contains(path) else { continue }
                seen.insert(path)

                let bundle = Bundle(url: appURL)
                let name = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? appURL.deletingPathExtension().lastPathComponent
                let bundleId = bundle?.bundleIdentifier

                items.append(
                    LauncherAppItem(
                        id: bundleId ?? path,
                        name: name,
                        path: path,
                        bundleIdentifier: bundleId
                    )
                )
            }
        }

        return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Testing

    /// 注入测试用应用列表
    public func setAppsForTesting(_ items: [LauncherAppItem]) {
        apps = items
    }

    // MARK: - Search

    /// 按查询词过滤应用（前缀 > 包含 > 模糊，同 QuickFileSearch 打分思路）
    public func search(matching query: String) -> [LauncherAppItem] {
        guard !query.isEmpty else { return [] }
        let lowered = query.lowercased()
        return apps.filter { item in
            let name = item.name.lowercased()
            return name.hasPrefix(lowered) || name.contains(lowered) || Self.fuzzyMatch(lowered, in: name)
        }
    }

    /// 按序子序列模糊匹配
    nonisolated static func fuzzyMatch(_ query: String, in target: String) -> Bool {
        guard !query.isEmpty else { return true }
        var index = target.startIndex
        for char in query {
            // 找到下一个匹配字符
            while index < target.endIndex, target[index] != char {
                index = target.index(after: index)
            }
            guard index < target.endIndex else { return false }
            index = target.index(after: index)
        }
        return true
    }

    // MARK: - Launch

    /// 启动应用（bundleId 优先，失败回退 /usr/bin/open）
    public func launchApp(_ item: LauncherAppItem) {
        let appURL = URL(fileURLWithPath: item.path)
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, error in
            if let error {
                QuickLauncherPlugin.logger.error("启动应用失败 \(item.name, privacy: .public): \(error.localizedDescription)")
            }
        }
    }
}
