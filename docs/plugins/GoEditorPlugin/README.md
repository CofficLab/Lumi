# GoEditorPlugin 实施方案

> 本方案定义 Lumi 编辑器对 Go (Golang) 语言完整支持的实现路径、模块划分、与现有内核/插件的对接点，以及分阶段验收标准。

---

## 一、目标

使 Lumi 编辑器对 Go 项目提供 **接近 VS Code + Go 扩展** 的开发体验，覆盖以下维度：

| 维度 | 能力 | 优先级 |
|------|------|--------|
| **语言智能** | Cmd+Click 跳转到定义/声明/类型定义/实现 | P0 |
| **语言智能** | 自动补全 (Completion) | P0 |
| **语言智能** | 悬停提示 (Hover，显示类型签名/文档) | P0 |
| **语言智能** | 实时诊断 (Diagnostics，编译错误/警告) | P0 |
| **语言智能** | 代码动作 (Code Action，快速修复/重构) | P1 |
| **语言智能** | 文档高亮 (Document Highlight，符号引用高亮) | P1 |
| **语言智能** | 符号重命名 (Rename Symbol) | P1 |
| **语言智能** | 查找引用 (Find References) | P1 |
| **语言智能** | 折叠范围 (Folding Range) | P2 |
| **语言智能** | 调用层级 (Call Hierarchy) | P2 |
| **语言智能** | Inlay Hints (类型推断提示) | P2 |
| **语言智能** | 语义标记 (Semantic Tokens) | P2 |
| **语言智能** | 工作区符号 (Workspace Symbols) | P2 |
| **工程能力** | `go build` 构建 + 输出面板 | P0 |
| **工程能力** | `go test` 测试 + 结果展示 | P1 |
| **工程能力** | `go mod tidy` / `go mod download` | P1 |
| **工程能力** | `go fmt` / `gofumpt` 格式化 | P1 |
| **工程能力** | 构建/测试状态栏指示 | P2 |
| **调试能力** | Delve 调试器集成 (DAP) | P3 |

---

## 二、目录结构

遵循 `plugin-directory-rules` 规范，在 `LumiApp/Plugins-Editor/GoEditorPlugin/` 下组织：

```
GoEditorPlugin/
├── GoEditorPlugin.swift              # 插件入口（遵循 EditorFeaturePlugin）
├── GoEditorPlugin.xcstrings          # 本地化字符串
├── README.md                         # 本实施方案文档
│
├── LSP/                              # LSP 相关配置与管线
│   ├── GoLSPConfig.swift             # gopls 启动参数、环境、workspace 配置
│   ├── GoCompletionPipeline.swift    # (可选) Go 补全策略定制
│   └── GoInlayHintPipeline.swift     # (可选) Go Inlay Hints 管线
│
├── Commands/                         # Go 工程命令
│   ├── GoBuildCommand.swift          # go build
│   ├── GoTestCommand.swift           # go test
│   ├── GoModCommand.swift            # go mod tidy / download
│   └── GoFmtCommand.swift            # go fmt / gofumpt
│
├── Build/                            # 构建系统
│   ├── GoBuildManager.swift          # 构建执行器（Process 封装）
│   ├── GoBuildOutputParser.swift     # 构建输出解析（error/warning 提取）
│   └── GoBuildOutputView.swift       # 构建输出面板视图
│
├── Test/                             # 测试系统
│   ├── GoTestManager.swift           # 测试执行器
│   ├── GoTestOutputParser.swift      # 测试输出解析（-json 模式）
│   └── GoTestResultView.swift        # 测试结果展示
│
├── Debug/                            # 调试系统（P3 阶段）
│   ├── DelveAdapter.swift            # Delve DAP 适配
│   └── DebugSessionManager.swift     # 调试会话管理
│
├── Grammar/                          # Tree-Sitter 语法
│   └── GoTreeSitterRegistration.swift # tree-sitter-go grammar 注册
│
├── Models/                           # 数据模型
│   ├── GoModuleInfo.swift            # go.mod 解析结果
│   ├── GoPackageInfo.swift           # 包信息
│   ├── GoBuildIssue.swift            # 构建问题（error/warning）
│   └── GoTestResult.swift            # 测试结果模型
│
├── Services/                         # 业务服务
│   ├── GoProjectDetector.swift       # Go 项目检测（go.mod 定位）
│   ├── GoEnvResolver.swift           # go env 解析（GOPATH/GOROOT/GOMODCACHE）
│   └── GoWorkspaceConfig.swift       # 工作区配置管理
│
├── ViewModels/                       # 视图模型
│   ├── GoBuildViewModel.swift        # 构建面板 ViewModel
│   └── GoTestViewModel.swift         # 测试面板 ViewModel
│
└── Views/                            # SwiftUI 视图
    ├── GoBuildPanelView.swift        # 构建面板
    ├── GoTestPanelView.swift         # 测试面板
    └── GoStatusBarIndicator.swift    # 状态栏构建/测试指示器
```

