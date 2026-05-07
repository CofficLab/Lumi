# ErrorDoctor Plugin Roadmap

## 1. 概述 (Overview)

### 1.1 背景
开发者在日常工作中花费大量时间进行 Debug：阅读错误日志、定位问题根因、搜索解决方案。传统的错误处理往往停留在"报错 -> 用户手动搜索 -> 尝试修复"的低效循环。Claude Code 的源码显示，其核心引擎包含**自我修正 (Self-Correction)** 机制——当工具执行或构建失败时，模型会自动分析错误并尝试修复。

### 1.2 目标
- **错误捕获**: 自动监听构建失败、Test 失败、运行时 Crash 和 Compiler Errors。
- **智能诊断**: Agent 分析错误日志，结合代码上下文，给出根因分析。
- **自动修复**: 生成修复方案（Patch 代码），用户一键应用。
- **知识库沉淀**: 记录常见错误及解法，形成项目级错误知识库。

### 1.3 设计原则
- **主动感知**: 不是等待用户报错，而是通过中间件和工具回调主动感知错误。
- **精准定位**: 利用 IDE 提供的 AST 信息和文件行号，精确定位问题代码。
- **安全修复**: 所有自动修复操作都需用户确认（Preview Diff），避免误改。

---

## 2. 架构设计 (Architecture)

### 2.1 核心组件关系图

```
Terminal Output / Build System / Test Runner
       │
       ├── Error Logs (Regex 提取)
       ├── Stack Traces
       └── Compiler Warnings
           │
           ▼
  ┌─────────────────────┐
  │  ErrorListener      │  监听错误输出，提取结构化信息
  └─────────┬───────────┘
            │
            ▼
  ┌─────────────────────┐       ┌──────────────────┐
  │  ErrorAnalyzer      │──────►│  LLM (Diagnosis) │
  │  (诊断引擎)          │◄──────┤                  │
  └─────────┬───────────┘       └──────────────────┘
            │
            ▼
  ┌─────────────────────┐       ┌──────────────────┐
  │  FixGenerator       │──────►│  Patch / Code Fix │
  │  (修复生成器)        │       │                  │
  └─────────┬───────────┘       └──────────────────┘
            │
      ┌─────┴──────┐
      ▼            ▼
┌───────────┐  ┌────────────────┐
│ Fix Tool  │  │ ErrorStatusBar │
│ (Apply)   │  │ & Popover      │
└───────────┘  └────────────────┘
```

### 2.2 插件目录结构

```
LumiApp/Plugins/ErrorDoctorPlugin/
├── ErrorDoctorPlugin.swift                     # 插件入口
├── Services/
│   ├── ErrorListener.swift                     # 错误输出监听与解析
│   ├── ErrorAnalyzer.swift                     # 诊断引擎 (LLM 调用)
│   ├── FixGenerator.swift                      # 修复代码生成
│   └── ErrorKnowledgeBase.swift                # 错误知识库 (Actor)
├── Models/
│   ├── ErrorReport.swift                       # 错误报告结构
│   └── FixSuggestion.swift                     # 修复建议结构
├── Middleware/
│   └── ErrorContextMiddleware.swift            # 错误上下文注入中间件 (Order: 40)
├── Tools/
│   ├── DiagnoseTool.swift                      # 手动触发诊断工具
│   └── ApplyFixTool.swift                      # 应用修复工具
└── Views/
    ├── ErrorStatusBarView.swift                # 状态栏入口
    └── ErrorReportPopover.swift                # 错误报告面板
```

---

## 3. 详细设计 (Detailed Design)

### 3.1 数据模型

