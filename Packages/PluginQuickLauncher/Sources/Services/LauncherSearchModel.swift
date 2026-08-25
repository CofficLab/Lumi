import Combine
import Foundation
import KitSuperLog
import os

/// Kernel-agnostic command record used by the launcher search index.
///
/// Both the legacy command registry and `ProviderCommand` map into this small
/// DTO, so the launcher UI does not depend on either kernel architecture.
@MainActor
public struct LauncherCommandItem: Sendable {
    public let id: String
    public let title: String
    public let action: @MainActor @Sendable () -> Void

    public init(id: String, title: String, action: @escaping @MainActor @Sendable () -> Void) {
        self.id = id
        self.title = title
        self.action = action
    }
}

@MainActor
public struct LauncherCommandGroup: Sendable {
    public let id: String
    public let name: String
    public let items: [LauncherCommandItem]

    public init(id: String, name: String, items: [LauncherCommandItem]) {
        self.id = id
        self.name = name
        self.items = items
    }
}

/// 插件与内核之间的回调桥（onReady 时注入，避免直接持有 kernel）
@MainActor
public enum LauncherBridge {
    /// 询问 AI：参数为问题文本，实现需激活主窗口并发送到会话
    public static var askAIHandler: (@MainActor (String) -> Void)?
    /// 提供当前所有命令组（来自内核 CommandProviding）
    public static var commandGroupsProvider: (@MainActor () -> [LauncherCommandGroup])?
    /// 激活 Lumi 主窗口
    public static var activateMainWindowHandler: (@MainActor () -> Void)?
}

/// 启动器搜索结果种类
public enum LauncherResultKind: String, CaseIterable, Sendable {
    case app
    case file
    case command
    case ai

    var localizedTitle: String {
        switch self {
        case .app: return LumiPluginLocalization.string("Applications", bundle: .module)
        case .file: return LumiPluginLocalization.string("Files", bundle: .module)
        case .command: return LumiPluginLocalization.string("Commands", bundle: .module)
        case .ai: return LumiPluginLocalization.string("Ask AI", bundle: .module)
        }
    }

    var systemImage: String {
        switch self {
        case .app: return "app"
        case .file: return "doc"
        case .command: return "command"
        case .ai: return "sparkles"
        }
    }
}

/// 启动器统一搜索结果
public struct LauncherResult: Identifiable, Hashable, Sendable {
    public let id: String
    public let kind: LauncherResultKind
    public let title: String
    public let subtitle: String?
    /// 应用条目（kind == .app 时有效）
    public let app: LauncherAppItem?
    /// 文件条目（kind == .file 时有效）
    public let file: LauncherFileItem?
    /// AI 问题（kind == .ai 时有效）
    public let aiQuery: String?

    init(app: LauncherAppItem) {
        self.id = "app:\(app.id)"
        self.kind = .app
        self.title = app.name
        self.subtitle = (app.path as NSString).deletingLastPathComponent
        self.app = app
        self.file = nil
        self.aiQuery = nil
    }

    init(file: LauncherFileItem) {
        self.id = "file:\(file.id)"
        self.kind = .file
        self.title = file.name
        self.subtitle = (file.path as NSString).deletingLastPathComponent
        self.app = nil
        self.file = file
        self.aiQuery = nil
    }

    init(command: LauncherCommandItem, groupName: String) {
        self.id = "command:\(groupName)/\(command.id)"
        self.kind = .command
        self.title = command.title
        self.subtitle = groupName
        self.app = nil
        self.file = nil
        self.aiQuery = nil
    }

    init(aiQuery: String) {
        self.id = "ai:\(aiQuery)"
        self.kind = .ai
        self.title = aiQuery
        self.subtitle = LumiPluginLocalization.string("Press Return to ask Lumi", bundle: .module)
        self.app = nil
        self.file = nil
        self.aiQuery = aiQuery
    }
}

/// 启动器聚合搜索模型：应用 + 文件（Spotlight）+ Lumi 命令 + AI 问答
@MainActor
public final class LauncherSearchModel: ObservableObject, SuperLog {
    public nonisolated static let emoji = "🔎"
    public nonisolated static let verbose: Bool = false

    public static let shared = LauncherSearchModel()

    // MARK: - State

    /// 搜索词
    @Published public var query: String = "" {
        didSet { queryDidUpdate() }
    }

    /// 聚合结果
    @Published public private(set) var results: [LauncherResult] = []

    /// 键盘选中索引
    @Published public var selectedIndex: Int = 0

    /// 各内容源开关（持久化 key）
    static let sourceDefaultsKeys: [LauncherResultKind: String] = [
        .app: "QuickLauncher.Source.apps",
        .file: "QuickLauncher.Source.files",
        .command: "QuickLauncher.Source.commands",
    ]

