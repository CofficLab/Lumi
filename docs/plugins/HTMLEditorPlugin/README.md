# HTMLEditorPlugin 实施方案

> 本方案定义 Lumi 编辑器对 HTML 语言完整支持的实现路径、模块划分、多语言内嵌策略，以及与现有内核/插件的对接点。

---

## 一、目标

使 Lumi 编辑器对 HTML 提供 **开箱即用、高效编辑、多语言无缝衔接** 的开发体验。

与 Go 插件的“工具链封装”和 JS 插件的“生态编排”不同，HTML 插件的核心挑战在于 **结构化编辑效率** 和 **内嵌语言（CSS/JS）的上下文切换**。

| 维度 | 能力 | 优先级 |
|------|------|--------|
| **基础编辑** | 标签自动闭合 (Auto-Closing) | P0 |
| **基础编辑** | 标签联动重命名 (Linked Editing) | P0 |
| **基础编辑** | 匹配标签高亮 (Highlight Matching) | P0 |
| **语言智能** | Emmet 缩写展开 (核心体验) | P0 |
| **语言智能** | 标准标签/属性补全 | P0 |
| **语言智能** | 悬停提示 (MDN 文档/ARIA 属性) | P1 |
| **语言智能** | 基础语法诊断 (未闭合/非法嵌套) | P1 |
| **语言智能** | 路径补全 (src/href) | P1 |
| **多语言** | 内嵌 CSS (`<style>`) 补全与诊断 | P0 |
| **多语言** | 内嵌 JS/TS (`<script>`) 补全与诊断 | P0 |
| **多语言** | 样式类名联动 (Class Name Completion) | P1 |
| **可视化** | 颜色预览 (Inline Color Preview) | P2 |

---

## 二、目录结构

遵循 `plugin-directory-rules` 规范，在 `LumiApp/Plugins-Editor/HTMLEditorPlugin/` 下组织：

```
HTMLEditorPlugin/
├── HTMLEditorPlugin.swift                 # 插件入口（遵循 EditorFeaturePlugin）
├── HTMLEditorPlugin.xcstrings             # 本地化字符串
├── README.md                              # 本实施方案文档
│
├── LSP/                                   # LSP 语言服务
│   ├── HTMLServiceManager.swift          # vscode-html-languageserver 生命周期管理
│   └── HTMLDiagnosticAggregator.swift    # HTML 专属诊断过滤
│
├── Emmet/                                 # Emmet 引擎
│   ├── EmmetEngine.swift                 # 缩写解析与 DOM 生成
│   ├── EmmetExpansionHandler.swift       # Tab 键触发与冲突处理
│   └── EmmetConfig.swift               # 配置文件 (variables/syntaxProfiles)
│
├── Structure/                             # 结构化编辑
│   ├── TagMatcher.swift                  # 开闭标签匹配逻辑
│   ├── TagRenamer.swift                  # 联动重命名 (双光标)
│   ├── TagHighlighter.swift              # 匹配标签高亮渲染
│   └── AutoclosingController.swift       # 智能闭合逻辑 (<br/> vs <div></div>)
│
├── Embedded/                              # 内嵌语言协调器
│   ├── LanguageShunter.swift             # 脚本/样式块上下文路由
│   ├── OffsetMapper.swift                # 虚拟文档偏移量计算
│   ├── EmbeddedCSSService.swift          # 内嵌 CSS LSP 适配
│   └── EmbeddedJSService.swift           # 内嵌 JS/TS LSP 适配
│
├── Helpers/                               # 辅助工具
│   ├── HTMLPathCompletion.swift          # src/href 路径补全
│   ├── ColorPreviewView.swift            # 颜色块内联渲染
│   └── ARIAAttributeDatabase.swift       # ARIA 属性元数据
│
├── Grammar/                               # Tree-Sitter 语法
│   └── HTMLTreeSitterRegistration.swift   # tree-sitter-html 注册
│
├── Models/                                # 数据模型
│   ├── HTMLEmbeddedRegion.swift          # 内嵌语言区域定义
│   ├── EmmetExpansion.swift              # Emmet 展开结果
│   └── TagLocation.swift                 # 标签位置信息
│
├── Services/                              # 业务服务
│   ├── HTMLProjectConfig.swift           # HTML 相关配置管理
│   └── EmmetProfileLoader.swift          # .emmetrc 加载
│
├── ViewModels/                            # 视图模型
│   └── EmmetViewModel.swift
│
└── Views/                                 # SwiftUI 视图
    ├── EmmetPreviewView.swift            # Emmet 预览 (可选)
    └── ColorPickerInlineView.swift       # 内联颜色选择器
```

