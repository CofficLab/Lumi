# Skill Plugin Roadmap

## 1. 概述 (Overview)

### 1.1 背景
Lumi 目前拥有强大的插件系统和 Agent 引擎，但缺乏一种轻量级、基于文件系统的领域知识扩展机制。现有的 **Plugin (插件)** 侧重于通过 Swift 代码扩展功能（如 Docker、数据库管理），而 **Skill (技能)** 旨在通过 Markdown 指令和配置提供**领域工作流和最佳实践**，无需编译即可热加载。

### 1.2 目标
- **零内核修改**: Skill 体系完全通过 `SkillPlugin` 插件实现，利用现有的 `SendMiddleware` 协议和 `StatusBar` 扩展点，不侵入 Lumi Core。
- **文件系统驱动**: 自动扫描 `.agent/skills/` 目录，解析 `metadata.json` 和 `SKILL.md`。
- **动态注入**: 通过中间件将 Skill 摘要注入 System Prompt，让 LLM 感知并使用。
- **可视化反馈**: 在状态栏显示当前项目可用的 Skill 数量和列表。

---

## 2. 架构设计 (Architecture)

### 2.1 核心组件关系图

```
.agent/skills/ 目录
       │
       ├── metadata.json ─┐
       ├── SKILL.md ──────┤
                          ▼
              ┌─────────────────────┐
              │   SkillScanner      │  扫描文件系统，解析元数据
              └─────────┬───────────┘
                        │
                        ▼
              ┌─────────────────────┐
              │   SkillService      │  业务逻辑层 (Actor)
              │   (管理 Skill 列表)  │
              └───┬───────────┬─────┘
                  │           │
         ┌────────┘           └────────┐
         ▼                             ▼
┌────────────────────┐      ┌─────────────────────┐
│ SkillSendMiddleware│      │  SkillStatusBarView │
│ (中间件注入 Prompt) │      │  (状态栏 UI 入口)   │
└─────────┬──────────┘      └──────────┬──────────┘
          │                             │
          ▼                             ▼
   SendPipeline              SkillListPopover
          │                  (Skill 列表面板)
          ▼
    LLM Request
    (增强后的 Prompt)
```

### 2.2 插件目录结构

```
LumiApp/Plugins/SkillPlugin/
├── SkillPlugin.swift                  # 插件入口，注册中间件和状态栏
├── Services/
│   └── SkillService.swift             # 扫描 + 加载逻辑 (Actor)
├── Models/
│   └── SkillMetadata.swift            # 数据模型定义
├── Middleware/
│   └── SkillSendMiddleware.swift      # 核心中间件：Prompt 注入
└── Views/
    ├── SkillStatusBarView.swift       # 状态栏组件
    └── SkillListPopover.swift         # 点击弹出的详情面板
```

---

## 3. 详细设计 (Detailed Design)

### 3.1 数据模型 (`SkillMetadata`)

```swift
struct SkillMetadata: Identifiable, Equatable, Codable {
    let id = UUID()

    // --- 来自 metadata.json ---
    let name: String              // 唯一标识，如 "swiftui-expert"
    let title: String             // 显示标题，如 "SwiftUI Expert"
    let description: String       // 一句话描述
    let triggers: [String]        // 触发关键词 (预留，用于后续智能匹配)
    let version: String           // 版本号

    // --- 来自文件系统 ---
    var contentPath: URL          // SKILL.md 的路径

    /// 加载完整 Skill 内容
    func loadContent() throws -> String {
        try String(contentsOf: contentPath, encoding: .utf8)
    }
}
```

### 3.2 目录规范 (`.agent/skills/`)

每个 Skill 是一个独立的文件夹：

```
.agent/skills/
├── swiftui-expert/
│   ├── metadata.json     # { "name": "swiftui-expert", "title": "...", ... }
│   └── SKILL.md          # 核心指令集
├── git-workflow/
│   ├── metadata.json
│   └── SKILL.md
└── ...
```

**metadata.json 格式示例:**

```json
{
    "name": "swiftui-expert",
    "title": "SwiftUI Expert",
    "description": "Apple HIG compliant SwiftUI code generation with modern patterns",
    "triggers": ["swift", "swiftui", "xcode", "view"],
    "version": "1.0.0"
}
```

### 3.3 中间件设计 (`SkillSendMiddleware`)

- **职责**: 在 LLM 请求前，扫描当前项目的 `.agent/skills/`，将可用 Skill 的摘要注入 `ctx.transientSystemPrompts`。
- **Order**: `50`（位于 `AgentRules(0)` 之后，`RAG(100)` 之前）。
- **注入内容格式**:

