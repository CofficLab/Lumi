# JSEditorPlugin 实施方案

> 本方案定义 Lumi 编辑器对 JavaScript / TypeScript 项目完整支持的实现路径、模块划分、生态适配策略，以及与现有内核/插件的对接点。

---

## 一、目标

使 Lumi 编辑器对 JS/TS 项目提供 **开箱即用、生态自适应、可配置扩展** 的开发体验。与 Go 插件的"统一工具链封装"不同，JS/TS 插件采用 **配置驱动 + 生态适配层** 架构。

| 维度 | 能力 | 优先级 |
|------|------|--------|
| **语言智能** | Cmd+Click 跳转到定义/实现/类型定义 | P0 |
| **语言智能** | 自动补全 (Completion) | P0 |
| **语言智能** | 悬停提示 (Hover，类型签名 + JSDoc/TSDoc) | P0 |
| **语言智能** | 实时诊断 (Type 错误 + Lint 规则) | P0 |
| **语言智能** | 代码动作 (Quick Fix / Auto Import) | P1 |
| **语言智能** | 符号重命名 / 查找引用 | P1 |
| **语言智能** | 语义高亮 / Inlay Hints / 折叠范围 | P2 |
| **工程能力** | `package.json` 脚本识别与执行 | P0 |
| **工程能力** | 构建任务流式输出 + 错误解析跳转 | P1 |
| **工程能力** | `prettier` / `eslint` 格式化与修复 | P1 |
| **测试能力** | Jest / Vitest / Mocha 自动识别与运行 | P1 |
| **测试能力** | 统一测试结果面板 + Gutter 状态 | P2 |
| **调试能力** | Node.js DAP 调试 | P2 |
| **调试能力** | 浏览器 CDP 调试 + Sourcemap 映射 | P3 |
| **工程能力** | Monorepo / pnpm workspace / yarn workspaces | P2 |

---

## 二、目录结构

遵循 `plugin-directory-rules` 规范，在 `LumiApp/Plugins-Editor/JSEditorPlugin/` 下组织：

```
JSEditorPlugin/
├── JSEditorPlugin.swift                 # 插件入口（遵循 EditorFeaturePlugin）
├── JSEditorPlugin.xcstrings             # 本地化字符串
├── README.md                            # 本实施方案文档
│
├── LSP/                                 # LSP 多服务器编排
│   ├── TSLSPConfig.swift               # tsserver 启动参数、TSConfig 注入
│   ├── ESLintLSPBridge.swift           # ESLint 集成（CLI 解析 / LSP 双模式）
│   ├── FrameworkLSPLoader.swift        # 动态探测并加载 Volar / Angular LS / Svelte LS
│   └── DiagnosticAggregator.swift      # 多 LSP 诊断去重、冲突解决与优先级合并
│
├── Config/                              # 项目配置解析
│   ├── PackageJSONParser.swift         # scripts 分类、依赖类型推断、引擎版本探测
│   ├── TSConfigResolver.swift          # tsconfig/jsconfig 解析、paths 别名映射
│   └── WorkspaceDetector.swift         # monorepo 识别（pnpm/yarn/nx/turborepo）
│
├── Tasks/                               # 通用任务/构建管线
│   ├── ScriptTaskRunner.swift          # 执行 npm/pnpm/yarn/bun run <script>
│   ├── BuildOutputAdapter.swift        # 多打包器错误正则适配（Vite/Webpack/esbuild/Next）
│   └── TaskOutputView.swift            # 任务日志面板 + 错误点击跳转
│
├── Test/                                # 测试适配层
│   ├── TestRunnerDetector.swift        # 从 devDependencies 识别 Jest / Vitest / Playwright
│   ├── TestOutputParser.swift          # 多格式 JSON 输出标准化
│   └── TestResultView.swift            # 测试结果面板 + 运行控制
│
├── Debug/                               # 调试系统
│   ├── NodeDAPAdapter.swift            # Node.js 调试适配（DAP）
│   ├── BrowserCDPAdapter.swift         # 浏览器远程调试（CDP）
│   ├── SourceMapResolver.swift         # .map 文件解析与断点源码映射
│   └── DebugSessionManager.swift       # 调试会话状态机与断点同步
│
├── Format/                              # 格式化
│   ├── PrettierFormatter.swift         # prettier CLI 封装 + 范围格式化
│   └── FormatOnSaveCoordinator.swift   # 保存时格式化协调器（避免与 LSP format 冲突）
│
├── Grammar/                             # Tree-Sitter 语法
│   └── JSTreeSitterRegistration.swift   # tree-sitter-javascript / tree-sitter-typescript 注册
│
├── Models/                              # 数据模型
│   ├── JSPackageInfo.swift             # package.json 解析结果
│   ├── TSProjectConfig.swift           # 编译配置 + 路径映射
│   ├── TaskIssue.swift                 # 构建/任务问题（error/warning）
│   └── TestSuiteResult.swift           # 标准化测试结果模型
│
├── Services/                            # 业务服务
│   ├── JSEnvResolver.swift             # node/bun/deno/nvm 路径探测
│   ├── ModuleResolver.swift            # ESM / CJS / node_modules / alias 路径解析
│   └── RuntimeBridge.swift             # 跨运行时脚本执行桥接（npm/pnpm/yarn/bun）
│
├── ViewModels/                          # 视图模型
│   ├── TaskViewModel.swift
│   └── TestViewModel.swift
│
└── Views/                               # SwiftUI 视图
    ├── TaskPanelView.swift             # 任务/构建日志面板
    ├── TestPanelView.swift             # 测试结果面板
    └── DebugToolbarView.swift          # 调试控制栏
```

