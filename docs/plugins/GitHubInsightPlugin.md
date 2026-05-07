# GitHubInsight Plugin Roadmap

## 1. 概述 (Overview)

### 1.1 背景

Lumi 作为 AI 编程助手，目前的知识范围局限于用户本地的项目代码和文件。但在实际开发中，开发者经常面临以下场景：

- "我的技术栈有没有更好用的替代方案？"
- "这个框架的最佳实践和官方示例在哪里？"
- "有没有轻量级的库能替代我当前这个臃肿的依赖？"

这些问题需要 Agent 具备**"行业视野"**——了解当前项目在 GitHub 开源生态中的位置、相关项目和最佳实践。

### 1.2 目标

- **项目画像**: 自动分析当前项目的技术栈、依赖、架构特征，生成结构化画像。
- **生态发现**: 基于画像在后台异步搜索 GitHub，发现相关的开源项目、替代方案和最佳实践。
- **知识注入**: 将发现结果通过中间件按需注入对话上下文，让 Agent 在回答时具备开源生态视角。
- **可视化反馈**: 通过状态栏和弹出面板，让用户查看和管理知识库内容。

### 1.3 设计原则

- **零内核修改**: 完全通过插件实现，利用 `SendMiddleware` + `StatusBar` + `AgentTool` 扩展点。
- **零阻塞**: 所有网络请求、解析、索引构建均在后台 Actor 中执行，绝不阻塞主线程或 Agent 循环。
- **按需注入**: 知识库内容不全量塞给 LLM，而是通过中间件按相关性提取 Top-K 摘要，或提供专用工具按需查询。
- **隐私安全**: 仅读取项目元数据（依赖清单、README、目录结构），不上传任何源码。

---

## 2. 架构设计 (Architecture)

### 2.1 核心组件关系图

```
本地项目文件系统
       │
       ├── package.json / Podfile / build.gradle ...
       ├── README.md
       └── 目录结构
           │
           ▼
  ┌─────────────────────┐
  │  ProjectProfiler     │  提取技术栈、依赖、关键词
  │  (项目画像引擎)       │
  └─────────┬───────────┘
            │
            ▼
  ┌─────────────────────┐       ┌──────────────────┐
  │  GitHubDiscoverer    │──────►│  GitHub API/CLI  │
  │  (生态发现引擎)       │◄──────┤  (网络层)        │
  └─────────┬───────────┘       └──────────────────┘
            │
            ▼
  ┌─────────────────────┐       ┌──────────────────┐
  │  KnowledgeBase       │──────►│  本地 JSON 存储   │
  │  (知识库构建器)       │◄──────┤  ~/Library/...   │
  └─────────┬───────────┘       └──────────────────┘
            │
      ┌─────┴──────┐
      ▼            ▼
┌───────────┐  ┌────────────────┐
│ Middleware │  │  StatusBar UI  │
│ (Prompt   │  │  (状态栏+面板)  │
│  注入)    │  │                │
└─────┬─────┘  └───────┬────────┘
      │                │
      ▼                ▼
  Agent 对话流      用户可视面板
```

### 2.2 插件目录结构

```
LumiApp/Plugins/GitHubInsightPlugin/
├── GitHubInsightPlugin.swift              # 插件入口，注册中间件 + 状态栏 + 工具
├── Services/
│   ├── ProjectProfiler.swift              # 项目画像引擎
│   ├── GitHubDiscoverer.swift             # GitHub 搜索与发现
│   └── KnowledgeBaseManager.swift         # 知识库管理 (Actor)
├── Models/
│   ├── ProjectProfile.swift               # 项目画像数据结构
│   ├── KBEntry.swift                      # 知识库条目数据结构
│   └── SyncState.swift                    # 同步状态枚举
├── Middleware/
│   └── GitHubKBMiddleware.swift           # Prompt 注入中间件
├── Tools/
│   └── QueryEcoKBTool.swift               # 知识库查询工具 (可选)
└── Views/
    ├── GitHubKBStatusBarView.swift        # 状态栏组件
    └── GitHubKBPopover.swift              # 知识探索面板
```

---

## 3. 详细设计 (Detailed Design)

### 3.1 项目画像引擎 (`ProjectProfiler`)

**职责**: 快速扫描项目文件，提取技术栈特征，生成结构化画像。

**扫描目标**:

| 文件/目录 | 提取信息 |
|-----------|----------|
| `package.json` | JavaScript/TypeScript 项目依赖、框架 (React/Vue/Next) |
| `Podfile` / `Package.swift` | Swift/iOS 项目依赖、平台版本 |
| `pom.xml` / `build.gradle` | Java/Kotlin 项目依赖、构建工具 |
| `go.mod` | Go 模块依赖 |
| `Cargo.toml` | Rust 项目依赖 |
| `requirements.txt` / `pyproject.toml` | Python 项目依赖 |
| `README.md` | 项目描述、关键词 |
| `.github/`, `docs/`, `src/`, `app/` | 项目类型推断 (Web/App/SDK/CLI) |