```markdown
## Available Skills
You have access to the following specialized skills.
If the user's request matches a skill, mention it in your response and follow its instructions.

| Skill | Description |
|-------|-------------|
| `swiftui-expert` | Apple HIG compliant SwiftUI code generation... |
| `git-workflow` | Strict git commit conventions and branch management |

When using a skill, start your response with: `[Skill: <skill-name>]` to indicate activation.
```

**核心逻辑伪代码:**

```swift
final class SkillSendMiddleware: SendMiddleware, SuperLog {
    let id = "skill-context"
    let order = 50

    func handle(ctx: SendMessageContext, next: SendPipelineNext) async {
        let projectPath = ctx.projectVM.currentProjectPath

        // 未选择项目时跳过
        guard !projectPath.isEmpty else {
            await next(ctx); return
        }

        // 扫描并获取可用 Skill 列表
        let skills = try await SkillService.shared.listSkills(projectPath: projectPath)

        // 无 Skill 时跳过
        guard !skills.isEmpty else {
            await next(ctx); return
        }

        // 构建 Prompt 并注入
        let prompt = buildSkillPrompt(skills: skills)
        ctx.transientSystemPrompts.append(prompt)

        await next(ctx)
    }
}
```

### 3.4 状态栏 UI 设计

#### A. 入口 (`SkillStatusBarView`)
- **位置**: 底部状态栏右侧。
- **显示内容**: `✨ N skills`。当 `N == 0` 时自动隐藏。
- **交互**: 点击弹出 `SkillListPopover`。
- **刷新时机**:
  - 视图首次出现 (`onAppear`)
  - 项目路径变化 (`onChange`)
  - 从其他应用切回 (`applicationDidBecomeActive`)

#### B. 面板 (`SkillListPopover`)
- **布局**: 列表展示所有可用 Skill。
- **信息**: 图标、Title、Description、Version。
- **底部提示**: `Skills are loaded from .agent/skills/`

**效果示意:**

```
状态栏 (从左到右):
[🌿 main]  [✨ 3 skills]  [📊 Quota]  [⚡ Fast Mode]

点击后弹出:
┌─────────────────────────────────────────┐
│ ✨ Available Skills              [3]    │
├─────────────────────────────────────────┤
│ ✨ SwiftUI Expert              v1.0.0   │
│    Apple HIG compliant SwiftUI code...  │
├─────────────────────────────────────────┤
│ ✨ Git Workflow                 v2.1.0  │
│    Strict git commit conventions...     │
├─────────────────────────────────────────┤
│ ✨ Code Review                  v1.2.0  │
│    Automated PR review guidelines...    │
├─────────────────────────────────────────┤
│ Skills are loaded from .agent/skills/   │
└─────────────────────────────────────────┘
```

---

## 4. 交互流程 (Interaction Flow)

### 4.1 完整时序

```
用户打开项目
    │
    ▼
SkillStatusBarView 出现
    │
    ├── 扫描 .agent/skills/
    │   ├── 读取 metadata.json
    │   └── 验证 SKILL.md 存在
    │
    └── 状态栏显示 "✨ 3 skills"

用户发送: "帮我写个 SwiftUI 登录页"
    │
    ▼
SendPipeline 执行中间件链
    │
    ├── Order 0:  AgentRulesMiddleware (注入规则摘要)
    ├── Order 50: SkillSendMiddleware (拦截)
    │   │
    │   ├── 扫描 .agent/skills/ → 找到 swiftui-expert
    │   │
    │   └── 注入 Prompt:
    │       """
    │       ## Available Skills
    │       | swiftui-expert | Apple HIG compliant SwiftUI... |
    │       When using a skill, start with: [Skill: <name>]
    │       """
    │
    └── Order 100: RAGMiddleware (文档检索)
    │
    ▼
LLM 收到增强后的消息
    │
    ▼
LLM 识别到匹配，回复:
    "[Skill: swiftui-expert] 正在使用 SwiftUI Expert 技能..."
    + 遵循 SKILL.md 中的规范生成代码
```

---

## 5. 实施计划 (Implementation Plan)

### Phase 1: 核心服务与模型
- [ ] 定义 `SkillMetadata` 结构体 (`Models/SkillMetadata.swift`)
- [ ] 实现 `SkillService` Actor (`Services/SkillService.swift`):
  - 扫描指定目录
  - 解析 `metadata.json`
  - 验证 `SKILL.md` 存在
  - 返回排序后的 Skill 列表