---

## 三、核心架构设计

### 3.1 配置驱动，而非命令硬编码
Go 生态工具链统一（`go build`/`go test`），但 JS/TS 生态高度碎片化。本插件 **不预设固定命令**，而是通过解析 `package.json` + 锁文件 + 框架配置，动态生成可用能力清单：
- 自动分类 `scripts`：`dev` / `build` / `test` / `lint` / `start` / `serve`
- 根据 `devDependencies` 推断工具链：`vite` → Vite 适配器；`next` → Next 适配器；无打包器 → 纯 TS/Node 模式
- 提供 **用户覆盖配置**：允许在 Lumi 设置中手动指定脚本命令或忽略自动探测

### 3.2 LSP 多服务器协同与诊断聚合
- **基础层**：`typescript-language-server` 提供类型检查、跳转、补全
- **规范层**：`eslint` 提供 lint 规则、代码风格、快速修复
- **框架层**：按需加载 `@vue/language-server`、`@angular/language-server` 等
- **冲突解决**：`DiagnosticAggregator` 负责：
  - 按 `source` 标签去重（同一位置 tsserver 和 eslint 报相同错误时保留高优先级）
  - 统一 severity 映射（error > warning > info > hint）
  - 支持用户配置优先级覆盖（如 `eslint.priority: high`）

### 3.3 运行时与包管理器桥接
- 自动探测 `.nvmrc` / `.node-version` / `engines.node` 约束
- 识别项目根目录的锁文件：`pnpm-lock.yaml` → `pnpm`；`yarn.lock` → `yarn`；`package-lock.json` → `npm`；`bun.lockb` → `bun`
- 统一执行接口 `RuntimeBridge.run(script, cwd)`，底层自动选择对应包管理器

---

## 四、核心模块实施详情

### 4.1 LSP 协同与配置（`JSEditorPlugin/LSP/`）

#### 4.1.1 `TSLSPConfig.swift`

**职责**：管理 `typescript-language-server` 启动与 TypeScript 配置注入。

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| `tsserver` 路径 | 优先使用项目本地 `node_modules/.bin/tsserver`，否则全局 | `auto-detect` |
| `tsconfig` 路径 | 自动查找 `tsconfig.json` / `jsconfig.json` | `nearest-upward` |
| `allowJs` | 是否对 `.js` 文件启用类型检查 | 跟随 tsconfig |
| `importModuleSpecifierPreference` | 自动导入路径偏好 | `shortest` |

**与内核对接**：
- 复用 `LSPService` 启动流程，通过 `LSPConfig.override(for: "typescript")` 注入自定义参数
- 监听文件变动，动态刷新 `tsserver` 的项目配置（`/reloadProjects`）

#### 4.1.2 `DiagnosticAggregator.swift`

**职责**：合并多语言服务器诊断，避免红波浪线重复/冲突。