**输出数据结构**:

```swift
struct ProjectProfile {
    let primaryLanguage: String       // "Swift"
    let frameworks: [String]          // ["SwiftUI", "Combine"]
    let dependencies: [String]        // ["Alamofire", "Realm"]
    let projectType: ProjectType      // .mobile, .web, .cli, .sdk
    let keywords: [String]            // 从 README 提取的关键词
    let description: String           // 项目简述
    let platform: String              // "iOS 16+", "macOS 13+"
}
```

### 3.2 GitHub 发现引擎 (`GitHubDiscoverer`)

**职责**: 基于项目画像生成搜索查询，调用 GitHub API 获取相关开源项目。

**搜索策略**:

1. **组合查询语法** (GitHub Advanced Search):
   ```
   language:swift topic:networking stars:>500 pushed:>2024-01-01
   ```

2. **多维度检索**:
   - **替代方案 (Alternative)**: 寻找当前依赖的替代品，对比优劣。
   - **生态互补 (Complementary)**: 寻找当前技术栈常用的配套工具。
   - **最佳实践 (Example)**: 寻找官方示例、标杆项目、教程仓库。

3. **排除策略**:
   - 排除已依赖的仓库（避免推荐正在使用的）。
   - 排除 archived 仓库。
   - 排除低质量 fork（仅保留 Star > 50 的 fork）。

**认证与限流**:

| 优先级 | 方式 | 限制 | 说明 |
|--------|------|------|------|
| 1 | 本地 `gh` CLI | 5000次/小时 | 自动复用用户已有的 GitHub 认证 |
| 2 | 用户配置的 Token | 5000次/小时 | 在插件设置中配置 |
| 3 | 未认证 REST API | 10次/分钟 | 降级方案，仅用于极简场景 |

**限流处理**:
- 请求队列 + 指数退避重试。
- 本地缓存 (ETag/If-Modified-Since)，相同查询 24h 内命中缓存。
- 限流时状态栏显示警告，不阻塞任何功能。

### 3.3 知识库构建器 (`KnowledgeBaseManager`)

**职责**: 将原始 API 结果清洗、去重、结构化，持久化到本地。

**存储位置**:
```
~/Library/Application Support/Lumi/github-kb/
├── index.json                          # 全局索引
├── <project-hash>.json                 # 每个项目的知识库
└── cache/                              # API 响应缓存
    └── <query-hash>.json
```

**条目数据结构**:

```swift
struct KBEntry: Identifiable, Codable {
    let id: UUID
    let repoURL: String
    let fullName: String                  // "owner/repo"
    let description: String
    let stars: Int
    let language: String?
    let topics: [String]
    let lastPushedAt: Date
    let relevanceScore: Double            // 0.0 ~ 1.0
    let relationType: RelationType        // .alternative, .complementary, .example
    let keyInsights: [String]             // AI 提炼的要点
    let syncedAt: Date
}

enum RelationType: String, Codable {
    case alternative       // 替代方案
    case complementary     // 生态互补
    case example           // 最佳实践/示例
}
```

**相关性评分算法**:

```
score = language_match * 0.35
      + keyword_overlap * 0.25
      + stars_score     * 0.20    // log(stars) 归一化
      + recency_score   * 0.20    // 最近 push 时间衰减
```

### 3.4 中间件设计 (`GitHubKBMiddleware`)

**职责**: 在 LLM 请求前，根据对话上下文按需注入知识库摘要。

- **Order**: `60` (位于 SkillPlugin(50) 之后，RAG(100) 之前)。
- **触发条件**:
  - 对话内容涉及架构设计、依赖选型、技术难题、库推荐时自动注入。
  - 通过关键词匹配判断相关性 (如 "recommend", "alternative", "best practice", "library", "框架", "推荐", "替代")。

**注入内容格式**:

```markdown
## GitHub Ecosystem Insights

Based on your project profile (Swift / SwiftUI / iOS), here are relevant open-source references:

| Repo | Type | Key Insight |
|------|------|-------------|
| `owner/repo-a` | Complementary | Official SwiftUI state management example |
| `owner/repo-b` | Alternative | 50% lighter than your current networking library |

Use `query_eco_kb` tool to get detailed information about a specific repository.
```

### 3.5 知识库查询工具 (`QueryEcoKBTool`) — 可选

**职责**: 注册为 AgentTool，允许 Agent 按需查询知识库详情。