---

## 三、核心模块实施详情

### 3.1 LSP 集成（`GoEditorPlugin/LSP/`）

#### 3.1.1 `GoLSPConfig.swift`

**职责**：管理 `gopls` 的启动参数、环境变量、workspace 配置。

**需要处理的关键点**：

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| `gopls` 可执行路径 | 通过 `which gopls` 或 `go env GOPATH` 推导 | `/usr/local/bin/gopls` |
| 启动参数 | `-remote=auto`、`-logfile` 等 | `["serve"]` |
| 环境变量 | `GOPATH`、`GOROOT`、`GOFLAGS`、`PATH` | 从 `go env` 读取 |
| 工作区配置 | `gopls` 的 `initializationOptions` | 见下表 |

**gopls 常用配置项**：

```yaml
# gopls 的 workspace 配置（JSON-RPC initializationOptions）
{
  "completeUnimported": true,          # 补全未导入的包
  "usePlaceholders": true,             # 补全时使用占位符
  "matcher": "fuzzy",                  # 模糊匹配
  "deepCompletion": true,              # 深度补全
  "staticcheck": true,                 # 启用 staticcheck 诊断
  "vulncheck": "imports",             # 漏洞检查
  "codelenses": {
    "generate": true,                  # 显示 go generate 代码透镜
    "gc_details": true,               # 显示 GC 细节
    "test": true,                      # 显示运行测试代码透镜
    "tidy": true,                      # 显示 go mod tidy 代码透镜
    "upgrade_dependency": true         # 显示升级依赖代码透镜
  },
  "analyses": {
    "nilness": true,                   # nil 分析
    "unusedparams": true,              # 未使用参数分析
    "shadow": true,                    # 变量遮蔽分析
    "unusedwrite": true                # 未使用写入分析
  }
}
```

**与现有内核的对接**：

- **对接点 1**：`LSPConfig.swift` 中已有 `case "go": return findCommand("gopls")`。Go 插件不需要修改这个 `switch`，而是通过 `LSPConfig.defaultConfig(for:)` 自动获取路径，再注入自定义参数。
- **对接点 2**：`LSPService.swift` 负责启动 LSP Server。Go 插件需要在 `.go` 文件打开时，确保 `LSPService` 使用 Go 的特定配置初始化。
- **对接点 3**：`Kernel/LSPRequestPipeline.swift` 提供 `LSPRequestLifecycle`。所有 Go 专属的 LSP 请求必须走这个管线，确保请求代际控制和过期响应丢弃。

#### 3.1.2 `GoCompletionPipeline.swift`

**职责**：为 Go 语言定制补全策略。

**核心逻辑**：

1. 拦截 `EditorCompletionContext`，当 `languageId == "go"` 时激活
2. 调用 `LSPService.requestCompletion()` 获取候选
3. 按以下规则排序：
   - 标准库优先级 > 第三方包 > 本地包
   - 已导入包 > 未导入包
   - 前缀匹配 > 模糊匹配
4. 返回 `EditorCompletionSuggestion` 列表

#### 3.1.3 `GoInlayHintPipeline.swift`

**职责**：为 Go 语言提供 Inlay Hints（类型推断提示）。

**需要展示的 Hints 类型**：

| Hint 类型 | 示例 | 显示内容 |
|-----------|------|---------|
| 变量类型 | `var x := getValue()` | `x: int` → `var x int := getValue()` |
| 参数名称 | `http.Get(url)` | `http.Get(url: "https://...")` |
| 闭包参数 | `sort.Slice(s, func(i, j int) bool {` | `func(i int, j int) bool {` |

