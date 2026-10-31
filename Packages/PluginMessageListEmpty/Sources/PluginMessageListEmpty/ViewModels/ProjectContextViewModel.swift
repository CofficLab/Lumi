import Foundation
import KitProjectDetect
import ProviderConversation
import ProviderGit
import ProviderProject
import ProviderProjectRAG

/// 项目身份：名字、展示路径与技术栈。
///
/// 路径折叠家目录（`/Users/me/Code/x` → `~/Code/x`）不是为了好看：项目名
/// 常常同名，只有路径能把两个项目区分开。
struct ProjectContextIdentity: Equatable {
    let name: String
    let displayPath: String
    /// 推断出的技术栈标签。为空表示没能识别出类型。
    let typeLabels: [String]
    /// 技术栈图标。未识别时为通用文件夹图标。
    let typeSymbol: String
}

/// 项目上下文卡里的一行状态。
///
/// ## 为什么不留「不可点的行」
///
/// 一行状态如果既不能点、又不能表达任何用户能用的动作，它就是噪音。
/// 因此每一行都必须绑定一个动作，否则根本不渲染。
struct ProjectContextRow: Identifiable, Equatable {
    /// 行点击后触发的动作。
    enum Action: Equatable {
        /// 打开文件树。
        case openFileTree
        /// 打开 Git 面板。
        case openGit
        /// 回到某个历史会话。
        case resumeConversation(UUID)
    }

    let id: String
    let systemImage: String
    /// 主文案。
    let title: String
    /// 次要文案（时间、计数等）。为空则只显示主文案。
    let detail: String?
    let action: Action
}

/// 项目上下文卡展开态里的键值对。
struct ProjectContextDetail: Identifiable, Equatable {
    let id: String
    let label: String
    let value: String
}

/// 汇总「当前项目是什么、现在什么状态」的那一层数据。
///
/// ## 它负责什么
///
/// - 身份：项目名、路径、技术栈；
/// - 就绪状态：索引、Git 未提交改动、历史上一次对话；
/// - 展开详情：本项目会话数、关键文件。
///
/// ## 它不负责什么
///
/// 不负责渲染。所有「显示成什么样」的决定都在视图层，这个类型只产出数据。
///
/// ## 并发
///
/// 目录读取、Git 状态、索引状态、会话查询都会离开主线程；`loadGeneration`
/// 保证慢的一次加载不会覆盖新的一次结果。
@MainActor
@Observable
final class ProjectContextViewModel {
    /// 当前项目身份。没有项目时为 nil。
    private(set) var identity: ProjectContextIdentity?
    /// 可点击的状态行。
    private(set) var rows: [ProjectContextRow] = []
    /// 展开态的键值对。
    private(set) var details: [ProjectContextDetail] = []
    /// 展开态里的关键文件标签。
    private(set) var keyFiles: [String] = []
    /// 是否正在加载。
    private(set) var isLoading = false

    private let project: (any ProjectProviding)?
    private let conversations: (any ConversationManaging)?
    private let projectRAG: (any ProjectRAGProviding)?
    private let git: (any GitRepositoryReading)?

    /// 防止慢加载覆盖新结果的代次标记。
    private var loadGeneration = 0
    /// 已经加载过的项目路径。同一个项目不重复读盘。
    private var loadedProjectPath: String?
    /// 会话 ID 缓存：`(项目路径, 窗口起点所属日, 会话 ID)`。
    private var conversationIDsCache: (path: String, day: Date, ids: [String])?

    init(
        project: (any ProjectProviding)?,
        conversations: (any ConversationManaging)?,
        projectRAG: (any ProjectRAGProviding)?,
        git: (any GitRepositoryReading)?
    ) {
        self.project = project
        self.conversations = conversations
        self.projectRAG = projectRAG
        self.git = git
    }

    /// 当前是否有项目。没有项目时整个上下文卡都不渲染。
    var hasProject: Bool { project?.currentProject != nil }

    /// 当前项目的根目录路径。没有项目时为 nil。
    var currentProjectPath: String? { project?.currentProject?.path }