- **工具名**: `query_eco_kb`
- **参数**:
  - `query` (string): 搜索关键词，如 "networking"
  - `relation_type` (string, optional): 过滤类型 ("alternative" / "complementary" / "example")
- **返回**: 匹配条目的详细信息列表。

**使用场景**: 当 Agent 需要深入了解某个库时，主动调用此工具获取结构化数据，而非依赖 Prompt 注入的摘要。

### 3.6 状态栏 UI 设计

#### A. 入口 (`GitHubKBStatusBarView`)

- **位置**: 底部状态栏右侧。
- **显示内容**:

| 状态 | 显示 |
|------|------|
| 同步中 | `🔄 Syncing...` |
| 就绪 | `🌐 12 insights` |
| 限流 | `🌐 ⚠️ Rate Limited` |
| 未选择项目 / 无数据 | 隐藏 |

- **刷新时机**:
  - 视图首次出现 (`onAppear`)
  - 项目路径变化 (`onChange`)
  - 从其他应用切回 (`applicationDidBecomeActive`)
  - 后台同步完成 (通过 NotificationCenter 监听)

#### B. 弹出面板 (`GitHubKBPopover`)

```
┌─────────────────────────────────────────────┐
│ 🌐 GitHub Ecosystem KB              [12]    │
│ Profile: Swift / SwiftUI / iOS              │
├──────┬──────────────────────────────────────┤
│  All │ Alternative │ Complementary │ Example │  ← 筛选 Tab
├──────┴──────────────────────────────────────┤
│                                              │
│  📦 BetterNetworking                    ★ 3.1k │
│  Type: Alternative                           │
│  💡 Async/Await native, 50% lighter than     │
│     your current Alamofire                   │
│                                     [GitHub] │
│──────────────────────────────────────────────│
│  📦 SwiftUI-MVVM-Example               ★ 8.2k │
│  Type: Example                               │
│  💡 Official MVVM + State management pattern │
│                                     [GitHub] │
│──────────────────────────────────────────────│
│  📦 SwiftDependency                   ★ 1.2k  │
│  Type: Complementary                         │
│  💡 Lightweight DI container for SwiftUI     │
│                                     [GitHub] │
│──────────────────────────────────────────────│
│  [🔄 Sync Now]                 [⚙️ Settings] │
└─────────────────────────────────────────────┘
```

---

## 4. 交互流程 (Interaction Flow)

### 4.1 初始化同步流程

```
用户打开项目
    │
    ▼
GitHubKBStatusBarView.onAppear
    │
    ├── ProjectProfiler 扫描项目
    │   ├── 读取 package.json / Podfile / README.md ...
    │   └── 生成 ProjectProfile
    │
    ├── 状态栏显示 "🔄 Syncing..."
    │
    ├── GitHubDiscoverer 搜索 (后台异步)
    │   ├── 构建查询 (基于画像)
    │   ├── 调用 GitHub API / gh CLI
    │   ├── 过滤、去重、评分
    │   └── 返回 [KBEntry]
    │
    ├── KnowledgeBaseManager 持久化
    │   └── 写入本地 JSON
    │
    └── 状态栏显示 "🌐 12 insights"
```

### 4.2 对话注入流程

```
用户发送: "我的网络请求层太重了，有没有轻量替代？"
    │
    ▼
SendPipeline 执行中间件链
    │
    ├── Order 0:   AgentRulesMiddleware
    ├── Order 50:  SkillSendMiddleware
    ├── Order 60:  GitHubKBMiddleware (拦截)
    │   │
    │   ├── 检测关键词匹配 ("替代", "alternative")
    │   │
    │   ├── 从知识库查询 relationType == .alternative
    │   │
    │   └── 注入 Top-3 摘要:
    │       """
    │       ## GitHub Ecosystem Insights
    │       | BetterNetworking | Alternative | Async/Await, 50% lighter |
    │       | ... | ... | ... |
    │       """
    │
    └── Order 100: RAGMiddleware
    │
    ▼
LLM 回复 (具备开源生态视角):
    "基于你项目当前的 Alamofire 依赖，我找到了一个更轻量的替代方案:
     BetterNetworking (★ 3.1k)，它基于原生 Async/Await，
     比 Alamofire 轻 50%，且无第三方依赖..."
```

---

## 5. 实施计划 (Implementation Plan)

### Phase 1: 项目画像引擎
- [ ] 定义 `ProjectProfile` 数据模型
- [ ] 实现 `ProjectProfiler`: 解析常见 Manifest 文件
- [ ] 支持 `package.json`, `Podfile`, `Package.swift`, `README.md`
- [ ] 输出结构化画像供后续模块消费