---

### 3.2 工程命令（`GoEditorPlugin/Commands/`）

#### 3.2.1 `GoBuildCommand.swift`

**职责**：执行 `go build` 并展示结果。

**执行流程**：

```
用户触发 (⌘B 或工具栏按钮)
    ↓
1. GoProjectDetector 定位 go.mod 所在项目根目录
    ↓
2. 构建命令组装
   go build -v ./...
    ↓
3. GoBuildManager 启动 Process
    ↓
4. 实时流式输出到 GoBuildOutputView
    ↓
5. GoBuildOutputParser 解析 error/warning
    ↓
6. 状态更新：成功/失败 + 问题数量
    ↓
7. 若有 error，在编辑器中标记（与 Problems Panel 联动）
```

**需要处理的场景**：

| 场景 | 处理方式 |
|------|---------|
| 单文件打开 | 自动推导所属包，执行 `go build .` |
| 多模块工作区 | 提供模块选择器 |
| 跨平台编译 | 支持 `GOOS=xxx GOARCH=xxx go build` |
| 构建缓存 | 利用 `go build` 原生缓存，无需额外处理 |
| 取消构建 | `Process.terminate()` + 输出 "Build cancelled" |

**与内核的对接**：

- **对接点**：`Kernel/CommandRegistry.swift`。命令注册为 `go.build`，启用条件为 `whenPresent(.currentFileURL)`。
- **快捷键**：`⌘B`（与 `builtin.build` 冲突时，优先使用 Go 专属命令）
- **输出面板**：复用 `EditorPanelCommandController` 或新增独立 Build Panel

#### 3.2.2 `GoTestCommand.swift`

**职责**：执行 `go test` 并展示结果。

**测试执行模式**：

| 模式 | 命令 | 触发场景 |
|------|------|---------|
| 当前文件测试 | `go test -v -run TestName ./...` | 光标在测试函数内 |
| 当前包测试 | `go test -v ./...` | 无选中测试函数 |
| 全部测试 | `go test -v ./...` | 工具栏/命令面板 |
| 覆盖度测试 | `go test -cover ./...` | 可选 |
| 基准测试 | `go test -bench=. ./...` | 可选 |

**结果解析**：

使用 `go test -json` 输出结构化结果：

```json
{
  "Action": "pass",
  "Package": "github.com/user/project/pkg",
  "Test": "TestMyFunction",
  "Elapsed": 0.123
}
```

**与编辑器的联动**：

- 测试通过/失败在代码行号旁显示绿/红图标（类似 VS Code 的 Test Explorer）
- 点击失败测试可直接跳转到对应代码行
- 支持在 gutter 中显示 "Run Test | Debug Test" 代码透镜

#### 3.2.3 `GoModCommand.swift`

**职责**：管理 Go Modules。

**支持的命令**：

| 命令 | 说明 |
|------|------|
| `go mod tidy` | 清理未使用的依赖，添加缺失的依赖 |
| `go mod download` | 下载所有依赖 |
| `go mod vendor` | 创建 vendor 目录 |
| `go get <package>` | 添加/更新依赖 |

**交互设计**：

- 在状态栏显示 `go.mod` 状态（需要同步/已是最新）
- 提供快速操作按钮（Tidy / Download / Upgrade）
- `go mod tidy` 输出结果展示在 Output Panel

#### 3.2.4 `GoFmtCommand.swift`

**职责**：格式化 Go 代码。

**策略**：

| 工具 | 优先级 | 说明 |
|------|--------|------|
| `gofumpt` | 高（如已安装） | 更严格的格式化器 |
| `go fmt` | 中 | 官方标准格式化 |
| LSP format | 低 | `gopls` 的 `textDocument/formatting` |

**自动化**：

- 保存时自动格式化（Format on Save）
- 可通过设置开关控制

---

### 3.3 构建系统（`GoEditorPlugin/Build/`）

#### 3.3.1 `GoBuildManager.swift`

**职责**：封装 `go build` 的 Process 调用。

**核心能力**：

- 支持增量构建（`go build` 原生支持）
- 支持交叉编译（`GOOS`/`GOARCH` 环境变量）
- 支持并发构建控制（同一时间只允许一个构建）
- 支持构建历史缓存（最近 10 次构建结果）

