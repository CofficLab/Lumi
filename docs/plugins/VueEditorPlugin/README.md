# VueEditorPlugin 实施方案

> 本方案定义 Lumi 编辑器对 Vue.js (尤其是 Vue 3 SFC) 完整支持的实现路径、模块划分、Volar 集成策略，以及与现有内核/插件的对接点。

---

## 一、目标

使 Lumi 编辑器对 Vue 项目提供 **原生般的单文件组件 (SFC) 编辑体验**。

与 HTML/JS/CSS 独立语言不同，Vue 的核心难点在于 **跨区块类型推导**：即 `<template>` 需要知道 `<script setup>` 中的变量，而 `<style scoped>` 需要理解 DOM 结构。本插件采用 **Volar 核心引擎 + 语言虚拟化分流** 架构。

| 维度 | 能力 | 优先级 |
|------|------|--------|
| **SFC 基础** | Vue 单文件组件解析 (SFC Parser) | P0 |
| **SFC 基础** | 三区块高亮分离 (Template/Script/Style) | P0 |
| **语言智能** | Volar 集成 (核心 LSP) | P0 |
| **语言智能** | Script Setup 变量模板补全 | P0 |
| **语言智能** | Props / Emits 智能提示 | P0 |
| **语言智能** | 组件自动导入 (Auto Import) | P1 |
| **语言智能** | 模板语法诊断与 Quick Fix | P1 |
| **样式支持** | `scoped` CSS 作用域感知 | P1 |
| **样式支持** | CSS Modules (`$style`) 类型推导 | P2 |
| **工程能力** | 自动检测 Vue 版本 (Vue 2 vs Vue 3) | P0 |
| **工程能力** | Vite + Vue 插件联动支持 | P1 |
| **调试支持** | Vue DevTools 协议桥接 | P2 |
| **重构能力** | 组件重命名联动 (文件 + 模板引用) | P2 |

---

## 二、目录结构

遵循 `plugin-directory-rules` 规范，在 `LumiApp/Plugins-Editor/VueEditorPlugin/` 下组织：

```
VueEditorPlugin/
├── VueEditorPlugin.swift                  # 插件入口（遵循 EditorFeaturePlugin）
├── VueEditorPlugin.xcstrings              # 本地化字符串
├── README.md                              # 本实施方案文档
│
├── LSP/                                   # LSP 核心服务
│   ├── VolarServiceManager.swift         # @vue/language-server 生命周期管理
│   ├── VueVirtualFileMapper.swift        # 虚拟文件映射 (.vue -> .vue.ts + .vue.html)
│   └── VueDiagnosticTransformer.swift    # 诊断坐标转换 (虚拟 -> 真实)
│
├── Config/                                # 配置解析
│   ├── VueVersionDetector.swift          # Vue 2 vs Vue 3 检测
│   ├── TSConfigVueExtender.swift         # tsconfig.json 中 vue 配置扩展
│   └── VueCompilerOptions.swift          # @vue/compiler-sfc 配置读取
│
├── Editor/                                # 编辑器增强
│   ├── SFCBlockHighlighter.swift         # SFC 区块头高亮与折叠控制
│   ├── ScriptSetupCompleter.swift        # Script Setup 上下文感知补全
│   ├── TemplateAttributeCompleter.swift  # 模板指令补全 (v-if, v-bind)
│   └── ComponentImportResolver.swift     # 组件名 -> 文件路径自动解析
│
├── Styles/                                # 样式联动
│   ├── ScopedStyleHelper.swift           # Scoped CSS 属性注入辅助
│   └── CSSModulesTypeGenerator.swift     # CSS Modules 类型生成与提示
│
├── Refactoring/                           # 重构工具
│   ├── ComponentRenamer.swift            # 组件重命名 (同步更新文件与引用)
│   └── PropDrillingAssistant.swift       # Props 传递辅助工具
│
├── Grammar/                               # Tree-Sitter 语法
│   └── VueTreeSitterRegistration.swift    # tree-sitter-vue 注册
│
├── Models/                                # 数据模型
│   ├── SFCBlock.swift                    # 区块模型 (type, attrs, content, range)
│   ├── VueComponentInfo.swift            # 组件元数据
│   └── VuePropDefinition.swift           # Props 定义模型
│
├── Services/                              # 业务服务
│   ├── VueProjectScanner.swift           # 项目组件树扫描
│   └── AutoImportRegistry.swift          # 自动导入注册表
│
├── ViewModels/                            # 视图模型
│   └── VueOutlineViewModel.swift
│
└── Views/                                 # SwiftUI 视图
    ├── VueOutlineView.swift              # 组件结构大纲视图
    └── VueBlockSelectorView.swift        # 区块快速切换视图 (⌘+1/2/3)
```