### Phase 2: GitHub 发现引擎
- [ ] 实现 `GitHubDiscoverer`: 搜索查询构建
- [ ] 集成 GitHub REST API (搜索端点)
- [ ] 支持 `gh` CLI 降级方案
- [ ] 实现请求队列 + 限流处理 + 本地缓存

### Phase 3: 知识库构建
- [ ] 定义 `KBEntry` 数据模型
- [ ] 实现 `KnowledgeBaseManager` (Actor)
- [ ] JSON 持久化 + 增量更新逻辑
- [ ] 相关性评分算法实现

### Phase 4: 中间件与工具
- [ ] 实现 `GitHubKBMiddleware` (Order: 60)
- [ ] 关键词触发检测
- [ ] Top-K 摘要注入
- [ ] (可选) 实现 `QueryEcoKBTool` AgentTool

### Phase 5: UI 与状态栏
- [ ] 实现 `GitHubKBStatusBarView`
- [ ] 实现 `GitHubKBPopover` (含筛选 Tab)
- [ ] 绑定 `KnowledgeBaseManager` 数据源
- [ ] 同步状态管理 (Syncing / Ready / RateLimited)

### Phase 6: 测试与优化
- [ ] 多语言项目画像测试 (Swift/JS/Python/Go/Java)
- [ ] API 限流场景容错测试
- [ ] 增量同步性能验证
- [ ] Token 消耗评估与优化

---

## 6. 技术决策 (Technical Decisions)

| 决策点 | 方案 | 理由 |
|--------|------|------|
| **认证方式** | 优先 `gh` CLI → 用户 Token → 未认证 | 零额外配置优先，平衡可用性与限流 |
| **存储格式** | JSON 文件 + 内存缓存 | 轻量、易调试、无需引入第三方 DB |
| **中间件 Order** | 60 | 在 Skill(50) 之后，RAG(100) 之前 |
| **注入策略** | 按关键词触发，仅注入 Top-3 摘要 | 控制 Token 消耗，防止上下文爆炸 |
| **详情获取** | 通过专用工具懒加载 | 避免全量注入，Agent 按需查询 |
| **后台执行** | `Task.detached` + Actor 隔离 | 绝不阻塞 UI 和 Agent 循环 |
| **更新频率** | 首次全量 → 24h 全量刷新 → 手动触发 | 节省 API 配额，保持数据新鲜 |

---

## 7. 中间件 Order 对照表

| 中间件 | Order | 职责 |
|-------|-------|------|
| `AgentRulesContextSendMiddleware` | 0 | 注入项目规则摘要 |
| `SkillSendMiddleware` | 50 | 注入可用 Skill 摘要 |
| **`GitHubKBMiddleware`** | **60** | **注入 GitHub 生态洞察** |
| `RAGSendMiddleware` | 100 | 检索项目文档 |
| `ToolCallLoopDetectionSendMiddleware` | 150 | 检测工具调用死循环 |

---

## 8. 与现有系统的联动

| 系统 | 联动方式 |
|------|----------|
| **SkillPlugin** | 当发现某仓库有成熟的 Skill 时，提示用户安装对应 Skill |
| **RAGPlugin** | 知识库条目可作为外部知识源注入 RAG 检索池，扩大检索覆盖面 |
| **BrewManagerPlugin** | 当推荐的工具可通过 Homebrew 安装时，提供一键安装建议 |
| **AgentGitToolsPlugin** | 利用已配置的 `gh` CLI 认证，免额外 Token 配置 |
| **ProjectOverviewPlugin** | 复用项目结构分析能力，减少重复扫描 |

---

## 9. 风险与应对 (Risks & Mitigations)

| 风险 | 影响 | 应对策略 |
|------|------|----------|
| **GitHub API 限流** | 无法发现新项目 | 请求队列 + 指数退避 + 本地缓存 + `gh` CLI 降级 + 状态栏警告 |
| **相关性误判 / 噪音** | 推荐无关项目 | Stars 阈值过滤 + 排除 archived/fork + 用户反馈标记"不相关" |
| **Token 消耗过大** | 上下文窗口被挤占 | 严格限制注入条目数 (Top-3) + 仅传摘要 + 详情工具懒加载 |
| **扫描耗时过长** | 影响首次体验 | 完全后台异步 + 状态栏进度提示 + 缓存复用 |
| **隐私合规** | 用户担忧数据泄露 | 仅分析公开元数据 + 不上传源码 + 设置中提供全局关闭选项 |

---

此 Roadmap 定义了 **GitHubInsightPlugin** 的完整实现路径。方案完全基于 Lumi 现有的插件扩展点 (SendMiddleware + StatusBar + AgentTool)，不侵入内核，可独立开发、测试和集成。