**聚合策略**：
```swift
enum DiagnosticPriority: Int {
    case tsserver_type = 10
    case eslint_lint = 20
    case prettier_style = 30
    case framework_sfc = 40
}

struct MergedDiagnostic {
    let range: NSRange
    let severity: Severity
    let message: String
    let source: String
    let code: String?
    let quickFixes: [CodeAction]
}
```
**工作流**：
1. 接收各 LSP 客户端的 `publishDiagnostics`
2. 按文件分组，按行/范围排序
3. 重叠诊断按 `priority` 覆盖，保留 `quickFixes` 并集
4. 输出至 `ProblemsPanel` 和编辑器 gutter

### 4.2 项目探测与智能配置（`JSEditorPlugin/Config/`）

#### 4.2.1 `PackageJSONParser.swift`

**职责**：解析 `package.json`，提取项目画像。

**分类逻辑**：
| 脚本关键词 | 归类 | 默认触发方式 |
|------------|------|--------------|
| `dev`, `serve`, `start` | 开发服务 | 命令面板 / 工具栏 ▶️ |
| `build`, `compile` | 构建 | `⌘B` / 工具栏 🔨 |
| `test`, `jest`, `vitest` | 测试 | 测试面板 / Gutter 按钮 |
| `lint`, `format` | 代码质量 | 保存时 / 手动触发 |

**依赖推断**：
```json
{
  "devDependencies": { "jest": "^29.0.0" } → TestRunner = .jest
  "dependencies": { "react": "^18.0.0" } → Framework = .react
  "devDependencies": { "vite": "^5.0.0" } → Builder = .vite
}
```

#### 4.2.2 `TSConfigResolver.swift`

**职责**：解析 `tsconfig.json`，处理路径别名与编译选项。

**关键处理**：
- `compilerOptions.paths` 映射：`"@/*": ["src/*"]` → 补全/跳转时替换为真实相对路径
- `baseUrl` / `rootDir` / `outDir` 提取，用于 ModuleResolver 解析边界
- 监听 `tsconfig` 变更，触发 LSP 重新加载项目上下文

### 4.3 通用任务/构建管线（`JSEditorPlugin/Tasks/`）

#### 4.3.1 `ScriptTaskRunner.swift`

**职责**：执行 `package.json` 脚本，流式输出。

**执行流程**：
```
用户触发 ▶️ dev
    ↓
1. RuntimeBridge 识别包管理器 (pnpm/yarn/npm/bun)
    ↓
2. 组装命令: pnpm run dev -- --host (透传参数)
    ↓
3. Process 启动，Pty 模拟终端 (支持 ANSI 颜色)
    ↓
4. 实时流式输出到 TaskOutputView
    ↓
5. 监听退出码，更新状态 (success/failed/killed)
```

#### 4.3.2 `BuildOutputAdapter.swift`

**职责**：解析不同打包器的错误输出，提取结构化问题。

| 打包器 | 错误特征 | 提取正则示例 |
|--------|----------|--------------|
| **Vite** | `file: /src/App.tsx:12:5` | `^\\[plugin.*?\\] (\\S+?):(\\d+):(\\d+):\\s*(.*)` |
| **Webpack** | `ERROR in ./src/App.tsx 12:5` | `^ERROR\\s+in\\s+\\.\\/(.*?):(\\d+):(\\d+)` |
| **esbuild** | `✘ [ERROR] TS2339: Property 'foo' ...` | `^\\u2718\\s+\\[ERROR\\]\\s+.*?\\((.*?):(\\d+),(\\d+)\\)` |
| **Next.js** | `Type error: Type '...' is not assignable` | `^Type error:.*\\n\\s+(.*?):(\\d+):(\\d+)` |

**降级策略**：正则匹配失败时，展示原始日志，但保留点击跳转功能（基于最后匹配的 `file:line:col`）

### 4.4 测试适配层（`JSEditorPlugin/Test/`）

#### 4.4.1 `TestRunnerDetector.swift`

**职责**：自动识别测试框架。

**探测优先级**：
1. `vitest` 存在 → 优先使用（启动快、原生 JSON）
2. `jest` 存在 → 使用 `jest --json --outputFile=/dev/stdout`
3. `mocha` / `cypress` → CLI 适配（需包装 JSON reporter）
4. 无识别 → 禁用测试面板，提供手动配置入口

#### 4.4.2 `TestOutputParser.swift`

**职责**：标准化不同 runner 的输出为 `TestSuiteResult`。