---

## 三、核心架构设计

### 3.1 Emmet 为核心
Emmet 是 Web 开发者的生产力倍增器。本插件不依赖 LSP 提供 Emmet 能力（因为 LSP 的 Emmet 通常有延迟），而是 **本地集成 Emmet 引擎**，实现毫秒级响应。
- **上下文感知**：根据光标位置自动切换 Abbreviation 语法（HTML 模式 / CSS 模式）。
- **冲突处理**：在 `<script>` 和 `<style>` 块内禁用 HTML Emmet，交由内嵌 LSP 处理。

### 3.2 内嵌语言分流 (Shunting)
HTML 文件本质上是多语言的容器。Lumi 需要通过 **偏移量映射 (Offset Mapping)** 和 **虚拟文档 (Virtual Document)** 技术，将内嵌的 CSS/JS 路由给专门的 LSP 服务。

```
HTML 文件:
  ...
  45: <style>
  46:   .container { width: 100%; }  <-- 虚拟文档行 1
  47: </style>
  48: <script>
  49:   console.log("Hello")         <-- 虚拟文档行 1
  50: </script>

编辑器请求:
  请求位置 (50, 5) -> 偏移计算 -> 发送给 JS LSP (1, 5)
  JS LSP 返回补全 -> 偏移反算 -> 展示在 (50, 5)
```

### 3.3 结构化编辑体验
区别于纯文本编辑器，Lumi 需要理解 DOM 结构。
- **TagMatcher**：基于 Tree-Sitter 或自定义扫描，快速定位对应的开/闭标签。
- **TagRenamer**：使用多光标技术，一处修改，处处同步。
- **Autoclosing**：不仅补全 `</tag>`，还要处理光标位置、属性补全时的 `=""` 智能插入。

---

## 四、核心模块实施详情

### 4.1 LSP 集成 (`HTMLEditorPlugin/LSP/`)

#### 4.1.1 `HTMLServiceManager.swift`

**职责**：管理 HTML 语言服务器的生命周期。

**集成方案**：
- 使用 `vscode-html-languageserver`（基于 Node）或 Swift 原生实现 `HTMLLanguageServer`（轻量级，推荐用于 macOS 原生编辑器）。
- 若采用原生实现，需自行维护 HTML5 元素/属性字典。
- **能力路由**：
  - `textDocument/completion`: 标签名、属性名、属性值（如 input type, a target）。
  - `textDocument/hover`: 显示元素描述。
  - `textDocument/formatting`: 基础格式化（缩进、换行）。

#### 4.1.2 `HTMLDiagnosticAggregator.swift`

**职责**：过滤无效噪音。
- 忽略 HTML5 允许的松散语法报错（如非自闭合 `<img>`）。
- 仅保留关键结构错误（如 `<div>` 内非法嵌套 `<tr>`）。

### 4.2 Emmet 引擎 (`HTMLEditorPlugin/Emmet/`)

#### 4.2.1 `EmmetEngine.swift`

**职责**：解析 Emmet 缩写并生成 HTML/CSS 代码。

**核心逻辑**：
```
输入: "div.box>ul>li.item$*3>a{Link}"
解析:
  - 元素: div
  - 类: box
  - 子级: ul > li*3 > a
  - 属性/文本: class="item1", text="Link"
输出:
<div class="box">
  <ul>
    <li class="item1"><a href="">Link</a></li>
    <li class="item2"><a href="">Link</a></li>
    <li class="item3"><a href="">Link</a></li>
  </ul>
</div>
```

**支持模式**：
- **HTML/JSX**: 生成标签树。
- **CSS/SCSS**: 生成属性声明 (`m10` -> `margin: 10px;`).
- **XSL**: 兼容 XML 格式。

### 4.3 结构化编辑 (`HTMLEditorPlugin/Structure/`)

#### 4.3.1 `TagMatcher.swift`

**职责**：定位匹配标签。

**算法选择**：
1. **Tree-Sitter (首选)**：直接查询语法树节点，准确率 100%，性能高。
2. **栈扫描 (降级)**：向前/向后扫描，维护开闭标签栈，寻找匹配项。

#### 4.3.2 `TagRenamer.swift`

