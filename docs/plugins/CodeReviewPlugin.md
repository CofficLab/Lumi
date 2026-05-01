# CodeReview Plugin Roadmap

## 1. 概述 (Overview)

### 1.1 背景
开发者在编写代码后，往往需要进行 Code Review 来确保代码质量、发现潜在 Bug 和安全隐患。手动审查耗时且容易遗漏细节。通过 AI 辅助审查，可以在 Commit 前或合并时自动分析代码变更，提供即时反馈。

### 1.2 目标
- **Diff 分析**: 自动捕获 Git Diff 变更，进行深度代码审查。
- **多维评估**: 检查潜在 Bug、安全漏洞、性能瓶颈、代码规范。
- **结构化报告**: 生成清晰的审查报告，支持一键应用建议。
- **PR 辅助**: 自动生成符合规范的 Pull Request 描述。

### 1.3 设计原则
- **非阻塞**: 审查在后台异步运行，不阻塞用户编辑。
- **上下文感知**: 结合项目规则 (`.agent/rules/`) 和项目技术栈进行审查。
- **可操作**: 报告中的每条建议都应附带具体的修改代码或命令。

---

## 2. 架构设计 (Architecture)

### 2.1 核心组件关系图

```
Git Repository
       │
       ├── git diff (staged / unstaged)
       ├── git log
       └── PR/MR Data (Optional)
           │
           ▼
  ┌─────────────────────┐
  │   ReviewAnalyzer    │  构建审查上下文 (Diff + 规则 + 技术栈)
  └─────────┬───────────┘
            │
            ▼
  ┌─────────────────────┐       ┌──────────────────┐
  │   ReviewEngine      │──────►│  LLM (Analysis)   │
  │   (审查引擎)         │◄──────┤                  │
  └─────────┬───────────┘       └──────────────────┘
            │
            ▼
  ┌─────────────────────┐       ┌──────────────────┐
  │  ReviewReportStore   │──────►│  Local JSON/Cache │
  │  (报告存储)          │       │                  │
  └─────────┬───────────┘       └──────────────────┘
            │
      ┌─────┴──────┐
      ▼            ▼
┌───────────┐  ┌────────────────┐
│ Review    │  │  ReviewStatusBar│
│ Tool      │  │  & Popover      │
└───────────┘  └────────────────┘
```

### 2.2 插件目录结构

```
LumiApp/Plugins/CodeReviewPlugin/
├── CodeReviewPlugin.swift                     # 插件入口
├── Services/
│   ├── ReviewAnalyzer.swift                   # Diff 分析与上下文构建
│   ├── ReviewEngine.swift                     # 审查核心逻辑 (LLM 调用)
│   └── ReviewReportStore.swift                # 报告存储与管理 (Actor)
├── Models/
│   ├── ReviewReport.swift                     # 审查报告结构
│   └── ReviewComment.swift                    # 单条审查意见
├── Tools/
│   ├── RunReviewTool.swift                    # 触发审查工具
│   └── ApplySuggestionTool.swift              # 应用建议工具
└── Views/
    ├── ReviewStatusBarView.swift              # 状态栏入口
    └── ReviewReportPopover.swift              # 报告详情面板
```

---

## 3. 详细设计 (Detailed Design)

### 3.1 数据模型

#### A. 审查报告 (`ReviewReport`)
```swift
struct ReviewReport: Identifiable, Codable {
    let id: UUID
    let commitHash: String?
    let diffStats: DiffStats                // +120, -45
    let overallScore: Double                // 0.0 ~ 10.0
    let summary: String                     // 整体评价
    let issues: [ReviewIssue]               // 发现的问题列表
    let suggestions: [ReviewSuggestion]     // 优化建议
    let createdAt: Date
}

struct ReviewIssue: Codable {
    let severity: Severity                  // .critical, .warning, .info
    let file: String
    let line: Int?
    let description: String
    let fixSuggestion: String?              // 建议的修复代码
}

enum Severity: String, Codable {
    case critical = "Critical"
    case warning = "Warning"
    case info = "Info"
}
```

### 3.2 审查维度