    /// 加载当前项目的上下文。
    ///
    /// - Parameter force: 忽略「同一项目已加载过」的短路，强制重读。
    public func loadIfNeeded(force: Bool = false) async {
        guard let info = project?.currentProject else {
            clear()
            return
        }
        let path = info.path
        if !force, loadedProjectPath == path, identity != nil { return }

        loadGeneration &+= 1
        let generation = loadGeneration
        isLoading = true
        defer { if generation == loadGeneration { isLoading = false } }

        // 身份先落地：路径与名字不需要读盘就能拿到，等目录读完再补上技术栈。
        // 否则空态会先闪一下「选个例子，或在下方输入你的问题」，
        // 再跳成项目身份——先给对的那一句，比先给一句错的话再改要好。
        if identity?.displayPath != Self.abbreviatedPath(path) {
            identity = ProjectContextIdentity(
                name: info.name,
                displayPath: Self.abbreviatedPath(path),
                typeLabels: [],
                typeSymbol: "folder"
            )
        }

        // 根目录条目一次读完：技术栈判定与关键文件标签共用它。
        let rootEntries = await Self.readRootEntryNames(at: path)

        async let indexStatus = fetchIndexStatus(path: path)
        async let gitState = fetchGitState(path: path)
        async let conversationState = fetchConversationState(path: path)

        let index = await indexStatus
        let git = await gitState
        let conversation = await conversationState

        guard generation == loadGeneration else { return }

        let type = ProjectTypeDetector.detect(rootEntryNames: rootEntries)
        self.identity = ProjectContextIdentity(
            name: info.name,
            displayPath: Self.abbreviatedPath(path),
            typeLabels: type.labels,
            typeSymbol: type.symbolName
        )
        self.keyFiles = Self.notableFiles(in: rootEntries)
        self.rows = Self.makeRows(
            index: index,
            git: git,
            lastConversation: conversation.last
        )
        self.details = Self.makeDetails(
            conversationCount: conversation.count,
            last: conversation.last
        )
        loadedProjectPath = path
    }

    /// 取某个项目在给定时间窗口内仍有活动的会话 ID。
    ///
    /// 活动卡按项目维度统计时用它过滤消息。窗口起点用来把会话集合限制在
    /// 窗口内：窗口之外才更新的会话不可能贡献窗口内的消息。
    ///
    /// - Returns: 会话 ID 列表。项目下没有会话时是空数组（不是 nil）——
    ///   空数组表示「这个范围没有会话」，与「不限会话」必须区分开。
    public func conversationIDs(forProjectAt path: String, since: Date) async -> [String] {
        let day = Calendar.current.startOfDay(for: since)
        if let cached = conversationIDsCache, cached.path == path, cached.day == day {
            return cached.ids
        }
        let ids = await conversations?.conversationIDs(projectPath: path, updatedSince: since) ?? []
        conversationIDsCache = (path, day, ids)
        return ids
    }

    /// 清空所有状态（没有项目时）。
    private func clear() {
        identity = nil
        rows = []
        details = []
        keyFiles = []
        loadedProjectPath = nil
        conversationIDsCache = nil
    }

    // MARK: - 数据获取

    private func fetchIndexStatus(path: String) async -> IndexState {
        guard let projectRAG else { return .unavailable }
        // 正在索引时，status 往往还是上一轮的旧值——先问「是否在索引」，
        // 否则用户会看到一个早就过时的文件数。
        if projectRAG.isIndexing(projectPath: path) { return .indexing }
        guard let status = try? await projectRAG.indexStatus(projectPath: path) else {
            return .unavailable
        }
        return .ready(status)
    }

    private func fetchGitState(path: String) async -> GitState? {
        guard let git else { return nil }
        guard let status = try? await git.status(atPath: path) else { return nil }
        let changed = status.modified.count + status.added.count + status.deleted.count
            + status.renamed.count + status.staged.count
        guard changed > 0 else { return nil }
        return GitState(changedFileCount: changed)
    }

    private func fetchConversationState(path: String) async -> ConversationState {
        guard let conversations else { return ConversationState(count: 0, last: nil) }
        // 顶层对话才代表「用户在这个项目里做过什么」；子代理会话不参与。
        let page = await conversations.fetchConversationPage(
            limit: 1,
            beforeUpdatedAt: nil,
            beforeID: nil,
            includingChildConversations: false,
            projectPath: path
        )
        let count = await conversations.conversationCount(projectPath: path, includingChildConversations: false)
        return ConversationState(count: count, last: page.first)
    }

    // MARK: - 组装

    private struct GitState {
        let changedFileCount: Int
    }

    /// 索引的三种状态。
    ///
    /// 「正在索引」必须单独表达：索引跑起来时 `indexStatus` 给出的仍是上一轮
    /// 的旧文件数，直接显示等于骗人。
    private enum IndexState {
        case ready(ProjectRAGIndexStatus)
        case indexing
        case unavailable
    }