**职责**：实现联动重命名。

**交互流程**：
1. 用户聚焦在 `<div>` 上。
2. 修改 "div" 为 "section"。
3. `TagRenamer` 监听编辑，找到闭标签 `</div>`。
4. 实时更新闭标签为 `</section>`，并保持光标同步。

#### 4.3.3 `AutoclosingController.swift`

**职责**：智能闭合逻辑。

**规则库**：
- **自闭合标签**：`br`, `hr`, `img`, `input`, `meta`, `link` 等。
  - 输入 `<br` -> 空格/回车 -> `<br />`。
- **普通标签**：`div`, `p`, `span`, `h1` 等。
  - 输入 `<div` -> 回车/空格 -> `<div></div>` (光标在中间)。
- **JSX 模式**：所有标签必须显式闭合。

### 4.4 内嵌语言协调 (`HTMLEditorPlugin/Embedded/`)

#### 4.4.1 `LanguageShunter.swift`

**职责**：根据光标位置切换语言上下文。

**区域识别逻辑**：
- 扫描 `<script` ... `</script>` 区域 -> 标记为 `language=javascript/typescript`。
- 扫描 `<style` ... `</style>` 区域 -> 标记为 `language=css/scss/less`。
- 处理 `type="text/javascript"` 或 `lang="scss"` 属性。

#### 4.4.2 `OffsetMapper.swift`

**职责**：虚拟文档偏移量映射。

**实现细节**：
- 维护一个 `RangeMap`，记录内嵌语言区域在源文件中的 `StartOffset` 和 `EndOffset`。
- 当编辑器请求 (Line 50, Col 10) 时，查询映射表：
  - 若在某区域内 -> 转换为 (VirtualLine, VirtualCol)。
  - 若不在区域内 -> 请求 HTML LSP。

---

## 五、与现有内核/插件的对接点

### 5.1 必须对接的内核模块

| 内核模块 | 对接方式 | 说明 |
|---------|---------|------|
| `EditorExtensionRegistry` | 注册 `EditorLanguageContributor` | 声明 `.html`/`.htm` 文件类型 |
| `EditorExtensionRegistry` | 注册 `EditorEmmetContributor` | 接入全局 Emmet 管线 |
| `EditorExtensionRegistry` | 注册 `EditorAutoClosingContributor` | 接管自动闭合逻辑 |
| `LSPService` | 启动 HTML Language Server | 提供基础补全和诊断 |
| `CodeEditLanguages` | 注册 HTML Tree-Sitter grammar | 结构化分析基础 |
| `KeyboardEventDispatcher` | 监听 `Tab` 键 | 触发 Emmet 展开 |

### 5.2 与 JSEditorPlugin / CSSEditorPlugin 的关系

HTML 插件是 **基础设施**，JS 和 CSS 插件是 **能力扩展**。

| 场景 | 责任归属 |
|------|----------|
| 纯 `.html` 文件 | `HTMLEditorPlugin` 全权负责 |
| 内嵌 `<style>` | `HTMLEditorPlugin` 负责分流，`CSSEditorPlugin` 提供 LSP 服务 |
| 内嵌 `<script>` | `HTMLEditorPlugin` 负责分流，`JSEditorPlugin` 提供 LSP 服务 |
| `.vue` / `.svelte` | 由专门的框架插件负责（或复用 HTML 的 Shunting 逻辑） |

### 5.3 HTMLEditorPlugin 独有的内容

| 模块 | 说明 |
|------|------|
| Emmet 引擎本地化 | 毫秒级展开，不依赖网络/进程 |
| TagMatcher / TagRenamer | DOM 结构感知编辑 |
| 内嵌语言偏移映射 | 解决“文件中文件”的坐标问题 |
| 路径补全 | 智能提示本地文件路径 (`href`, `src`) |

---

## 六、分阶段实施计划

### Phase 1: 基础结构与 Emmet（P0）
**目标**：实现核心编辑体验，Emmet 可用。
| 任务 | 文件 | 验收标准 |
|------|------|---------|
| HTML LSP 配置 | `HTMLServiceManager.swift` | 基础补全、属性提示正常 |
| Emmet 引擎集成 | `EmmetEngine.swift` | 缩写展开 (div>ul>li) 正常 |
| Emmet Tab 触发 | `EmmetExpansionHandler.swift` | 按 Tab 展开，不冲突 |
| 自动闭合 | `AutoclosingController.swift` | `<div>` 自动补全 `</div>` |
| Tree-Sitter 注册 | `HTMLTreeSitterRegistration.swift` | 语法高亮、代码折叠正常 |
**预计工作量**：1-2 周