---

## 三、核心架构设计

### 3.1 Volar 深度集成 (The Volar Core)
Volar 不仅仅是一个 LSP，它是一个 **虚拟文件系统框架**。
- **架构逻辑**：
  1. **输入**：`MyComponent.vue` 文件。
  2. **处理**：Volar 将其拆解为三个虚拟文档：
     - `MyComponent.vue.html` (Template 部分)
     - `MyComponent.vue.ts` (Script 部分，注入类型声明)
     - `MyComponent.vue.css` (Style 部分)
  3. **输出**：LSP 请求发给这些虚拟文档，LSP 返回结果后，Volar 负责将坐标映射回真实的 `.vue` 文件。
- **Lumi 职责**：只需维护 Volar 进程的正确启动、配置注入（如 Vue 版本）以及坐标映射结果的转发。

### 3.2 Script Setup 上下文感知
Vue 3 的 `<script setup>` 语法糖改变了游戏规。
- 插件必须理解：在 Script 中定义的变量 `const count = ref(0)` 会 **自动暴露** 给 Template 使用，无需 `return`。
- **实现**：依赖 Volar 的 TS 插件能力，但在 UI 层，我们需要确保补全列表在 `<template>` 中也能精准显示 Script 上下文。

### 3.3 组件自动导入与路径解析
现代 Vue 项目（尤其是 Vite 项目）常使用自动导入。
- **Auto Import**：当用户在 Template 输入 `<MyComp` 时，插件应提示并支持自动插入 `import MyComp from './components/MyComp.vue'`。
- **Alias 支持**：完美解析 `tsconfig` 中的 `@/*` 别名，确保路径跳转正确。

---

## 四、核心模块实施详情

### 4.1 LSP 核心与映射 (`VueEditorPlugin/LSP/`)

#### 4.1.1 `VolarServiceManager.swift`

**职责**：管理 `@vue/language-server` 进程。

**关键配置**：
- **混合模式 (Hybrid Mode)**：启用 `vue.server.hybridMode`（Volar 推荐），仅由 Vue LS 处理 Template，Script 交给 TSServer。这能显著提高性能。
- **Vue 版本探测**：
  - 读取项目 `package.json` 中 `vue` 依赖版本。
  - Vue 2 项目自动启用 `@vue/vue2-language-server`。
  - Vue 3 项目启用 `@vue/language-server`。

**启动命令**：
```bash
node <workspace>/node_modules/@vue/language-server/bin/vue-language-server.js --stdio
```

#### 4.1.2 `VueVirtualFileMapper.swift`

**职责**：处理虚拟文档映射（主要在 Hybrid Mode 下由 Volar 内部处理，此模块主要负责 Lumi 侧的文件变动监听与同步）。

- **文件同步策略**：当 `.vue` 文件保存时，触发 `textDocument/didSave`。
- **局部更新**：当用户仅在 `<script>` 区域编辑时，优先发送 Script 虚拟文档的增量更新，减少 Template 区域的解析开销。

### 4.2 编辑器增强 (`VueEditorPlugin/Editor/`)

#### 4.2.1 `SFCBlockHighlighter.swift`

**职责**：优化 SFC 结构的视觉体验。

**特性**：
- **区块头高亮**：高亮 `<template>`, `<script setup>`, `<style scoped>` 标签栏，使其与普通代码区分。
- **独立折叠**：支持仅折叠 `<style>` 或 `<template>` 区域，保留 `<script>` 可见。
- **快捷导航**：提供 "Go to Script", "Go to Template" 快速跳转命令。

#### 4.2.2 `TemplateAttributeCompleter.swift`

**职责**：提供 Vue 专属指令补全。