**关键设计**：

```
GoBuildManager (actor)
├── state: BuildState (idle/building/success/failed)
├── currentProcess: Process?
├── outputLog: [BuildLogEntry]
├── lastBuildDuration: TimeInterval
└── methods:
    ├── startBuild(config: GoBuildConfig) async -> BuildResult
    ├── cancelBuild() async
    ├── getBuildHistory() -> [BuildResult]
    └── isBuilding() -> Bool
```

#### 3.3.2 `GoBuildOutputParser.swift`

**职责**：解析 `go build` 输出，提取结构化信息。

**需要解析的模式**：

| 模式 | 正则示例 | 提取内容 |
|------|---------|---------|
| 编译错误 | `^(.*?):(\d+):\d*:\s*(error):\s*(.*)` | 文件、行、类型、消息 |
| 编译警告 | `^(.*?):(\d+):\d*:\s*(warning):\s*(.*)` | 文件、行、类型、消息 |
| 包路径 | `^# (.*)$` | 当前编译的包 |
| 构建成功 | `^$` （无输出即成功） | 构建耗时 |
| 构建失败时间 | 计时器 | 构建总耗时 |

**输出结构**：

```
GoBuildIssue {
  fileURL: URL
  line: Int
  column: Int
  severity: .error / .warning
  message: String
  code: String?      // 错误代码（如 go vet 的代码）
}
```

#### 3.3.3 `GoBuildOutputView.swift`

**职责**：展示构建日志和错误列表。

**UI 结构**：

```
┌─────────────────────────────────────────┐
│ 🔨 Build Output              ✕   ⚙️   │
├─────────────────────────────────────────┤
│ 🔴 3 errors, 1 warning    (1.2s)       │
├─────────────────────────────────────────┤
│ 📍 main.go:45:12  error: undefined: foo │
│ 📍 handler.go:23:5  warning: unused var │
│                                         │
│ # github.com/user/project/cmd            │
│ Compiling...                           │
│ ...                                    │
└─────────────────────────────────────────┘
```

**交互能力**：

- 点击错误行 → 跳转到对应文件和行
- 双击错误行 → 在编辑器中高亮该行
- 支持折叠/展开包级别的输出
- 支持复制错误信息

---

### 3.4 测试系统（`GoEditorPlugin/Test/`）

#### 3.4.1 `GoTestManager.swift`

**职责**：管理测试执行。

**核心能力**：

| 能力 | 说明 |
|------|------|
| 单测试运行 | 执行光标所在测试函数 |
| 包测试 | 执行当前包所有测试 |
| 全局测试 | 执行项目所有测试 |
| 覆盖度 | `go test -cover` |
| 基准测试 | `go test -bench` |
| 并发控制 | 同一时间只允许一个测试运行 |

#### 3.4.2 `GoTestOutputParser.swift`

**职责**：解析 `go test -json` 输出。

**解析的 JSON 事件**：

```json
{"Action":"run","Package":"pkg","Test":"TestA","Time":"..."}
{"Action":"output","Package":"pkg","Test":"TestA","Output":"=== RUN   TestA\n"}
{"Action":"pass","Package":"pkg","Test":"TestA","Elapsed":0.123}
{"Action":"fail","Package":"pkg","Test":"TestB","Elapsed":0.456}
```

**映射到 UI 状态**：

| 事件 | UI 表现 |
|------|--------|
| `run` | 显示运行中动画 |
| `pass` | 显示绿色 ✅ |
| `fail` | 显示红色 ❌ + 错误输出 |
| `skip` | 显示灰色 ⏭️ |

#### 3.4.3 `GoTestResultView.swift`

**职责**：展示测试结果。

**UI 结构**：

```
┌─────────────────────────────────────────┐
│ 🧪 Test Results                ✕   ⚙️   │
├─────────────────────────────────────────┤
│ ✅ 12 passed, 2 failed, 1 skipped       │
├─────────────────────────────────────────┤
│ ✅ TestUserService_Register     0.12s   │
│ ✅ TestUserService_Login        0.08s   │
│ ❌ TestUserService_Logout       0.34s   │
│    └─ expected: true, got: false        │
│ ⏭️ TestUserService_Mock         skipped │
└─────────────────────────────────────────┘
```