| 维度 | 检查内容 | 示例 |
|------|----------|------|
| **🐛 潜在 Bug** | 空指针、内存泄漏、未捕获异常、竞态条件 | `Optional unwrapping without nil check` |
| **🛡️ 安全** | 硬编码密钥、SQL 注入、XSS、不安全的 API 调用 | `API Key hardcoded in Config.swift` |
| **⚡ 性能** | 冗余计算、主线程阻塞、大量对象创建 | `Network call on MainThread` |
| **📐 规范** | 命名风格、代码组织、注释缺失、Swift 最佳实践 | `Use `guard` instead of nested `if` |
| **🧪 测试** | 缺少单元测试、测试覆盖率不足 | `Missing unit test for ViewModel` |

### 3.3 审查引擎 (`ReviewEngine`)

**工作流程**:
1. **获取 Diff**: 调用 `git diff` 或 `git diff --cached`。
2. **构建 Prompt**:
   ```markdown
   You are a senior code reviewer. Review the following Git Diff based on the project rules.
   
   ## Project Context
   - Language: Swift
   - Framework: SwiftUI
   - Rules: Follow Apple HIG, use MVVM pattern
   
   ## Diff Content
   ```diff
   + func fetchData() { ... }
   ```
   
   Provide a structured report including Critical Issues, Warnings, and Optimization Suggestions.
   ```
3. **LLM 分析**: 调用 Agent 进行异步分析。
4. **解析结果**: 将 LLM 响应解析为 `ReviewReport` 结构体。

### 3.4 工具设计

#### A. `run_review` (触发审查)
- **参数**:
  - `scope` (string): "staged" (暂存区), "unstaged" (工作区), "branch" (分支对比)
- **返回**: 结构化审查报告摘要。

#### B. `apply_suggestion` (应用建议)
- **参数**:
  - `suggestion_id` (string): 建议 ID
- **动作**: 自动修改文件内容，应用 LLM 提供的 Patch。

### 3.5 状态栏 UI (`ReviewStatusBarView`)

- **显示内容**:
  - **无变更**: 隐藏
  - **有变更**: `🔍 Review` (提示可审查)
  - **审查中**: `🔄 Reviewing...`
  - **审查完成**: `⚠️ 3 Issues` (红色/黄色指示器)
- **点击交互**: 弹出报告面板，按严重程度列出问题。

---

## 4. 交互流程 (Interaction Flow)

```
用户完成代码编写
    │
    ▼
状态栏显示 "🔍 Review" 提示
    │
    ▼
用户点击 / 输入 /review
    │
    ▼
ReviewAnalyzer 获取 Git Diff
    │
    ▼
ReviewEngine 调用 LLM 分析 (后台异步)
    │
    ▼
生成 ReviewReport
    │
    ▼
ReviewReportStore 保存报告
    │
    ▼
状态栏显示 "⚠️ 3 Issues"
    │
    ▼
用户点击状态栏 -> 查看报告 -> 点击 "Apply Fix"
    │
    ▼
apply_suggestion 工具执行 -> 代码自动修复 -> Git Diff 更新
```

---

## 5. 实施计划 (Implementation Plan)

### Phase 1: 核心服务
- [ ] 定义 `ReviewReport`, `ReviewIssue` 数据模型
- [ ] 实现 `ReviewAnalyzer`: Git Diff 获取与上下文构建
- [ ] 实现 `ReviewEngine`: LLM 调用与结果解析

### Phase 2: 工具与存储
- [ ] 实现 `RunReviewTool` / `ApplySuggestionTool`
- [ ] 实现 `ReviewReportStore` (JSON 持久化)

### Phase 3: UI 开发
- [ ] 实现 `ReviewStatusBarView`
- [ ] 实现 `ReviewReportPopover` (按严重性分级展示)
- [ ] 支持 "Apply Fix" 按钮交互

### Phase 4: 集成与优化
- [ ] 结合 `.agent/rules/` 进行定制化审查
- [ ] 支持 Commit 前自动审查 (可选 Hook)
- [ ] PR 描述生成能力

---

## 6. 技术决策

| 决策点 | 方案 | 理由 |
|--------|------|------|
| **Diff 获取** | `git diff` (Process 调用) | 简单可靠，无需引入第三方 Git 库 |
| **审查范围** | 仅当前未提交的变更 | 聚焦于用户正在工作的部分 |
| **存储** | JSON 缓存 | 轻量，易于清理 |
| **LLM 上下文** | Diff + Rules + Tech Stack | 确保审查建议符合项目规范 |

---

## 7. 风险与应对

| 风险 | 应对策略 |
|------|----------|
| **大文件 Diff 过大** | 限制单次审查文件大小 (如 500 行)，超出则分块审查或提示 |
| **误报率高** | 引入置信度评分，低置信度建议仅作为 Info 级别展示 |
| **隐私问题** | Diff 内容仅在本地处理，不上传外部服务 (除非用户配置) |

---

此 Roadmap 定义了 **CodeReview Plugin** 的实现路径，使 Lumi 具备专业代码审查能力，成为用户的“AI 架构师”。