### Phase 2: 中间件集成
- [ ] 实现 `SkillSendMiddleware` (`Middleware/SkillSendMiddleware.swift`)
- [ ] 在 `SkillPlugin` 中注册中间件
- [ ] 测试 Prompt 注入效果 (Verbose 日志验证)

### Phase 3: UI 与状态栏
- [ ] 实现 `SkillStatusBarView` (`Views/SkillStatusBarView.swift`)
- [ ] 实现 `SkillListPopover` (`Views/SkillListPopover.swift`)
- [ ] 绑定 `SkillService` 数据源
- [ ] 完善刷新逻辑 (项目切换、应用激活)

### Phase 4: 测试与优化
- [ ] 测试空目录、格式错误、缺少文件的容错处理
- [ ] 性能测试: 扫描耗时是否在可接受范围内 (< 10ms)
- [ ] 编写示例 Skill (`swiftui-expert`) 验证全流程
- [ ] 验证中间件 Order 正确性 (确保在 Rules 之后、RAG 之前)

---

## 6. 技术决策 (Technical Decisions)

| 决策点 | 方案 | 理由 |
|-------|------|------|
| **目录位置** | `.agent/skills/` | 与 `.agent/rules/` 保持一致的项目级约定 |
| **中间件 Order** | 50 | 在 Rules(0) 之后，RAG(100) 之前，确保规则优先、技能次之、检索最后 |
| **注入内容** | 仅摘要 (元数据) | 控制 Token 消耗，完整内容按需由 LLM 自主推理使用 |
| **激活方式** | 自然语言匹配 | LLM 看到摘要后自主决定是否使用，无需显式工具调用 |
| **错误处理** | 静默跳过 | 目录不存在或解析失败不阻塞发送流程 |
| **状态栏显示** | 数量为 0 时隐藏 | 保持界面整洁，无 Skill 时不占空间 |
| **并发模型** | Actor (SkillService) | 保证线程安全，适配 Swift 并发 |

---

## 7. 风险与考量 (Risks & Considerations)

### 7.1 Token 消耗
- **风险**: 如果 Skill 数量过多 (如 20+)，摘要表格也会变长，占用上下文窗口。
- **对策**:
  - 设置最大显示数量限制 (如 Top 10)。
  - 后续可引入关键词过滤，仅注入与当前对话相关的 Skill。

### 7.2 热重载
- **风险**: 用户在对话过程中修改了 `SKILL.md`，当前会话可能不会立即生效。
- **对策**: 每次 `handle` 都重新扫描文件系统 (性能开销极小)，或监听文件系统变化更新缓存。

### 7.3 权限与安全
- **风险**: 恶意 Skill 通过 Prompt Injection 攻击 LLM。
- **对策**:
  - Skill 仅作为 Context 注入，不自动执行脚本。
  - 如需执行外部脚本，需结合 Lumi 现有的 `PermissionService` 进行权限确认。

### 7.4 多 Skill 冲突
- **风险**: 多个 Skill 可能描述相似功能，导致 LLM 选择困惑。
- **对策**:
  - 在 `metadata.json` 中引入 `priority` 字段。
  - 注入时按优先级排序，引导 LLM 优先选择高优 Skill。

---

## 8. 与现有系统的对比

### 8.1 Skill vs Plugin vs Rule

| 特性 | Plugin (插件) | Rule (规则) | Skill (技能) |
|------|--------------|-------------|-------------|
| **形态** | Swift 代码，需编译 | Markdown 文件 | Markdown + JSON |
| **定位** | 扩展能力 (Code) | 全局约束 (Constraint) | 领域工作流 (Workflow) |
| **加载方式** | 启动时加载 | 按需读取 | 自动扫描，摘要注入 |
| **修改后** | 需重新编译 App | 立即生效 | 下次请求生效 |
| **示例** | Docker 管理、数据库连接 | 必须使用中文、禁止删除文件 | SwiftUI 规范、Git 工作流 |

### 8.2 中间件 Order 对照表

| 中间件 | Order | 职责 |
|-------|-------|------|
| `AgentRulesContextSendMiddleware` | 0 | 注入项目规则摘要 |
| **`SkillSendMiddleware`** | **50** | **注入可用 Skill 摘要** |
| `RAGSendMiddleware` | 100 | 检索项目文档 |
| `ToolCallLoopDetectionSendMiddleware` | 150 | 检测工具调用死循环 |

---

此 Roadmap 定义了 **SkillPlugin** 的完整实现路径。方案完全基于 Lumi 现有的扩展点 (SendMiddleware + StatusBar)，确保低耦合、高可用性，无需任何内核代码修改。