**Gutter 集成**：

在代码行号旁显示测试结果图标：
- ✅ 测试通过
- ❌ 测试失败
- ⏭️ 测试跳过
- 🔄 测试运行中

---

### 3.5 调试系统（`GoEditorPlugin/Debug/`）- P3 阶段

#### 3.5.1 `DelveAdapter.swift`

**职责**：适配 Delve 调试器（DAP - Debug Adapter Protocol）。

**核心能力**：

| 能力 | 说明 |
|------|------|
| 启动调试 | `dlv dap` 启动 DAP Server |
| 断点管理 | 设置/删除/条件断点 |
| 变量查看 | 查看当前作用域变量 |
| 调用栈 | 显示调用栈信息 |
| 步进控制 | Step Over / Step Into / Step Out / Continue |

**与内核的对接**：

- DAP 协议与 LSP 协议类似，都是 JSON-RPC
- 需要新增 `DAPClient`（类似 `LSPService`）
- 调试 UI 复用 `LSPSheetsEditorPlugin` 的 Sheet 机制

#### 3.5.2 `DebugSessionManager.swift`

**职责**：管理调试会话。

**会话状态机**：

```
Idle → Launching → Running → Paused → Stepping → Stopped
  ↑                                                    ↓
  └────────────────────────────────────────────────────┘
```

---

### 3.6 Tree-Sitter 语法（`GoEditorPlugin/Grammar/`）

#### 3.6.1 `GoTreeSitterRegistration.swift`

**职责**：注册 `tree-sitter-go` grammar。

**需要注册的语法**：

- Go 语言关键词：`go`, `func`, `var`, `const`, `type`, `struct`, `interface`, `map`, `chan`, `defer`, `go`, `select`, `package`, `import`, `range`, `if`, `else`, `for`, `switch`, `case`, `fallthrough`, `break`, `continue`, `return`, `goto`
- Go 特有结构：`goroutine` 启动 (`go func()`)、`channel` 操作 (`<-`)、`type assertion` (`.(type)`)

**与现有内核的对接**：

- `CodeEditLanguages` 应已包含 Go 的 tree-sitter grammar
- 插件只需在激活时确保 grammar 已注册
- 用于本地高亮和 `JumpToDefinitionDelegate` 的 AST 回退查找

---

## 四、与现有内核/插件的对接点

### 4.1 必须对接的内核模块

| 内核模块 | 对接方式 | 说明 |
|---------|---------|------|
| `EditorExtensionRegistry` | 注册 `EditorCommandContributor` | 提供 Go 专属命令 |
| `EditorExtensionRegistry` | 注册 `EditorCompletionContributor` | Go 补全策略 |
| `EditorExtensionRegistry` | 注册 `EditorHoverContributor` | Go 悬停提示 |
| `EditorExtensionRegistry` | 注册 `EditorInteractionContributor` | 文本变化时触发诊断 |
| `LSPConfig` | 读取/覆盖 Go 配置 | gopls 启动参数 |
| `LSPService` | 启动 gopls 进程 | LSP 通信 |
| `LSPRequestPipeline` | 包装所有 LSP 请求 | 请求代际控制 |
| `JumpToDefinitionDelegate` | 无需修改，自动工作 | LSP 已支持 textDocument/definition |
| `CommandRegistry` | 注册 go.build / go.test 等命令 | 命令化 |

### 4.2 可复用的现有插件

| 现有插件 | 复用内容 | 说明 |
|---------|---------|------|
| `LSPServiceEditorPlugin` | LSP 补全/悬停/诊断 | Go 不需要重写这些基础能力 |
| `LSPContextCommandsEditorPlugin` | Cmd+Click 跳转 | 自动走 LSP 通道 |
| `LSPCodeActionEditorPlugin` | 代码动作 | gopls 返回的代码动作自动展示 |
| `LSPDocumentHighlightEditorPlugin` | 符号高亮 | gopls 返回的文档高亮自动展示 |
| `LSPFoldingRangeEditorPlugin` | 折叠范围 | gopls 返回的折叠范围自动展示 |
| `LSPCallHierarchyEditorPlugin` | 调用层级 | gopls 返回的调用层级自动展示 |
| `LSPWorkspaceSymbolEditorPlugin` | 工作区符号 | gopls 返回的符号自动展示 |
| `LSPSidePanelsEditorPlugin` | Problems / References 面板 | 自动展示 gopls 诊断和引用 |