    private let appSearch = AppSearchService.shared
    private let fileSearch = FileSearchService.shared
    private var cancellables: Set<AnyCancellable> = []
    private var queryDebounceTask: Task<Void, Never>?

    /// AI 问答触发前缀
    static let aiPrefix = "?"
    /// 各分组结果上限
    static let appLimit = 6
    static let commandLimit = 5

    // MARK: - Initialization

    private init() {
        // Spotlight 文件结果变化时重建聚合列表
        fileSearch.$results
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.rebuildResults()
            }
            .store(in: &cancellables)
    }

    /// 内容源是否启用（默认全开）
    public static func isSourceEnabled(_ kind: LauncherResultKind, defaults: UserDefaults = .standard) -> Bool {
        guard let key = sourceDefaultsKeys[kind] else { return true }
        return defaults.object(forKey: key) as? Bool ?? true
    }

    // MARK: - Search

    private func queryDidUpdate() {
        rebuildResults()
        queryDebounceTask?.cancel()
        queryDebounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled, let self else { return }
            if Self.isSourceEnabled(.file) {
                self.fileSearch.search(self.query)
            }
        }
    }

    /// 根据当前查询词重建聚合结果
    func rebuildResults() {
        defer { clampSelection() }

        let trimmed = query.trimmingCharacters(in: .whitespaces)

        // `?` 前缀：AI 问答模式
        if trimmed.hasPrefix(Self.aiPrefix) {
            let question = String(trimmed.dropFirst(Self.aiPrefix.count)).trimmingCharacters(in: .whitespaces)
            results = question.isEmpty ? [] : [LauncherResult(aiQuery: question)]
            return
        }

        guard !trimmed.isEmpty else {
            results = []
            fileSearch.cancelSearch()
            return
        }

        var merged: [LauncherResult] = []

        // 应用
        if Self.isSourceEnabled(.app) {
            let lowered = trimmed.lowercased()
            let apps = appSearch.search(matching: trimmed).prefix(Self.appLimit)
            // 前缀命中排前
            merged += apps
                .sorted { a, b in
                    let aPrefix = a.name.lowercased().hasPrefix(lowered)
                    let bPrefix = b.name.lowercased().hasPrefix(lowered)
                    if aPrefix != bPrefix { return aPrefix }
                    return a.name.count < b.name.count
                }
                .map(LauncherResult.init(app:))
        }

        // 文件（Spotlight 异步，结果到达后经 $results 再触发 rebuild）
        if Self.isSourceEnabled(.file) {
            merged += fileSearch.results.map(LauncherResult.init(file:))
        }

        // 命令
        if Self.isSourceEnabled(.command) {
            merged += searchCommands(matching: trimmed).prefix(Self.commandLimit)
        }

        results = merged
    }

    /// 展平并过滤内核命令组
    func searchCommands(matching query: String) -> [LauncherResult] {
        guard let groups = LauncherBridge.commandGroupsProvider?() else { return [] }
        let lowered = query.lowercased()
        var found: [LauncherResult] = []
        for group in groups {
            for item in group.items where
                item.title.lowercased().contains(lowered) || group.name.lowercased().contains(lowered)
            {
                found.append(LauncherResult(command: item, groupName: group.name))
            }
        }
        return found
    }

    private func clampSelection() {
        if selectedIndex >= results.count { selectedIndex = 0 }
    }

    // MARK: - Execution

    /// 执行选中的结果，返回是否由调用方负责关闭窗口（始终 true，命令执行失败仅记录日志）
    @discardableResult
    public func execute(at index: Int) -> Bool {
        guard index >= 0 && index < results.count else { return false }
        let result = results[index]

        switch result.kind {
        case .app:
            if let app = result.app {
                appSearch.launchApp(app)
            }
        case .file:
            if let file = result.file {
                fileSearch.openFile(file)
            }
        case .command:
            executeCommand(matching: result)
        case .ai:
            if let question = result.aiQuery {
                LauncherBridge.askAIHandler?(question)
            }
        }
        return true
    }

    /// 按结果 id 找到原始命令并执行（避免闭包非 Sendable 存进结果）。
    private func executeCommand(matching result: LauncherResult) {
        guard let groups = LauncherBridge.commandGroupsProvider?() else { return }
        for group in groups {
            for item in group.items where result.id == "command:\(group.name)/\(item.id)" {
                item.action()
                return
            }
        }
        if Self.verbose {
            QuickLauncherPlugin.logger.info("\(self.t)未找到命令结果对应的原始项: \(result.title)")
        }
    }

    // MARK: - Reset

    /// 窗口隐藏时复位状态
    public func reset() {
        query = ""
        selectedIndex = 0
        fileSearch.cancelSearch()
    }
}