    private struct ConversationState {
        let count: Int
        let last: ConversationSummary?
    }

    private static func makeRows(
        index: IndexState,
        git: GitState?,
        lastConversation: ConversationSummary?
    ) -> [ProjectContextRow] {
        var rows: [ProjectContextRow] = []

        switch index {
        case .ready(let status):
            rows.append(
                ProjectContextRow(
                    id: "index",
                    systemImage: "checkmark.seal",
                    title: ProjectContextText.format("Indexed %lld files", status.fileCount),
                    detail: relativeTime(status.lastIndexedAt),
                    action: .openFileTree
                )
            )
        case .indexing:
            rows.append(
                ProjectContextRow(
                    id: "index",
                    systemImage: "arrow.triangle.2.circlepath",
                    title: pluginLocalization.string("Indexing…"),
                    detail: nil,
                    action: .openFileTree
                )
            )
        case .unavailable:
            break
        }

        if let git {
            rows.append(
                ProjectContextRow(
                    id: "git",
                    systemImage: "pencil",
                    title: ProjectContextText.format("%lld files have uncommitted changes", git.changedFileCount),
                    detail: nil,
                    action: .openGit
                )
            )
        }

        if let lastConversation {
            rows.append(
                ProjectContextRow(
                    id: "last-conversation",
                    systemImage: "clock",
                    title: ProjectContextText.format("Last time here: %@", lastConversation.displayTitle),
                    detail: relativeTime(lastConversation.updatedAt),
                    action: .resumeConversation(lastConversation.id)
                )
            )
        }

        return rows
    }

    private static func makeDetails(
        conversationCount: Int,
        last: ConversationSummary?
    ) -> [ProjectContextDetail] {
        var details: [ProjectContextDetail] = []
        details.append(
            ProjectContextDetail(
                id: "conversation-count",
                label: pluginLocalization.string("Conversations"),
                value: ProjectContextText.format("%lld", conversationCount)
            )
        )
        if let last {
            details.append(
                ProjectContextDetail(
                    id: "last-conversation",
                    label: pluginLocalization.string("Last conversation"),
                    value: last.displayTitle
                )
            )
        }
        return details
    }

    /// 值得展示为标签的根目录文件。
    ///
    /// 只挑「能说明这个项目是什么」的入口文件，避免把根目录所有文件都列一遍。
    private static func notableFiles(in rootEntries: [String]) -> [String] {
        let preferred = [
            "README.md", "AGENTS.md", "Package.swift", "package.json",
            "Cargo.toml", "pyproject.toml", "go.mod", "Gemfile",
            "composer.json", "pubspec.yaml", "build.gradle", "build.zig",
            "mix.exs", ".lumi-project",
        ]
        var result: [String] = []
        for name in preferred where rootEntries.contains(name) {
            result.append(name)
        }
        // 工程目录（Xcode / Visual Studio / Swift Package）也值得露出。
        for entry in rootEntries.sorted() {
            guard result.count < 6 else { break }
            if entry.hasSuffix(".xcodeproj") || entry.hasSuffix(".sln") {
                result.append(entry)
            }
        }
        return Array(result.prefix(6))
    }

    // MARK: - 工具

    /// 读根目录条目名。放在后台线程，避免首帧被磁盘 IO 拖住。
    private static func readRootEntryNames(at path: String) async -> [String] {
        await Task.detached(priority: .utility) {
            (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
        }.value
    }

    /// 把家目录折叠成 `~`。
    static func abbreviatedPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        guard !home.isEmpty, path == home || path.hasPrefix(home + "/") else { return path }
        return "~" + path.dropFirst(home.count)
    }

    /// 相对时间描述（"3 分钟前" / "2 hours ago"）。
    static func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = pluginLocalization.preferredLocale()
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

/// 带参数的本地化文案。
///
/// `pluginLocalization.string(_:)` 只解析 key、不接受格式参数；但它返回的**模板**
/// 里带着 `%lld` 这类占位符，再交给 `String(format:locale:arguments:)` 填值即可。
/// 与活动卡锚点文案用的是同一套路。
enum ProjectContextText {
    /// 取本地化模板并填入参数。
    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        let format = pluginLocalization.string(key)
        return String(format: format, locale: pluginLocalization.preferredLocale(), arguments: arguments)
    }
}