**统一模型**：
```swift
struct TestSuiteResult {
    let suiteName: String
    let status: .passed / .failed / .skipped
    let duration: TimeInterval
    let tests: [TestCaseResult]
}

struct TestCaseResult {
    let name: String
    let fileURL: URL?
    let line: Int?
    let status: .passed / .failed / .skipped
    let errorMessage: String?
    let duration: TimeInterval
}
```
**Gutter 联动**：解析 `fileURL` + `line`，在 `SourceEditorView` 对应行显示 ✅/❌/⏭️，点击运行单测。

### 4.5 调试系统（`JSEditorPlugin/Debug/`）

#### 4.5.1 `NodeDAPAdapter.swift`

**职责**：对接 Node.js 调试协议 (DAP)。

**关键能力**：
- 启动命令：`node --inspect-brk <script>` 或直接使用 `js-debug` DAP server
- 断点设置：支持条件断点、日志断点、异常断点
- 变量查看：支持 `Scope` 展开、Watch 表达式、Evaluate

#### 4.5.2 `SourceMapResolver.swift`

**职责**：处理 `.map` 文件，实现编译后代码 → 源码断点映射。

**映射流程**：
```
用户点击行号设置断点 (App.tsx:20)
    ↓
1. 查找编译产物对应 .map 文件
    ↓
2. 解析 SourceMap v3 (sources, mappings, names)
    ↓
3. 使用 `vlq` 解码 mapping，匹配 generated line/col → original line/col
    ↓
4. 将实际断点发送给 DAP Server (绑定到 dist/App.js:45)
    ↓
5. 命中断点时，反向映射回 App.tsx:20 并高亮
```
**优化**：缓存已解析的 sourcemap，支持 inline sourcemap (`sourceMappingURL=data:...`)，忽略 `node_modules` 映射。

---

## 五、与现有内核/插件的对接点

### 5.1 必须对接的内核模块

| 内核模块 | 对接方式 | 说明 |
|---------|---------|------|
| `EditorExtensionRegistry` | 注册 `EditorLanguageContributor` | 声明 `.js`/`.ts`/`.jsx`/`.tsx` 文件类型 |
| `LSPService` | 启动 tsserver / eslint / framework LS | 多客户端生命周期管理 |
| `LSPRequestPipeline` | 路由补全/跳转/诊断请求 | 按 `languageId` 分发 |
| `CommandRegistry` | 注册 `js.run.dev` / `js.build` / `js.test` | 命令化执行 |
| `SaveCoordinator` | 接入 `FormatOnSaveCoordinator` | 保存时触发 prettier/eslint --fix |
| `CodeEditLanguages` | 注册 JS/TS Tree-Sitter grammar | 本地高亮与语法树回退 |

### 5.2 可复用的现有插件

| 现有插件 | 复用内容 | 说明 |
|---------|---------|------|
| `LSPServiceEditorPlugin` | 基础 LSP 通信管线 | JS 插件负责配置注入，不重写协议层 |
| `LSPContextCommandsEditorPlugin` | Cmd+Click 跳转 | 自动路由至 tsserver 的 `textDocument/definition` |
| `LSPCodeActionEditorPlugin` | 代码动作 | 快速修复、Auto Import、Organize Imports |
| `LSPSidePanelsEditorPlugin` | Problems / References 面板 | 直接展示 `DiagnosticAggregator` 输出 |
| `TerminalPlugin` (若存在) | 内置终端执行 | 任务运行可降级至终端视图 |

### 5.3 JSEditorPlugin 只需新增的内容

| 模块 | 说明 |
|------|------|
| `package.json` 解析与脚本分类 | 项目画像生成核心 |
| `ScriptTaskRunner` + 输出适配 | 跨打包器任务执行与错误提取 |
| `TestRunnerDetector` + 标准化解析 | 统一测试体验 |
| `DiagnosticAggregator` | 多 LSP 冲突解决 |
| `SourceMapResolver` | 调试断点映射核心 |
| Monorepo 工作区探测 | pnpm/yarn/nx 支持 |

---

## 六、分阶段实施计划