#### A. 错误报告 (`ErrorReport`)
```swift
struct ErrorReport: Identifiable, Codable {
    let id: UUID
    let type: ErrorType                   // .build, .test, .runtime, .compiler
    let severity: Severity                // .error, .warning
    let message: String                   // 原始错误信息
    let file: String?                     // 出错文件
    let line: Int?                        // 出错行号
    let stackTrace: [String]?             // 堆栈跟踪
    let rootCause: String?                // 根因分析 (由 LLM 生成)
    let suggestedFix: FixSuggestion?      // 修复建议
    let isResolved: Bool                  // 是否已解决
}

enum ErrorType: String, Codable {
    case build       // 构建错误 (xcodebuild, swift build)
    case test        // 单元测试失败
    case runtime     // 运行时崩溃
    case compiler    // 编译器错误
}
```

#### B. 修复建议 (`FixSuggestion`)
```swift
struct FixSuggestion: Codable {
    let description: String               // 修复说明
    let patches: [CodePatch]              // 具体的代码修改
    let commands: [String]?               // 需要运行的命令 (如 `pod install`)
}

struct CodePatch: Codable {
    let filePath: String
    let oldCode: String
    let newCode: String
}
```

### 3.2 错误监听器 (`ErrorListener`)

**监听来源**:
1. **Shell Tool 回调**: 当 Agent 调用 `run_shell` 工具时，捕获 stdout/stderr。
2. **Regex 匹配**: 针对常见编译器/构建工具的 Error Pattern 进行提取。

**正则匹配示例**:
```swift
// Swift Compiler Error
let patterns = [
    #"error: (.+):(\d+):\d+: (.+)"#,      // 文件名:行号: 错误信息
    #"fatal error: (.+):(\d+):\d+: (.+)"#,
    #"xcodebuild: error: (.+)"#
]
```

### 3.3 诊断引擎 (`ErrorAnalyzer`)

**工作流程**:
1. **提取错误**: ErrorListener 捕获并解析错误日志。
2. **关联代码**: 读取错误文件上下文的 10-20 行代码。
3. **构建 Prompt**:
   ```markdown
   You are an expert debugger. Analyze the following error.
   
   ## Error Message
   error: MyProject/View.swift:42:10: Cannot find 'user' in scope
   
   ## Code Context
   Line 40: var name: String
   Line 41: 
   Line 42: Text(user.name)  // <-- Error here
   Line 43: 
   
   ## Task
   1. Identify the root cause.
   2. Provide a fix.
   ```
4. **LLM 分析**: 异步调用，返回结构化诊断结果。
5. **存储**: 存入 `ErrorKnowledgeBase`，供后续查询和复用。

### 3.4 中间件 (`ErrorContextMiddleware`)

- **Order**: `40` (位于 Skill(50) 之前，确保错误上下文优先处理)。
- **逻辑**:
  - 如果上一轮 Agent 对话中触发了错误 (通过工具结果检测到)，则在下一轮自动注入错误分析摘要。
  - 这样 Agent 在生成回复时，已经知道"上一次操作失败了"，会自动尝试修正。
  
  **注入 Prompt**:
  ```markdown
  ## Previous Action Error
  The previous command failed with the following error:
  Error: Cannot find 'user' in scope (View.swift:42)
  
  Please analyze the error and correct the code before proceeding.
  ```

### 3.5 工具设计

#### A. `diagnose_error` (手动诊断)
- **触发**: 用户点击状态栏或通过命令触发。
- **动作**: 读取最近一次构建/测试日志，进行诊断。
- **返回**: `ErrorReport` 列表。

#### B. `apply_fix` (应用修复)
- **参数**: `error_id` (错误 ID)
- **动作**: 应用 LLM 生成的 CodePatch，弹出 Diff 预览供确认。

### 3.6 状态栏 UI (`ErrorStatusBarView`)

- **显示内容**:
  - **无错误**: 隐藏
  - **有错误**: `⚠️ 2 Errors` (红色)
  - **诊断中**: `🔍 Analyzing...`
  - **已修复**: `✅ Fixed` (绿色，持续 3 秒后消失)
- **点击交互**: 弹出报告面板，展示错误详情和"🔧 Apply Fix"按钮。

---

## 4. 交互流程 (Interaction Flow)

### 4.1 自动诊断流程

