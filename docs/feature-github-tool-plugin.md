# GitHub 工具插件实现方案

本文档描述了为 Lumi 项目开发 GitHub 工具插件的完整实现方案，该插件允许 Agent 通过自然语言调用 GitHub API 执行仓库查询、代码搜索、文件获取等操作。

## 目录

- [1. 需求分析](#1-需求分析)
- [2. 插件架构](#2-插件架构)
- [3. 目录结构](#3-目录结构)
- [4. 核心实现](#4-核心实现)
- [5. 工具定义](#5-工具定义)
- [6. 配置界面](#6-配置界面)
- [7. 实现步骤](#7-实现步骤)

---

## 1. 需求分析

### 1.1 功能需求

| 功能 | 描述 | 优先级 |
|------|------|--------|
| 仓库信息查询 | 获取 GitHub 仓库的基本信息（stars、forks、描述等） | P0 |
| 代码搜索 | 搜索 GitHub 上的代码片段和仓库 | P0 |
| 文件内容获取 | 获取指定仓库中文件的内容 | P0 |
| 趋势项目 | 获取 GitHub 趋势项目列表 | P1 |
| Issue 管理 | 创建、查询、更新 Issue | P2 |
| PR 管理 | 创建、查询 Pull Request | P2 |

### 1.2 用户场景

1. **开发者查询仓库信息**
   - 用户：「帮我查一下 SwiftUI 的 star 数」
   - Agent：调用 `github_repo_info` 工具

2. **搜索代码示例**
   - 用户：「找一个用 Swift 写的网络请求示例」
   - Agent：调用 `github_search` 工具

3. **查看文件内容**
   - 用户：「我想看苹果官方 Swift 仓库的 README」
   - Agent：调用 `github_file_content` 工具

---

## 2. 插件架构

### 2.1 Lumi 插件系统概述

Lumi 采用基于协议扩展的插件架构：

```
┌─────────────────────────────────────────────────────────┐
│                    PluginProvider                        │
│  (自动发现、注册、管理所有插件的生命周期)                 │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                   SuperPlugin Protocol                   │
│  (定义所有插件扩展点：UI、工具、中间件、Worker)            │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│                 GitHubToolsPlugin                        │
│  (实现 GitHub 相关功能的具体插件)                         │
└─────────────────────────────────────────────────────────┘
```

### 2.2 核心协议

#### SuperPlugin 协议关键扩展点

```swift
protocol SuperPlugin: Actor {
    // 核心属性
    static var id: String { get }
    static var displayName: String { get }
    static var description: String { get }
    static var iconName: String { get }
    static var isConfigurable: Bool { get }
    static var enable: Bool { get }
    static var order: Int { get }

    // Agent 工具扩展点
    func agentTools() -> [AgentTool]
    func agentToolFactories() -> [AnyAgentToolFactory]

    // 工具展示描述
    func toolPresentationDescriptors() -> [ToolPresentationDescriptor]

    // Worker 描述符
    func workerAgentDescriptors() -> [WorkerAgentDescriptor]

    // 中间件
    func conversationTurnMiddlewares() -> [AnyConversationTurnMiddleware]
    func messageSendMiddlewares() -> [AnyMessageSendMiddleware]

    // UI 扩展点（省略...）
}
```

#### AgentTool 协议

```swift
protocol AgentTool: Sendable {
    var name: String { get }           // 工具名称
    var description: String { get }    // 工具描述
    var inputSchema: [String: Any] { get }  // 输入参数 JSON Schema

    func execute(arguments: [String: ToolArgument]) async throws -> String
}
```

#### AgentToolFactory 协议

```swift
@MainActor
protocol AgentToolFactory {
    var id: String { get }
    var order: Int { get }
    func makeTools(env: AgentToolEnvironment) -> [AgentTool]
}
```

---

## 3. 目录结构

```
LumiApp/Plugins/GitHubToolsPlugin/
├── GitHubToolsPlugin.swift          # 插件主类（SuperPlugin 实现）
├── Tools/
│   ├── GitHubRepoInfoTool.swift     # 仓库信息查询工具
│   ├── GitHubSearchTool.swift       # 搜索工具
│   ├── GitHubFileContentTool.swift  # 文件内容获取工具
│   └── GitHubTrendingTool.swift     # 趋势项目工具
├── Services/
│   └── GitHubAPIService.swift       # GitHub API 客户端
├── Models/
│   └── GitHubModels.swift           # 数据模型
└── Views/
    └── GitHubPluginSettingsView.swift  # 设置界面
```

---

## 4. 核心实现

### 4.1 插件主类

**文件**: `GitHubToolsPlugin.swift`

```swift
import Foundation
import MagicKit

/// GitHub 工具插件
///
/// 为 Agent 提供访问 GitHub API 的能力，包括仓库查询、文件检索等。
actor GitHubToolsPlugin: SuperPlugin {
    // MARK: - Plugin Properties

    static let id: String = "GitHubTools"
    static let displayName: String = "GitHub Tools"
    static let description: String = "提供访问 GitHub API 的 Agent 工具（仓库/文件/搜索）。"
    static let iconName: String = "github"
    static let isConfigurable: Bool = true
    static let enable: Bool = true
    static var order: Int { 15 }

    static let shared = GitHubToolsPlugin()

    // MARK: - Agent Tool Factories

    @MainActor
    func agentToolFactories() -> [AnyAgentToolFactory] {
        [AnyAgentToolFactory(GitHubToolsFactory())]
    }

    // MARK: - Tool Presentation Descriptors

    @MainActor
    func toolPresentationDescriptors() -> [ToolPresentationDescriptor] {
        [
            .init(
                toolName: "github_repo_info",
                displayName: "仓库信息",
                emoji: "📦",
                category: .custom,
                order: 0
            ),
            .init(
                toolName: "github_search",
                displayName: "GitHub 搜索",
                emoji: "🔍",
                category: .custom,
                order: 10
            ),
            .init(
                toolName: "github_file_content",
                displayName: "文件内容",
                emoji: "📄",
                category: .readFile,
                order: 20
            ),
            .init(
                toolName: "github_trending",
                displayName: "趋势项目",
                emoji: "🔥",
                category: .custom,
                order: 30
            ),
        ]
    }
}

// MARK: - Tools Factory

@MainActor
private struct GitHubToolsFactory: AgentToolFactory {
    let id: String = "github.tools.factory"
    let order: Int = 0

    func makeTools(env: AgentToolEnvironment) -> [AgentTool] {
        [
            GitHubRepoInfoTool(),
            GitHubSearchTool(),
            GitHubFileContentTool(),
            GitHubTrendingTool(),
        ]
    }
}
```

### 4.2 GitHub API 服务

**文件**: `GitHubAPIService.swift`

```swift
import Foundation
import OSLog
import MagicKit

/// GitHub API 服务
///
/// 封装 GitHub REST API v3 的网络请求。
class GitHubAPIService: SuperLog {
    nonisolated static let emoji = "🐙"
    nonisolated static let verbose = true

    static let shared = GitHubAPIService()

    private let baseURL = "https://api.github.com"
    private let session: URLSession

    /// GitHub Token（从插件设置读取）
    var accessToken: String? {
        UserDefaults.standard.string(forKey: "GitHubToken")
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "Accept": "application/vnd.github.v3+json",
            "User-Agent": "Lumi-GitHub-Plugin/1.0"
        ]
        session = URLSession(configuration: config)
    }

    // MARK: - Public Methods

    /// 获取仓库信息
    /// - Parameters:
    ///   - owner: 仓库所有者
    ///   - repo: 仓库名称
    /// - Returns: GitHubRepo 对象
    func getRepoInfo(owner: String, repo: String) async throws -> GitHubRepo {
        let endpoint = "/repos/\(owner)/\(repo)"
        return try await fetch(endpoint)
    }

    /// 搜索仓库
    /// - Parameters:
    ///   - query: 搜索关键词
    ///   - page: 页码
    ///   - perPage: 每页数量
    /// - Returns: GitHubSearchResult 搜索结果
    func searchRepositories(
        query: String,
        page: Int = 1,
        perPage: Int = 10
    ) async throws -> GitHubSearchResult {
        let endpoint = "/search/repositories"
        let params = [
            "q": query,
            "page": "\(page)",
            "per_page": "\(perPage)"
        ]
        return try await fetch(endpoint, params: params)
    }

    /// 获取文件内容
    /// - Parameters:
    ///   - owner: 仓库所有者
    ///   - repo: 仓库名称
    ///   - path: 文件路径
    ///   - branch: 分支名称
    /// - Returns: GitHubFileContent 文件内容
    func getFileContent(
        owner: String,
        repo: String,
        path: String,
        branch: String = "main"
    ) async throws -> GitHubFileContent {
        let endpoint = "/repos/\(owner)/\(repo)/contents/\(path)"
        let params = ["ref": branch]
        return try await fetch(endpoint, params: params)
    }

    /// 获取趋势项目
    /// - Parameter since: 时间范围 (daily/weekly/monthly)
    /// - Returns: GitHubRepo 数组
    func getTrendingRepositories(since: String = "daily") async throws -> [GitHubRepo] {
        // GitHub API 无直接趋势接口，通过搜索模拟
        let query = "stars:>1000"
        let result: GitHubSearchResult = try await fetch(
            "/search/repositories",
            params: ["q": query, "sort": "stars", "order": "desc"]
        )
        return result.items
    }

    // MARK: - Private Methods

    private func fetch<T: Decodable>(
        _ endpoint: String,
        params: [String: String] = [:]
    ) async throws -> T {
        var components = URLComponents(string: baseURL + endpoint)!
        components.queryItems = params.map {
            URLQueryItem(name: $0.key, value: $0.value)
        }

        var request = URLRequest(url: components.url!)
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if Self.verbose {
            os_log("\(Self.t)🌐 GET \(request.url!)")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 403 {
                throw GitHubError.rateLimited
            }
            throw GitHubError.httpError(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Error Types

enum GitHubError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case decodeError
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "无效的 API 响应"
        case .httpError(let code):
            return "HTTP 错误：\(code)"
        case .decodeError:
            return "数据解析失败"
        case .rateLimited:
            return "API 请求超限，请稍后重试"
        }
    }
}
```

### 4.3 数据模型

**文件**: `GitHubModels.swift`

```swift
import Foundation

// MARK: - GitHub Repository

/// GitHub 仓库
struct GitHubRepo: Codable {
    let id: Int
    let name: String
    let fullName: String
    let description: String?
    let htmlUrl: String
    let language: String?
    let stargazersCount: Int
    let forksCount: Int
    let openIssuesCount: Int?
    let owner: GitHubUser
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case fullName = "full_name"
        case description
        case htmlUrl = "html_url"
        case language
        case stargazersCount = "stargazers_count"
        case forksCount = "forks_count"
        case openIssuesCount = "open_issues_count"
        case owner
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - GitHub User

/// GitHub 用户
struct GitHubUser: Codable {
    let login: String
    let id: Int
    let avatarUrl: String
    let htmlUrl: String

    enum CodingKeys: String, CodingKey {
        case login, id
        case avatarUrl = "avatar_url"
        case htmlUrl = "html_url"
    }
}

// MARK: - Search Result

/// GitHub 搜索结果
struct GitHubSearchResult: Codable {
    let totalCount: Int
    let incompleteResults: Bool
    let items: [GitHubRepo]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case incompleteResults = "incomplete_results"
        case items
    }
}

// MARK: - File Content

/// GitHub 文件内容
struct GitHubFileContent: Codable {
    let name: String
    let path: String
    let sha: String
    let size: Int
    let url: String
    let htmlUrl: String
    let gitUrl: String
    let downloadUrl: String
    let type: String
    let content: String?
    let encoding: String?

    enum CodingKeys: String, CodingKey {
        case name, path, sha, size, url
        case htmlUrl = "html_url"
        case gitUrl = "git_url"
        case downloadUrl = "download_url"
        case type, content, encoding
    }

    /// 解码后的内容（处理 base64 编码）
    var decodedContent: String? {
        guard let content = content,
              let data = Data(base64Encoded: content),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
}
```

---

## 5. 工具定义

### 5.1 仓库信息工具

**文件**: `GitHubRepoInfoTool.swift`

```swift
import Foundation
import OSLog
import MagicKit

/// GitHub 仓库信息工具
struct GitHubRepoInfoTool: AgentTool, SuperLog {
    nonisolated static let emoji = "📦"
    nonisolated static let verbose = false

    let name = "github_repo_info"
    let description = "获取 GitHub 仓库的基本信息，包括 star 数、fork 数、描述、主要语言等。"

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "owner": [
                    "type": "string",
                    "description": "仓库所有者（用户名或组织名）"
                ],
                "repo": [
                    "type": "string",
                    "description": "仓库名称"
                ]
            ],
            "required": ["owner", "repo"]
        ]
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let owner = arguments["owner"]?.value as? String,
              let repo = arguments["repo"]?.value as? String else {
            throw NSError(
                domain: name,
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "缺少必需参数：owner 和 repo"]
            )
        }

        if Self.verbose {
            os_log("\(Self.t)🔍 获取仓库信息：\(owner)/\(repo)")
        }

        do {
            let repoInfo = try await GitHubAPIService.shared.getRepoInfo(
                owner: owner,
                repo: repo
            )
            return formatRepoInfo(repoInfo)
        } catch {
            return "获取仓库信息失败：\(error.localizedDescription)"
        }
    }

    private func formatRepoInfo(_ repo: GitHubRepo) -> String {
        """
        📦 \(repo.fullName)

        \(repo.description ?? "无描述")

        ⭐ Stars: \(repo.stargazersCount)
        🍴 Forks: \(repo.forksCount)
        📌 Open Issues: \(repo.openIssuesCount ?? 0)
        💻 Language: \(repo.language ?? "未知")
        🔗 URL: \(repo.htmlUrl)
        """
    }
}
```

### 5.2 搜索工具

**文件**: `GitHubSearchTool.swift`

```swift
import Foundation
import OSLog
import MagicKit

/// GitHub 搜索工具
struct GitHubSearchTool: AgentTool, SuperLog {
    nonisolated static let emoji = "🔍"
    nonisolated static let verbose = false

    let name = "github_search"
    let description = "在 GitHub 上搜索仓库和代码。支持关键词、语言、stars 等条件筛选。"

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "query": [
                    "type": "string",
                    "description": "搜索关键词"
                ],
                "language": [
                    "type": "string",
                    "description": "编程语言过滤（可选）"
                ],
                "minStars": [
                    "type": "number",
                    "description": "最小 star 数（可选）"
                ],
                "limit": [
                    "type": "number",
                    "description": "返回结果数量限制，默认 5"
                ]
            ],
            "required": ["query"]
        ]
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let query = arguments["query"]?.value as? String else {
            throw NSError(
                domain: name,
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "缺少必需参数：query"]
            )
        }

        let language = arguments["language"]?.value as? String
        let minStars = arguments["minStars"]?.value as? Int ?? 0
        let limit = arguments["limit"]?.value as? Int ?? 5

        // 构建搜索查询
        var searchQuery = query
        if let language = language {
            searchQuery += " language:\(language)"
        }
        if minStars > 0 {
            searchQuery += " stars:>=\(minStars)"
        }

        if Self.verbose {
            os_log("\(Self.t)🔍 搜索：\(searchQuery)")
        }

        do {
            let result = try await GitHubAPIService.shared.searchRepositories(
                query: searchQuery,
                perPage: limit
            )
            return formatSearchResult(result)
        } catch {
            return "搜索失败：\(error.localizedDescription)"
        }
    }

    private func formatSearchResult(_ result: GitHubSearchResult) -> String {
        guard !result.items.isEmpty else {
            return "未找到匹配的仓库"
        }

        var output = "🔍 找到 \(result.totalCount) 个结果，显示前 \(result.items.count) 个：\n\n"

        for (index, repo) in result.items.enumerated().prefix(5) {
            output += """
            \(index + 1). **\(repo.fullName)**
               \(repo.description ?? "无描述")
               ⭐ \(repo.stargazersCount) | 🍴 \(repo.forksCount)
               💻 \(repo.language ?? "未知")
               🔗 \(repo.htmlUrl)

            """
        }

        return output
    }
}
```

### 5.3 文件内容工具

**文件**: `GitHubFileContentTool.swift`

```swift
import Foundation
import OSLog
import MagicKit

/// GitHub 文件内容获取工具
struct GitHubFileContentTool: AgentTool, SuperLog {
    nonisolated static let emoji = "📄"
    nonisolated static let verbose = false

    let name = "github_file_content"
    let description = "获取 GitHub 仓库中指定文件的内容。支持读取 README、源代码文件等。"

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "owner": [
                    "type": "string",
                    "description": "仓库所有者"
                ],
                "repo": [
                    "type": "string",
                    "description": "仓库名称"
                ],
                "path": [
                    "type": "string",
                    "description": "文件路径（如 README.md、src/main.swift）"
                ],
                "branch": [
                    "type": "string",
                    "description": "分支名称，默认为 main"
                ]
            ],
            "required": ["owner", "repo", "path"]
        ]
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let owner = arguments["owner"]?.value as? String,
              let repo = arguments["repo"]?.value as? String,
              let path = arguments["path"]?.value as? String else {
            throw NSError(
                domain: name,
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "缺少必需参数"]
            )
        }

        let branch = arguments["branch"]?.value as? String ?? "main"

        if Self.verbose {
            os_log("\(Self.t)📄 获取文件：\(owner)/\(repo)/\(path)")
        }

        do {
            let fileContent = try await GitHubAPIService.shared.getFileContent(
                owner: owner,
                repo: repo,
                path: path,
                branch: branch
            )

            guard let content = fileContent.decodedContent else {
                return "无法解码文件内容"
            }

            return "📄 **\(fileContent.name)**\n\n```\(content)```"
        } catch {
            return "获取文件失败：\(error.localizedDescription)"
        }
    }
}
```

### 5.4 趋势项目工具

**文件**: `GitHubTrendingTool.swift`

```swift
import Foundation
import OSLog
import MagicKit

/// GitHub 趋势项目工具
struct GitHubTrendingTool: AgentTool, SuperLog {
    nonisolated static let emoji = "🔥"
    nonisolated static let verbose = false

    let name = "github_trending"
    let description = "获取 GitHub 趋势项目列表，按时间范围（daily/weekly/monthly）筛选热门开源项目。"

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "since": [
                    "type": "string",
                    "description": "时间范围：daily、weekly、monthly",
                    "enum": ["daily", "weekly", "monthly"]
                ],
                "limit": [
                    "type": "number",
                    "description": "返回数量限制，默认 10"
                ]
            ]
        ]
    }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let since = arguments["since"]?.value as? String ?? "daily"
        let limit = arguments["limit"]?.value as? Int ?? 10

        if Self.verbose {
            os_log("\(Self.t)🔥 获取趋势项目：since=\(since)")
        }

        do {
            let repos = try await GitHubAPIService.shared.getTrendingRepositories(since: since)
            return formatTrendingRepos(Array(repos.prefix(limit)))
        } catch {
            return "获取趋势项目失败：\(error.localizedDescription)"
        }
    }

    private func formatTrendingRepos(_ repos: [GitHubRepo]) -> String {
        guard !repos.isEmpty else {
            return "暂无趋势项目"
        }

        var output = "🔥 GitHub 趋势项目\n\n"

        for (index, repo) in repos.enumerated() {
            output += """
            \(index + 1). **\(repo.fullName)**
               \(repo.description ?? "无描述")
               ⭐ \(repo.stargazersCount) | 💻 \(repo.language ?? "未知")

            """
        }

        return output
    }
}
```

---

## 6. 配置界面

### 6.1 设置视图

**文件**: `GitHubPluginSettingsView.swift`

```swift
import SwiftUI

/// GitHub 插件设置视图
struct GitHubPluginSettingsView: View {
    @State private var token: String = ""
    @State private var isSaved: Bool = false
    @State private var showToken: Bool = false

    var body: some View {
        Form {
            Section(
                header: Text("GitHub 认证"),
                footer: Text("Personal Access Token 将存储在本地，用于访问私有仓库和提高 API 限额。")
            ) {
                Group {
                    if showToken {
                        TextField("Personal Access Token", text: $token)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    } else {
                        SecureField("Personal Access Token", text: $token)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }

                HStack {
                    Button("保存 Token") {
                        saveToken()
                    }
                    .buttonStyle(.borderedProminent)

                    Toggle("显示 Token", isOn: $showToken)

                    if isSaved {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }

                Link(
                    "如何创建 Personal Access Token？",
                    destination: URL(string: "https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens")!
                )
                .font(.caption)
            }

            Section(header: Text("API 限制")) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("未认证用户：60 次/小时")
                    Text("已认证用户：5000 次/小时")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .onAppear {
            loadToken()
        }
    }

    private func saveToken() {
        UserDefaults.standard.set(token, forKey: "GitHubToken")
        isSaved = true

        // 延迟重置保存状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isSaved = false
        }
    }

    private func loadToken() {
        token = UserDefaults.standard.string(forKey: "GitHubToken") ?? ""
    }
}

#Preview {
    GitHubPluginSettingsView()
        .frame(width: 400, height: 300)
}
```

### 6.2 插件主类集成设置视图

在 `GitHubToolsPlugin.swift` 中添加：

```swift
extension GitHubToolsPlugin {
    @MainActor
    func addSettingsView() -> AnyView? {
        AnyView(GitHubPluginSettingsView())
    }
}
```

---

## 7. 实现步骤

### 7.1 开发流程

| 步骤 | 任务 | 预计时间 |
|------|------|----------|
| 1 | 创建插件目录结构 | 10 min |
| 2 | 实现数据模型 (GitHubModels.swift) | 30 min |
| 3 | 实现 API 服务 (GitHubAPIService.swift) | 1 h |
| 4 | 实现基础工具 (RepoInfo/Search/FileContent) | 2 h |
| 5 | 实现趋势工具 (TrendingTool) | 30 min |
| 6 | 实现插件主类 (GitHubToolsPlugin.swift) | 30 min |
| 7 | 实现设置界面 (GitHubPluginSettingsView.swift) | 1 h |
| 8 | 测试与调试 | 2 h |
| **总计** | | **~7 小时** |

### 7.2 代码生成命令

使用以下命令快速创建文件骨架：

```bash
cd LumiApp/Plugins
mkdir -p GitHubToolsPlugin/{Tools,Services,Models,Views}

# 创建文件
touch GitHubToolsPlugin/GitHubToolsPlugin.swift
touch GitHubToolsPlugin/Tools/{GitHubRepoInfoTool,GitHubSearchTool,GitHubFileContentTool,GitHubTrendingTool}.swift
touch GitHubToolsPlugin/Services/GitHubAPIService.swift
touch GitHubToolsPlugin/Models/GitHubModels.swift
touch GitHubToolsPlugin/Views/GitHubPluginSettingsView.swift
```

### 7.3 测试用例

```swift
import XCTest
@testable import Lumi

@MainActor
final class GitHubToolsPluginTests: XCTestCase {
    func testRepoInfoToolSchema() {
        let tool = GitHubRepoInfoTool()
        let schema = tool.inputSchema

        XCTAssertEqual(schema["type"] as? String, "object")
        let properties = schema["properties"] as? [String: Any]
        XCTAssertNotNil(properties?["owner"])
        XCTAssertNotNil(properties?["repo"])
    }

    func testRepoInfoToolExecution() async throws {
        let tool = GitHubRepoInfoTool()
        let arguments: [String: ToolArgument] = [
            "owner": .init("apple"),
            "repo": .init("swift")
        ]

        let result = try await tool.execute(arguments: arguments)
        XCTAssertNotNil(result)
        XCTAssertTrue(result.contains("swift"))
    }
}
```

---

## 8. 扩展方向

### 8.1 未来功能

1. **Issue 管理工具**
   - `github_create_issue` - 创建 Issue
   - `github_list_issues` - 列出 Issue
   - `github_update_issue` - 更新 Issue 状态

2. **PR 管理工具**
   - `github_create_pr` - 创建 Pull Request
   - `github_list_prs` - 列出 Pull Requests
   - `github_review_pr` - 获取 PR 详情

3. **用户信息工具**
   - `github_user_info` - 获取用户信息
   - `github_user_repos` - 获取用户仓库列表

### 8.2 Worker 集成

可以定义一个 "GitHub 专家" Worker：

```swift
@MainActor
func workerAgentDescriptors() -> [WorkerAgentDescriptor] {
    [
        .init(
            id: "github_expert",
            displayName: "GitHub 专家",
            roleDescription: "专注于 GitHub 相关任务，包括仓库管理、代码审查、Issue 跟踪等。",
            specialty: "GitHub API 操作、开源项目协作",
            systemPrompt: """
            You are a GitHub expert assistant.
            Help users with repository management, code search, issue tracking,
            and pull request workflows.
            """,
            order: 0
        )
    ]
}
```

---

## 9. 参考资料

- [GitHub REST API v3 文档](https://docs.github.com/en/rest)
- [GitHub OAuth 认证指南](https://docs.github.com/en/developers/apps/building-oauth-apps)
- [Lumi 插件开发指南](../.claude/rules/SWIFTUI_GUIDE.md)
- [SuperLog 日志规范](../.claude/rules/LOGGING_STANDARDS.md)

---

*文档创建时间：2026-03-13*