### 4.3 Go 插件只需新增的内容

| 模块 | 说明 |
|------|------|
| `gopls` 配置管理 | 启动参数、环境变量、workspace 配置 |
| Go 工程命令 | build / test / mod / fmt |
| 构建输出面板 | 实时日志 + 错误解析 + 跳转 |
| 测试输出面板 | 测试结果 + gutter 图标 |
| 状态栏指示器 | 构建/测试状态 |
| Go 项目检测 | go.mod 定位 + go env 解析 |

---

## 五、分阶段实施计划

### Phase 1: LSP 基础（P0）

**目标**：实现 Go 语言的核心智能编辑能力。

| 任务 | 文件 | 验收标准 |
|------|------|---------|
| gopls 配置管理 | `GoLSPConfig.swift` | gopls 成功启动，LSP 通信正常 |
| Go 项目检测 | `GoProjectDetector.swift` | 正确识别 go.mod 位置 |
| go env 解析 | `GoEnvResolver.swift` | 正确获取 GOPATH/GOROOT |
| Cmd+Click 跳转 | （复用现有） | 能跳转到定义、声明、类型定义 |
| 自动补全 | `GoCompletionPipeline.swift` | 补全列表正常显示 |
| 悬停提示 | （复用现有） | Hover 显示类型签名和文档 |
| 实时诊断 | （复用现有） | 编译错误实时显示在编辑器中 |

**预计工作量**：3-5 天

---

### Phase 2: 工程命令（P0-P1）

**目标**：实现 Go 项目的构建和格式化能力。

| 任务 | 文件 | 验收标准 |
|------|------|---------|
| `go build` 命令 | `GoBuildCommand.swift` + `GoBuildManager.swift` | ⌘B 触发构建 |
| 构建输出解析 | `GoBuildOutputParser.swift` | 正确提取 error/warning |
| 构建输出面板 | `GoBuildOutputView.swift` | 实时日志 + 错误可点击跳转 |
| `go fmt` 命令 | `GoFmtCommand.swift` | 格式化当前文件/包 |
| `go mod tidy` | `GoModCommand.swift` | 执行 tidy 并展示结果 |

**预计工作量**：5-7 天

---

### Phase 3: 测试系统（P1）

**目标**：实现 Go 测试的完整体验。

| 任务 | 文件 | 验收标准 |
|------|------|---------|
| `go test` 命令 | `GoTestCommand.swift` + `GoTestManager.swift` | 执行测试 |
| 测试输出解析 | `GoTestOutputParser.swift` | 解析 -json 输出 |
| 测试结果面板 | `GoTestResultView.swift` | 展示测试通过/失败 |
| Gutter 测试图标 | （与 SourceEditorView 集成） | 行号旁显示测试状态 |
| 单测试运行 | （基于光标位置推导） | 运行光标所在测试函数 |

**预计工作量**：5-7 天

---

### Phase 4: 体验打磨（P1-P2）

**目标**：提升 Go 开发的整体体验。

| 任务 | 文件 | 验收标准 |
|------|------|---------|
| Inlay Hints | `GoInlayHintPipeline.swift` | 显示类型推断提示 |
| 保存时格式化 | （集成到 Save 流程） | 保存时自动 go fmt |
| 状态栏指示器 | `GoStatusBarIndicator.swift` | 显示构建/测试状态 |
| 代码透镜（Code Lens） | （与 LSPCodeActionEditorPlugin 集成） | 显示 Run Test / Debug Test |
| Go 文件模板 | （可选） | 新建 .go 文件时提供模板 |

**预计工作量**：3-5 天

---

### Phase 5: 调试系统（P3）

**目标**：实现 Delve 调试器集成。

| 任务 | 文件 | 验收标准 |
|------|------|---------|
| Delve DAP 适配 | `DelveAdapter.swift` | 启动调试会话 |
| 断点管理 | （与编辑器集成） | 设置/删除断点 |
| 变量查看 | （调试面板） | 查看变量值 |
| 步进控制 | （工具栏按钮） | Step/Continue/Stop |