```
Agent 执行 Shell 命令 (如 swift build)
    │
    ▼
命令失败，输出错误日志
    │
    ▼
ErrorListener 捕获 stderr
    │
    ▼
解析出 "View.swift:42:10: Cannot find 'user' in scope"
    │
    ▼
ErrorAnalyzer 读取 View.swift 上下文 -> 调用 LLM 诊断
    │
    ▼
生成 ErrorReport:
  - Root Cause: Missing @StateObject var user
  - Fix: Add @StateObject var user = UserViewModel()
    │
    ▼
状态栏显示 "⚠️ 1 Error Found"
    │
    ▼
用户点击 -> 查看报告 -> 点击 "Apply Fix"
    │
    ▼
代码自动修改 -> 自动重新构建 -> 验证是否修复
```

### 4.2 自我修正循环

```
Agent 收到 ErrorReport 中间件注入
    │
    ▼
Agent 回复: "我看到了错误，让我修复它..."
    │
    ▼
Agent 生成修正代码 -> 写入文件 -> 重新运行测试
    │
    ▼
(循环直到通过或达到最大重试次数)
```

---

## 5. 实施计划 (Implementation Plan)

### Phase 1: 错误监听与解析
- [ ] 定义 `ErrorReport` 数据模型
- [ ] 实现 `ErrorListener`: Shell 输出捕获与 Regex 提取
- [ ] 支持 Swift Compiler / xcodebuild 错误格式

### Phase 2: 诊断与分析
- [ ] 实现 `ErrorAnalyzer`: LLM 诊断 Prompt 构建与结果解析
- [ ] 实现 `FixGenerator`: 生成 CodePatch
- [ ] 错误知识库 (JSON 存储)

### Phase 3: 工具与中间件
- [ ] 实现 `DiagnoseTool` / `ApplyFixTool`
- [ ] 实现 `ErrorContextMiddleware` (Order: 40)
- [ ] 验证自动修正循环

### Phase 4: UI 开发
- [ ] 实现 `ErrorStatusBarView`
- [ ] 实现 `ErrorReportPopover`
- [ ] Diff 预览与确认交互

### Phase 5: 优化与扩展
- [ ] 支持更多语言/编译器 (JS/Python/Go)
- [ ] 测试失败自动重试机制
- [ ] 错误知识库搜索与推荐

---

## 6. 技术决策

| 决策点 | 方案 | 理由 |
|--------|------|------|
| **错误提取** | Regex Pattern + Context | 轻量、快速、无需依赖复杂 AST |
| **LLM 上下文** | Error Line ± 20 行 | 平衡信息量与 Token 消耗 |
| **修复应用** | Patch Diff + 用户确认 | 安全优先，防止误改 |
| **存储** | JSON (项目级 `.agent/errors.json`) | 易于追踪和清理 |

---

## 7. 与现有系统的联动

| 系统 | 联动方式 |
|------|----------|
| **AutoTask Plugin** | 错误修复作为独立子任务，完成后自动更新任务状态 |
| **CodeReview Plugin** | 审查发现的 Issue 可转化为 ErrorDoctor 的待修复项 |
| **TerminalPlugin** | 复用终端输出流，减少重复监听逻辑 |
| **GitHubInsight Plugin** | 疑难错误可搜索 GitHub Issues 查找相似案例 |

---

## 8. 风险与应对

| 风险 | 应对策略 |
|------|----------|
| **误报 / 误修复** | 所有修复需 Diff 预览 + 用户确认 |
| **日志过大** | 限制日志捕获大小，仅保留相关错误上下文 |
| **LLM 幻觉修复** | 修复后自动运行构建/测试验证，若仍失败则重试或标记失败 |
| **多语言支持** | 初期聚焦 Swift/Xcode，后续通过插件扩展其他语言 Parser |

---

此 Roadmap 定义了 **ErrorDoctor Plugin** 的实现路径，让 Lumi 不仅能写代码，还能像资深工程师一样诊断问题、自动修复，大幅缩短 Debug 周期。