**补全列表**：
- **核心指令**：`v-if`, `v-for`, `v-bind` (`:`), `v-on` (`@`), `v-model`, `v-slot` (`#`).
- **修饰符提示**：输入 `@click.` -> 提示 `.prevent`, `.stop`, `.self`.
- **参数提示**：输入 `v-for` -> 提示 `item in list` 语法格式。

### 4.3 样式联动 (`VueEditorPlugin/Styles/`)

#### 4.3.1 `ScopedStyleHelper.swift`

**职责**：辅助 `scoped` CSS 的编写。

- **属性提示**：在 `<style scoped>` 中，提示当前组件 Template 中使用过的 Class 名。
- **深层选择器**：提示 `:deep()` 语法（替代旧的 `/deep/`），帮助用户正确穿透 scoped 样式。

#### 4.3.2 `CSSModulesTypeGenerator.swift`

**职责**：为 `<style module>` 提供类型安全。

- **类型推导**：解析 `.module.css` 或 `<style module>` 中的类名。
- **TS 声明注入**：在 Script 中输入 `$style.` 时，自动补全 CSS 类名（如 `$style.container`）。
- **实现**：通过生成临时的 `.d.ts` 文件供 TSServer 消费。

### 4.4 重构工具 (`VueEditorPlugin/Refactoring/`)

#### 4.4.1 `ComponentRenamer.swift`

**职责**：安全的组件重命名。

**重命名流程**：
1. 用户重命名组件文件 `OldName.vue` -> `NewName.vue`。
2. 插件扫描项目中所有引用 `OldName` 的地方：
   - **Template**：`<OldName />` -> `<NewName />`。
   - **Script**：`import OldName from ...` -> `import NewName from ...`。
   - **Router**：路由配置中的引用更新。
3. 执行批量修改。

---

## 五、与现有内核/插件的对接点

### 5.1 必须对接的内核模块

| 内核模块 | 对接方式 | 说明 |
|---------|---------|------|
| `EditorExtensionRegistry` | 注册 `EditorLanguageContributor` | 声明 `.vue` 文件类型 |
| `LSPService` | 启动 Volar Language Server | 核心智能大脑 |
| `LSPRequestPipeline` | 路由请求 | 转发至 Volar |
| `CodeEditLanguages` | 注册 Vue Tree-Sitter grammar | 结构化分析基础 |
| `CommandRegistry` | 注册 `vue.goToTemplate` 等命令 | 区块导航 |

### 5.2 与 HTML / JS / CSS 插件的协作关系

这是最容易混淆的地方。在 Hybrid Mode 下，Volar 是 **协调者**，而 HTML/JS/CSS LSP 是 **底层工人**。

| 场景 | LSP 请求路由 | 说明 |
|------|-------------|------|
| **编辑 Template** | Volar -> (内部调用) -> HTML LS | Volar 包装 HTML 能力 |
| **编辑 Script** | Volar -> TSServer | Volar 包装 TS 能力 |
| **编辑 Style** | Volar -> CSS LS | Volar 包装 CSS 能力 |
| **跨区块跳转** | Volar 原生处理 | Volar 内部已实现虚拟映射 |

**结论**：Lumi 的 Vue 插件 **不需要** 像 HTML 插件那样自己实现偏移量映射（Shunting），而是利用 Volar 封装好的 `LanguageServicePlugin` 机制。Vue 插件的主要职责是 **进程管理**、**配置注入** 和 **UI 增强**。

### 5.3 VueEditorPlugin 独有的内容

| 模块 | 说明 |
|------|------|
| Volar 混合模式管理 | 协调 Vue/TS/CSS 三个服务的生命周期 |
| Script Setup 补全增强 | 理解 `<script setup>` 的隐式导出 |
| SFC 结构可视化 | 区块高亮、折叠与导航 |
| 组件自动导入注册 | 识别未导入的组件并提供 Quick Fix |

---

## 六、分阶段实施计划