**预计工作量**：7-10 天

---

## 六、风险与应对

| 风险 | 影响 | 应对策略 |
|------|------|---------|
| `gopls` 未安装 | 所有 LSP 能力不可用 | 提供安装引导，使用 AST/正则降级 |
| `gopls` 启动慢 | 用户体验差 | 显示加载状态，后台预热 |
| 大型 Go 项目索引慢 | 补全/跳转延迟高 | 限制 viewport 请求，使用缓存 |
| `go build` 输出格式变化 | 解析失败 | 使用多种模式匹配，降级为纯文本展示 |
| Tree-Sitter Go grammar 未加载 | AST 回退失效 | 确保 CodeEditLanguages 包含 Go grammar |
| 交叉编译环境配置 | 构建失败 | 提供 GUI 配置 GOOS/GOARCH |

---

## 七、验收标准

### 7.1 基础验收（Phase 1 完成后）

- [ ] 打开 `.go` 文件，语法高亮正常
- [ ] Cmd+Click 符号，能跳转到定义（同文件 + 跨文件）
- [ ] 输入代码时，自动补全列表出现
- [ ] 鼠标悬停符号，显示类型签名和文档
- [ ] 编译错误实时显示（红色波浪线）

### 7.2 工程验收（Phase 2 完成后）

- [ ] ⌘B 触发 `go build`，输出面板实时显示日志
- [ ] 构建错误可点击跳转到对应文件和行
- [ ] `go fmt` 能格式化当前文件
- [ ] `go mod tidy` 能执行并展示结果

### 7.3 测试验收（Phase 3 完成后）

- [ ] 工具栏按钮触发 `go test`
- [ ] 测试结果面板展示通过/失败
- [ ] Gutter 显示测试状态图标
- [ ] 能运行单个测试函数

### 7.4 体验验收（Phase 4 完成后）

- [ ] Inlay Hints 显示类型推断
- [ ] 保存时自动格式化
- [ ] 状态栏显示构建/测试状态

---

## 八、与 VS Code Go 扩展的对比

| 能力 | VS Code Go | Lumi GoEditorPlugin |
|------|-----------|---------------------|
| Cmd+Click 跳转 | ✅ gopls | ✅ gopls（复用 JumpToDefinitionDelegate） |
| 自动补全 | ✅ gopls | ✅ gopls（复用 LSPService） |
| 悬停提示 | ✅ gopls | ✅ gopls（复用 LSPService） |
| 实时诊断 | ✅ gopls | ✅ gopls（复用 LSPSidePanelsEditorPlugin） |
| 代码动作 | ✅ gopls | ✅ gopls（复用 LSPCodeActionEditorPlugin） |
| 符号重命名 | ✅ gopls | ✅ gopls（复用现有） |
| 查找引用 | ✅ gopls | ✅ gopls（复用现有） |
| go build | ✅ Tasks | ✅ GoBuildManager（原生） |
| go test | ✅ Test Explorer | ✅ GoTestManager（原生） |
| go mod | ✅ 代码透镜 | ✅ GoModCommand（原生） |
| Debug (Delve) | ✅ DAP | ⏳ Phase 5 |
| 代码透镜 | ✅ codelens | ⏳ Phase 4 |
| 文件模板 | ✅ 部分 | ⏳ Phase 4 |
| 扩展市场 | ✅ 丰富 | ❌ 不优先 |

---

## 九、总结

GoEditorPlugin 的实施核心思想是：**LSP 能力复用现有管线，工程命令原生实现**。

- **LSP 智能编辑**：`gopls` 提供的能力（跳转、补全、悬停、诊断、代码动作等）通过现有 `LSPServiceEditorPlugin` 管线自动生效，Go 插件只需确保 `gopls` 正确配置和启动。
- **工程能力**：`go build`、`go test`、`go mod`、`go fmt` 等命令行工具需要原生封装，通过 `Process` 调用并解析输出，这是 Go 插件的主要工作量所在。
- **用户体验**：构建/测试输出面板、状态栏指示器、gutter 图标等需要与现有编辑器视图层集成，这是实现"像 VS Code 一样好用"的关键。
