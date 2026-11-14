import AppKit
import LumiLoggingKit
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

/// 应用检索条目：缓存归一化名称，避免每次按键重复 lowercased
public struct AppSearchEntry: Sendable {
    public let item: LauncherAppItem
    public let normalizedName: String

    public init(item: LauncherAppItem, normalizedName: String) {
        self.item = item
        self.normalizedName = normalizedName
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
    @Published public private(set) var apps: [LauncherAppItem] = [] {
        didSet { rebuildSearchIndex() }
    }

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
    /// 检索索引：应用条目 + 归一化名称，随应用列表变化重建
    private var searchIndex: [AppSearchEntry] = []

    /// 标准应用目录
    ///
    /// 扫描只取各根目录的直接 `.app` 子项、不递归，因此系统自带的
    /// Terminal / Activity Monitor / Console 等位于 Utilities 子目录的应用
    /// 必须把 Utilities 显式列为扫描根，否则永远扫不到（#299）。
    static let searchDirectories: [String] = [
        "/Applications",
        "/Applications/Utilities",
        "/System/Applications",
        "/System/Applications/Utilities",
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
                    QuickLauncherPluginSupport.logger.info("\(self?.t ?? "")已扫描 \(items.count) 个应用")
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
        searchItems(matching: query, limit: Int.max).map(\.item)
    }

    /// 按查询词检索应用，最多返回 limit 条。
    ///
    /// 归一化键已在索引中预先算好并缓存，检索本身不再做字符串分配（#1218）。
    /// 必须扫描全部条目、按「前缀 > 包含 > 模糊」分类并在同类内按名称长度稳定排序后，
    /// 再截断到 limit：若边扫边在达到 limit 时停止，会按字母扫描序提前截断，
    /// 把排在后面但优先级更高的精确/前缀命中整个丢掉（#301）。
    func searchItems(matching query: String, limit: Int) -> [AppSearchEntry] {
        guard !query.isEmpty, limit > 0 else { return [] }
        let lowered = query.lowercased()

        var prefixHits: [AppSearchEntry] = []
        var containsHits: [AppSearchEntry] = []
        var fuzzyHits: [AppSearchEntry] = []

        for entry in searchIndex {
            let normalized = entry.normalizedName
            if normalized.hasPrefix(lowered) {
                prefixHits.append(entry)
            } else if normalized.contains(lowered) {
                containsHits.append(entry)
            } else if Self.fuzzyMatch(lowered, in: normalized) {
                fuzzyHits.append(entry)
            }
        }

        // 前缀命中排前；同类按名称长度排，短名优先，等长时保持注册顺序。
        let ordered = byLengthStable(prefixHits) + byLengthStable(containsHits) + byLengthStable(fuzzyHits)
        return Array(ordered.prefix(limit))
    }

    /// 同类命中按名称长度升序排序；等长时按注册顺序保持稳定。
    ///
    /// Swift `sorted` 不保证稳定，必须用注册下标做次级键，
    /// 否则同优先级等长名会被打乱，且短名包含命中可能越级排到前缀命中之前。
    private func byLengthStable(_ hits: [AppSearchEntry]) -> [AppSearchEntry] {
        hits.enumerated().sorted { lhs, rhs in
            if lhs.element.item.name.count != rhs.element.item.name.count {
                return lhs.element.item.name.count < rhs.element.item.name.count
            }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }

    /// 重建应用检索索引（应用列表变化时调用）。
    private func rebuildSearchIndex() {
        searchIndex = apps.map { item in
            AppSearchEntry(item: item, normalizedName: item.name.lowercased())
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
                QuickLauncherPluginSupport.logger.error("启动应用失败 \(item.name, privacy: .public): \(error.localizedDescription)")
            }
        }
    }
}