### Phase 1: LSP 基础 + 项目自动探测（P0）
**目标**：实现 JS/TS 核心智能编辑能力，自动识别项目结构。
| 任务 | 文件 | 验收标准 |
|------|------|---------|
| tsserver 配置与启动 | `TSLSPConfig.swift` | 自动定位本地/全局 tsserver，通信正常 |
| `package.json` 解析 | `PackageJSONParser.swift` | 正确提取 scripts、依赖、引擎版本 |
| `tsconfig` 路径映射 | `TSConfigResolver.swift` | `@/` 别名补全/跳转生效 |
| Cmd+Click 跳转 / 补全 / 悬停 | （复用 LSP 管线） | 跨文件跳转、类型提示、JSDoc 展示 |
| Tree-Sitter 注册 | `JSTreeSitterRegistration.swift` | 语法高亮、折叠范围生效 |
**预计工作量**：2-3 周

### Phase 2: 任务执行 + 格式化（P0-P1）
**目标**：实现 `package.json` 脚本执行与代码格式化。
| 任务 | 文件 | 验收标准 |
|------|------|---------|
| 脚本任务运行器 | `ScriptTaskRunner.swift` | `npm/pnpm/yarn run` 流式执行 |
| 构建输出适配 | `BuildOutputAdapter.swift` | Vite/Webpack/esbuild 错误可点击跳转 |
| prettier 格式化 | `PrettierFormatter.swift` | 格式化当前文件/选中范围 |
| 保存时格式化 | `FormatOnSaveCoordinator.swift` | 保存自动执行，支持开关 |
| 任务输出面板 | `TaskOutputView.swift` | 实时日志 + 状态指示 + 终止按钮 |
**预计工作量**：2-3 周

### Phase 3: 测试适配层（P1）
**目标**：统一测试体验，支持主流 Runner。
| 任务 | 文件 | 验收标准 |
|------|------|---------|
| 测试框架探测 | `TestRunnerDetector.swift` | 自动识别 Jest / Vitest |
| 输出标准化解析 | `TestOutputParser.swift` | 统一为 `TestSuiteResult` |
| 测试面板 | `TestResultView.swift` | 展示通过/失败/耗时，支持重新运行 |
| Gutter 测试图标 | （与编辑器集成） | 行号旁显示状态，点击运行单测 |
**预计工作量**：2-3 周

### Phase 4: 调试 + ESLint 集成（P2）
**目标**：完整调试体验与代码规范检查。
| 任务 | 文件 | 验收标准 |
|------|------|---------|
| Node DAP 调试 | `NodeDAPAdapter.swift` | 断点/步进/变量查看正常 |
| ESLint 桥接 | `ESLintLSPBridge.swift` | lint 诊断实时展示，支持 quick fix |
| 诊断聚合 | `DiagnosticAggregator.swift` | tsserver + eslint 冲突解决 |
| 调试工具栏 | `DebugToolbarView.swift` | 启动/暂停/停止/继续控制 |
**预计工作量**：3-4 周

### Phase 5: Monorepo + 框架感知 + 浏览器调试（P2）
**目标**：覆盖企业级与前端框架场景。
| 任务 | 文件 | 验收标准 |
|------|------|---------|
| Monorepo 探测 | `WorkspaceDetector.swift` | pnpm workspace / nx 项目正确识别 |
| 框架 LS 自动加载 | `FrameworkLSPLoader.swift` | Vue/React/Angular 专属 LSP 按需启动 |
| 浏览器 CDP 调试 | `BrowserCDPAdapter.swift` | Chrome/Edge 远程调试接入 |
| Sourcemap 映射 | `SourceMapResolver.swift` | 编译后代码断点精准映射回源码 |
**预计工作量**：4-5 周

---

## 七、风险与应对

| 风险 | 影响 | 应对策略 |
|------|------|---------|
| `node_modules` 巨大导致 LSP 启动慢 | 补全/跳转卡顿 | 限制扫描边界（`exclude` / `typesVersions`），启用 `tsserver` 增量解析 |
| 多 LSP 诊断冲突/重复 | 用户困惑 | `DiagnosticAggregator` 严格去重，提供来源过滤开关 |
| 打包器错误格式频繁变更 | 解析失效 | 正则库社区可更新，降级展示原始日志+通用 `file:line` 提取 |
| Sourcemap 解析性能差 | 调试设置断点延迟 | 懒加载、LRU 缓存、仅解析当前工作区文件 |
| 包管理器/Node 版本不匹配 | 任务执行失败 | `JSEnvResolver` 读取 `.nvmrc`，提供版本切换引导 |
| 大型 Monorepo 内存溢出 | 编辑器卡顿 | LSP 虚拟工作区模式，按需加载子包，忽略非活跃包 |