### Phase 2: 结构化编辑增强（P0-P1）
**目标**：提升 DOM 编辑效率。
| 任务 | 文件 | 验收标准 |
|------|------|---------|
| 匹配标签高亮 | `TagHighlighter.swift` | 光标在标签上时，配对标签高亮 |
| 联动重命名 | `TagRenamer.swift` | 改开标签，闭标签同步修改 |
| 路径补全 | `HTMLPathCompletion.swift` | `src="..."` 时提示文件 |
| 诊断优化 | `HTMLDiagnosticAggregator.swift` | 减少误报 |
**预计工作量**：1 周

### Phase 3: 内嵌语言支持（P0）
**目标**：打通 HTML + CSS/JS 的协作。
| 任务 | 文件 | 验收标准 |
|------|------|---------|
| 区域识别 | `LanguageShunter.swift` | 识别 `<script>` / `<style>` 区域 |
| 偏移量映射 | `OffsetMapper.swift` | 坐标映射准确 |
| 内嵌 LSP 路由 | `EmbeddedCSSService.swift` | `<style>` 内 CSS 补全生效 |
| 内嵌 LSP 路由 | `EmbeddedJSService.swift` | `<script>` 内 JS 补全生效 |
**预计工作量**：2 周

### Phase 4: 高级体验（P1-P2）
**目标**：锦上添花的可视化功能。
| 任务 | 文件 | 验收标准 |
|------|------|---------|
| 颜色预览 | `ColorPreviewView.swift` | `style="color:#f00"` 显示色块 |
| 颜色选择器 | `ColorPickerInlineView.swift` | 点击色块弹出选择器 |
| ARIA 辅助 | `ARIAAttributeDatabase.swift` | 无障碍属性提示 |
| CSS 类名联动 | (与 CSSEditorPlugin 协作) | `class="..."` 提示 CSS 定义 |
**预计工作量**：1-2 周

---

## 七、风险与应对

| 风险 | 影响 | 应对策略 |
|------|------|---------|
| Emmet 展开与 Tab 键冲突 | 代码缩进失效 | 智能判断：若有有效缩写则展开，否则保留 Tab 缩进 |
| 内嵌语言偏移计算错误 | 补全位置错乱 | 严格测试边界情况 (多行注释/嵌套脚本)，使用单元测试覆盖 |
| HTML LSP 启动慢 | 首次补全延迟 | 预加载 HTML 字典，LSP 异步接管 |
| 非标准 HTML (模板字符串) | 解析失败 | 基于 Tree-Sitter 的容错解析，降级为纯文本模式 |

---

## 八、验收标准

### 8.1 基础验收（Phase 1 完成后）
- [ ] 打开 `.html` 文件，语法高亮正常
- [ ] 输入 `<div` 自动闭合为 `<div></div>`
- [ ] 输入 `ul>li*3` 按 Tab 展开为完整结构
- [ ] 基础标签和属性补全正常

### 8.2 结构验收（Phase 2 完成后）
- [ ] 光标在标签名上，对应标签高亮
- [ ] 修改开标签，闭标签同步更新
- [ ] 输入 `src="/` 提示项目文件

### 8.3 内嵌验收（Phase 3 完成后）
- [ ] 在 `<style>` 中输入 `color` 有 CSS 补全
- [ ] 在 `<script>` 中输入 `console` 有 JS 补全
- [ ] 补全项位置与输入光标对齐

### 8.4 体验验收（Phase 4 完成后）
- [ ] 颜色值旁边显示预览色块
- [ ] ARIA 属性有辅助说明
- [ ] CSS 类名补全能关联到 CSS 文件定义

---

## 九、总结

HTMLEditorPlugin 的核心在于 **"不只是文本，更是结构"**。

- **Emmet 是灵魂**：没有 Emmet，HTML 编辑器就失去了 50% 的竞争力。
- **结构是基础**：联动重命名和标签高亮是区别于记事本的关键。
- **内嵌是桥梁**：HTML 是 Web 开发的容器，打通 CSS/JS 的上下文是必由之路。

实现本方案后，Lumi 将具备 **专业级前端 HTML 编辑能力**，并与后续规划的 JS/CSS 插件形成完整的 Web 开发套件。