### Phase 1: Volar 集成与基础 SFC 支持（P0）
**目标**：跑通 `.vue` 文件的基础智能编辑。
| 任务 | 文件 | 验收标准 |
|------|------|---------|
| Volar 进程管理 | `VolarServiceManager.swift` | Volar 成功启动，诊断正常 |
| Vue 版本检测 | `VueVersionDetector.swift` | 自动识别 Vue 2 / Vue 3 并加载对应 LS |
| 混合模式配置 | `VolarServiceManager.swift` | Script 跳转走 TSServer，Template 走 Volar |
| Tree-Sitter 注册 | `VueTreeSitterRegistration.swift` | SFC 结构高亮与折叠正常 |
**预计工作量**：2 周

### Phase 2: SFC 编辑器增强（P0）
**目标**：提升编写体验。
| 任务 | 文件 | 验收标准 |
|------|------|---------|
| SFC 区块高亮/折叠 | `SFCBlockHighlighter.swift` | 区块视觉区分明显，可独立折叠 |
| 指令补全 | `TemplateAttributeCompleter.swift` | `v-if`, `v-model` 等补全正常 |
| Script Setup 补全 | (Volar 原生支持) | 验证 Setup 变量在模板中可补全 |
| 区块导航命令 | `CommandRegistry` | Cmd+1/2/3 快速切换区块 |
**预计工作量**：1-2 周

### Phase 3: 高级特性与重构（P1）
**目标**：完善生态支持。
| 任务 | 文件 | 验收标准 |
|------|------|---------|
| 组件自动导入 | `ComponentImportResolver.swift` | 输入组件名提示导入路径 |
| Scoped CSS 辅助 | `ScopedStyleHelper.swift` | 提示 `:deep()` 语法 |
| 组件重命名 | `ComponentRenamer.swift` | 重命名文件同步更新引用 |
| CSS Modules 类型 | `CSSModulesTypeGenerator.swift` | `$style.` 补全类名 |
**预计工作量**：2-3 周

### Phase 4: 调试与工具链（P2）
**目标**：调试与构建联动。
| 任务 | 文件 | 验收标准 |
|------|------|---------|
| Vue DevTools 桥接 | `Debug/` (新增) | 支持组件树查看 (需浏览器扩展配合) |
| Vite 联动优化 | `Config/` | 识别 Vite 配置，优化热重载提示 |
**预计工作量**：2 周

---

## 七、风险与应对

| 风险 | 影响 | 应对策略 |
|------|------|---------|
| Volar 启动慢 | 打开 .vue 文件卡顿 | 使用 Hybrid Mode 分流，仅加载必要服务；后台预热 |
| 虚拟文档映射错误 | 补全/报错位置错乱 | Volar 内部已处理此问题，若出现异常需检查 Volar 版本兼容性 |
| Vue 2/3 混淆 | 插件崩溃或功能缺失 | 严格检测 `package.json`，若无法识别则降级为普通 HTML/JS |
| Node 环境缺失 | Volar 无法启动 | 提供"安装 Node.js"引导，或尝试使用系统路径 |

---

## 八、验收标准

### 8.1 基础验收（Phase 1 完成后）
- [ ] 打开 `.vue` 文件，Template/Script/Style 区分显示
- [ ] 提供 Template 语法高亮
- [ ] 基础类型错误（如 Template 中使用未定义变量）实时报错
- [ ] Cmd+Click 可跳转到组件定义或变量声明

### 8.2 体验验收（Phase 2 完成后）
- [ ] 输入 `v-` 提示 Vue 指令
- [ ] 输入 `@click` 提示修饰符
- [ ] `<script setup>` 中定义的变量在 Template 中有补全
- [ ] 区块折叠/展开流畅

### 8.3 进阶验收（Phase 3 完成后）
- [ ] 组件重命名联动更新
- [ ] 自动提示组件导入路径
- [ ] `scoped` 样式提示正确

---

## 九、总结

VueEditorPlugin 的核心策略是 **"Volar 核心 + 局部增强"**。

- **不重复造轮子**：利用 Volar 强大的虚拟文件系统处理最复杂的跨区块推导。
- **专注编辑器体验**：Lumi 原生插件层负责 SFC 特有的视觉呈现（区块高亮）、快捷导航和重构工具。
- **版本自适应**：自动检测 Vue 2/3，确保老项目和新项目都能获得最佳支持。

实现本方案后，Lumi 将成为一款 **对 Vue 开发者极具吸引力** 的编辑器，特别是在 macOS 平台上提供比 VS Code 更轻量、更原生的 SFC 编辑体验。