---

## 八、验收标准

### 8.1 基础验收（Phase 1 完成后）
- [ ] 打开 `.ts` / `.tsx` / `.js` / `.jsx`，语法高亮正常
- [ ] Cmd+Click 符号，能跳转到定义（同文件 + 跨文件 + `node_modules` 类型声明）
- [ ] 输入代码时，自动补全列表出现（含 Auto Import）
- [ ] 悬停显示类型签名 + JSDoc/TSDoc 注释
- [ ] 类型错误实时显示（红色波浪线）

### 8.2 工程验收（Phase 2 完成后）
- [ ] 自动识别 `package.json` 脚本，命令面板可执行 `dev` / `build`
- [ ] 构建输出面板实时日志，错误可点击跳转到源码行
- [ ] 手动/保存时触发 `prettier` 格式化生效
- [ ] 支持 `npm` / `pnpm` / `yarn` / `bun` 自动切换

### 8.3 测试验收（Phase 3 完成后）
- [ ] 自动识别 Jest / Vitest，测试面板展示结果
- [ ] 测试通过/失败在代码行号旁显示图标
- [ ] 支持运行单文件 / 单测试用例
- [ ] 失败用例点击跳转至对应断言位置

### 8.4 体验验收（Phase 4~5 完成后）
- [ ] ESLint 诊断与 tsserver 合并展示，无重复报错
- [ ] Node.js 调试可下断点、步进、查看变量
- [ ] Monorepo 子包跳转/补全正常
- [ ] Vue/React 专属语法（SFC / JSX）补全与诊断正常

---

## 九、与 VS Code 生态对比

| 能力 | VS Code (需装扩展) | Lumi JSEditorPlugin |
|------|-------------------|---------------------|
| 基础 LSP (tsserver) | ✅ 内置 TypeScript 插件 | ✅ 内置自动探测 |
| ESLint 集成 | ⚠️ 需安装 ESLint 扩展 | ✅ 桥接自动启用 |
| Prettier 格式化 | ⚠️ 需安装 Prettier 扩展 | ✅ 保存时自动触发 |
| 构建任务 | ⚠️ 需配置 `tasks.json` | ✅ 自动解析 `scripts` |
| 测试运行 | ⚠️ 需 Jest/Vitest 扩展 | ✅ 自动识别并统一面板 |
| Node 调试 | ✅ 内置 js-debug | ✅ DAP 适配 + 统一 UI |
| 浏览器调试 | ⚠️ 需额外插件/配置 | ⏳ CDP 集成 (Phase 5) |
| Monorepo 支持 | ⚠️ 需 Nx/Turbo 扩展 | ⏳ 工作区探测 (Phase 5) |
| 开箱即用程度 | 🟡 中等（需装 3~5 个扩展） | 🟢 高（安装即用，按需加载） |
| 配置复杂度 | 🔴 高（json/tsconfig/eslint/prettier 分离） | 🟡 中（内核自动协调，用户可覆盖） |

---

## 十、总结

JSEditorPlugin 的实施核心思想是：**配置驱动 + 生态适配层 + 诊断聚合**。

- **项目画像为中心**：不硬编码命令，而是解析 `package.json`、`tsconfig`、锁文件，动态生成可用能力清单。
- **LSP 协同而非单打**：通过 `DiagnosticAggregator` 统一 tsserver / eslint / framework LS 输出，解决长期困扰前端开发者的"诊断打架"问题。
- **通用管线 + 正则适配**：构建/测试不绑定单一工具，提供可插拔的输出解析器，社区贡献即可扩展新打包器/测试框架。
- **调试与映射并重**：Sourcemap 是 JS/TS 调试的灵魂，独立模块负责精准映射，确保编译/混淆后断点仍能回退至源码。
- **框架能力按需加载**：React / Vue / Angular 专属 LSP 与语法仅在检测到对应依赖时激活，严格遵守 `minimal-functionality` 原则。

与 `GoEditorPlugin` 的"官方工具链直封"不同，JSEditorPlugin 本质上是一个 **生态编排器**。实现本方案后，Lumi 将具备对现代前端/全栈 JS/TS 项目的 **企业级开箱即用支持**，后续扩展只需新增适配模块，无需改动内核管线。
