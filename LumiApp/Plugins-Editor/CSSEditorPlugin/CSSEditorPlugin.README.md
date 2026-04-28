# CSSEditorPlugin 实施方案

> 本方案定义 Lumi 编辑器对 CSS / Sass / Less / SCSS 等样式语言完整支持的实现路径、模块划分、可视化功能与现有内核/插件的对接点。

---

## 一、目标

使 Lumi 编辑器对样式语言提供 **高可视性、智能补全、预处理兼容** 的开发体验。

与 HTML 的“结构驱动”和 JS 的“工具链驱动”不同，CSS 插件的核心挑战在于 **属性值可视化**、**选择器优先级计算** 以及 **多预处理器（Sass/Less）的统一支持**。

| 维度 | 能力 | 优先级 |
|------|------|--------|
| **基础编辑** | 属性/值补全 (Completion) | P0 |
| **基础编辑** | 属性/值悬停提示 (Hover/MDN) | P0 |
| **基础编辑** | 颜色预览 (Inline Color Preview) | P0 |
| **基础编辑** | 颜色选择器 (Inline Color Picker) | P1 |
| **基础编辑** | 括号/引号自动配对 | P0 |
| **语言智能** | 语法诊断 (非法属性/值) | P0 |
| **语言智能** | 选择器高亮 (Highlight Selectors) | P1 |
| **语言智能** | 选择器优先级计算 (Specificity) | P2 |
| **工程能力** | CSS/SCSS/Sass/Less 混合支持 | P0 |
| **工程能力** | 格式化 (Prettier/CleanCSS) | P1 |
| **工程能力** | 路径补全 (url() 图像/字体路径) | P1 |
| **联动** | HTML/JSX Class 名跳转与查找引用 | P1 |
| **联动** | Tailwind CSS 补全支持 | P2 |

---

## 二、目录结构

遵循 `plugin-directory-rules` 规范，在 `LumiApp/Plugins-Editor/CSSEditorPlugin/` 下组织：

```
CSSEditorPlugin/
├── CSSEditorPlugin.swift                  # 插件入口（遵循 EditorFeaturePlugin）
├── CSSEditorPlugin.xcstrings              # 本地化字符串
├── README.md                              # 本实施方案文档
│
├── LSP/                                   # LSP 语言服务
│   ├── CSSServiceManager.swift           # CSS 语言服务器管理 (css-languageserver)
│   ├── SCSSServiceManager.swift          # SCSS/Sass 专属适配
│   └── LessServiceManager.swift          # Less 专属适配
│
├── Visual/                                # 可视化功能
│   ├── ColorPreviewView.swift            # 行内颜色块渲染
│   ├── ColorPickerPopover.swift          # 行内颜色选择器
│   └── SpecificityBadgeView.swift        # 选择器优先级显示 (可选)
│
├── Completions/                           # 补全增强
│   ├── CSSValueProvider.swift            # 属性值字典 (MDN 数据)
│   ├── CSSPropertyProvider.swift         # 属性名补全
│   ├── URLPathCompletion.swift           # url() 路径智能补全
│   └── TailwindCompletion.swift          # Tailwind 类名/变量补全 (若启用)
│
├── Parsing/                               # 解析与 AST
│   ├── CSSParserAdapter.swift            # 轻量级 CSS 解析 (用于高亮/跳转)
│   └── SCSSPreprocessorResolver.swift    # SCSS 变量/Mixin 引用解析
│
├── Structure/                             # 结构化编辑
│   ├── BracketMatchingController.swift   # 括号高亮与配对
│   ├── BlockFoldingController.swift      # 规则块折叠范围计算
│   └── VendorPrefixExpander.swift        # 私有前缀展开 (如 -webkit- / -moz-)
│
├── Diagnostics/                           # 诊断增强
│   ├── CSSDiagnosticAggregator.swift     # 诊断去重与过滤
│   └── UnknownPropertyLinter.swift       # 未知属性检查
│
├── Grammar/                               # Tree-Sitter 语法
│   └── CSSTreeSitterRegistration.swift    # tree-sitter-css / tree-sitter-scss / tree-sitter-less 注册
│
├── Models/                                # 数据模型
│   ├── CSSColor.swift                    # 颜色模型 (Hex/RGB/HSL/Named)
│   ├── CSSRuleBlock.swift                # 选择器/声明块模型
│   ├── CSSSelectorSpecificity.swift      # 优先级模型 (a-b-c)
│   └── CSSVariableDefinition.swift       # CSS 变量 (--custom-prop)
│
├── Services/                              # 业务服务
│   ├── CSSConfigManager.swift            # 格式化/方言配置管理
│   └── TailwindResolver.swift            # Tailwind 配置读取
│
├── ViewModels/                            # 视图模型
│   └── ColorPickerViewModel.swift
│
└── Views/                                 # SwiftUI 视图
    ├── InlineDecorationView.swift         # 行内装饰视图基类
    └── ColorSwatchView.swift             # 颜色色块视图
```

---

## 三、核心架构设计

### 3.1 多方言支持（Dialect Support）
CSS 家族不仅仅只有 CSS。插件需要支持：
- **纯 CSS**: CSS3, CSS4 (Drafts).
- **SCSS/Sass**: 变量 (`$var`), 嵌套 (Nested Rules), Mixins, 函数 (`darken()`, `lighten()`).
- **Less**: 变量 (`@var`), Mixins (`.mixin()`).

**架构策略**：
使用 `vscode-css-languageservice` 作为底层解析核心，它天然支持上述方言切换。LSP 启动时根据文件扩展名自动配置 `dataProvider` 和 `Scanner`。

### 3.2 视觉增强（Visual Enhancements）
CSS 是“所见即所得”的语言。
- **Inline Color Preview**: 在 `#f00`, `rgb(...)`, `hsl(...)`, `var(--primary)` 旁边渲染小色块。
- **Inline Color Picker**: 点击色块弹出系统颜色选择器，修改后直接更新文本。
- **Selector Highlighting**: 当光标在选择器上时，高亮所有使用该选择器的规则块。

### 3.3 智能补全与 MDN 集成
- **上下文感知补全**: 输入 `display:` -> 提示 `block`, `flex`, `grid` 等合法值。
- **MDN Hover**: 悬停属性名时，展示 MDN 描述、兼容性表格摘要。
- **URL 补全**: 输入 `url('` -> 补全项目中的静态资源。

### 3.4 Tailwind CSS 支持（现代标配）
鉴于 Tailwind 的流行，必须提供基础支持。
- 识别 `tailwind.config.js`。
- 提供 `@apply` 指令补全。
- 提供 Tailwind 变量（如 `text-xl`, `bg-blue-500`）补全。

---

## 四、核心模块实施详情

### 4.1 LSP 与方言管理 (`CSSEditorPlugin/LSP/`)

#### 4.1.1 `CSSServiceManager.swift`

**职责**：管理 CSS/SCSS/Less LSP 服务。

**配置矩阵**：
| 语言 | 扩展名 | 启动参数 | 说明 |
|------|--------|----------|------|
| **CSS** | `.css` | `--stdio` | 标准模式 |
| **SCSS** | `.scss` | `--stdio` + `scss: true` | 开启嵌套/变量解析 |
| **Sass** | `.sass` | `--stdio` + `scss: false` (缩进语法) | 较少用，需特殊处理缩进 |
| **Less** | `.less` | `--stdio` + `less: true` | 开启 Less 变量 |

**特性支持**：
- `textDocument/completion`: 属性、值、函数、变量、颜色。
- `textDocument/hover`: 属性文档、值含义。
- `textDocument/references`: 查找 CSS 变量引用。

### 4.2 可视化功能 (`CSSEditorPlugin/Visual/`)

#### 4.2.1 `ColorPreviewView.swift`

**职责**：渲染内联颜色预览。

**检测逻辑**：
1. 正则匹配颜色值: `#([0-9a-fA-F]{3,8})`, `rgb(...)`, `rgba(...)`, `hsl(...)`, 以及颜色关键字 (`red`, `blue`).
2. 解析 `var(--name)` 并在同文件中查找 `--name` 的定义值进行递归解析。
3. **渲染**：在行末或光标后插入 `Circle` (带填充色)。

#### 4.2.2 `ColorPickerPopover.swift`

**职责**：交互修改颜色。

**交互流程**：
1. 点击色块 -> 弹出 `NSColorPanel` 或 SwiftUI `ColorPicker`。
2. 用户选择新颜色。
3. 计算新颜色的 Hex/RGB 字符串。
4. 替换原文档中的颜色文本。
5. 支持格式保持（如果是 Hex 则输出 Hex，如果是 RGBA 则保留 Alpha）。

### 4.3 补全增强 (`CSSEditorPlugin/Completions/`)

#### 4.3.1 `CSSValueProvider.swift`

**职责**：提供属性值字典。

**数据源**：
- 内置 `MDN Web Docs` 属性值列表（JSON 格式）。
- **CSS Variables**: 扫描文档中定义的 `--custom-prop`，在 `var()` 补全时提示。

#### 4.3.2 `TailwindCompletion.swift`

**职责**：Tailwind 专属补全。

**实现**：
- 读取 `tailwind.config.js`。
- 提取 `theme` 配置中的工具类列表。
- 当光标位于 `@apply` 后或 HTML `class="` 中（需与 HTML 插件协作）时触发。

### 4.4 结构化与解析 (`CSSEditorPlugin/Parsing/`)

#### 4.4.1 `SCSSPreprocessorResolver.swift`

**职责**：解决 SCSS 特有的引用问题。

**核心能力**：
- **变量跳转**: `Ctrl+Click` 变量 `$primary-color` -> 跳转到定义处。
- **Mixin 跳转**: `@include mixin-name` -> 跳转到 Mixin 定义。
- **Import 解析**: 解析 `@import "variables"` -> 自动添加 `.scss` 后缀并查找 `_variables.scss` (Partial 机制)。

---

## 五、与现有内核/插件的对接点

### 5.1 必须对接的内核模块

| 内核模块 | 对接方式 | 说明 |
|---------|---------|------|
| `EditorExtensionRegistry` | 注册 `EditorLanguageContributor` | 声明 `.css`/`.scss`/`.less`/`.sass` |
| `EditorExtensionRegistry` | 注册 `EditorInlineDecorationContributor` | 注册颜色预览等行内装饰 |
| `LSPService` | 启动 CSS/SCSS Language Server | 提供基础智能提示 |
| `CodeEditLanguages` | 注册 CSS/SCSS/Less Tree-Sitter grammar | 语法高亮、折叠 |
| `KeyboardEventDispatcher` | 监听快捷键 | 触发颜色选择器/格式化 |

### 5.2 与 HTMLEditorPlugin / JSEditorPlugin 的协作

CSS 插件是 Web 开发的 **样式供给方**。

| 场景 | 责任归属 |
|------|----------|
| `.css` 文件编辑 | `CSSEditorPlugin` 全权负责 |
| HTML `<style>` 块 | `HTMLEditorPlugin` 负责上下文路由，`CSSEditorPlugin` 提供服务 |
| React `style={}` | `JSEditorPlugin` (TS) 负责对象语法补全 |
| Tailwind `class="..."` | `HTMLEditorPlugin` 负责 HTML 属性上下文，`CSSEditorPlugin` 提供 Tailwind 补全数据 |
| CSS Modules | `JSEditorPlugin` 处理 `.module.css` 导入，`CSSEditorPlugin` 处理样式文件本身 |

### 5.3 CSSEditorPlugin 独有的内容

| 模块 | 说明 |
|------|------|
| Inline Color Preview | 最直观的 CSS 编辑体验 |
| SCSS/Less 变量解析 | 预处理器核心能力 |
| 属性值字典补全 | 解决“不知道属性可以填什么”的痛点 |
| 选择器优先级显示 | 调试 CSS 覆盖问题的利器 |

---

## 六、分阶段实施计划

### Phase 1: LSP 基础与方言支持（P0）
**目标**：实现 CSS/SCSS/Less 基础编辑能力。
| 任务 | 文件 | 验收标准 |
|------|------|---------|
| CSS LSP 配置 | `CSSServiceManager.swift` | 标准 CSS 补全、诊断生效 |
| SCSS 适配 | `SCSSServiceManager.swift` | 变量、嵌套、Mixins 补全生效 |
| Less 适配 | `LessServiceManager.swift` | Less 语法支持正常 |
| Tree-Sitter 注册 | `CSSTreeSitterRegistration.swift` | 语法高亮、折叠正常 |
**预计工作量**：1-2 周

### Phase 2: 可视化与增强补全（P0）
**目标**：提升编辑直观性。
| 任务 | 文件 | 验收标准 |
|------|------|---------|
| 颜色预览 | `ColorPreviewView.swift` | 各种格式颜色均显示色块 |
| 颜色选择器 | `ColorPickerPopover.swift` | 点击修改颜色，文本同步更新 |
| 属性值补全 | `CSSValueProvider.swift` | 输入 `display:` 后提示合法值 |
| url() 路径补全 | `URLPathCompletion.swift` | 提示项目静态资源 |
**预计工作量**：2 周

### Phase 3: 预处理器深度支持（P1）
**目标**：完善 SCSS/Less 体验。
| 任务 | 文件 | 验收标准 |
|------|------|---------|
| SCSS 变量跳转 | `SCSSPreprocessorResolver.swift` | 变量/混入可跳转定义 |
| 变量引用查找 | (LSP 扩展) | 查找 `--var` 或 `$var` 引用 |
| 嵌套折叠优化 | `BlockFoldingController.swift` | SCSS 嵌套块折叠准确 |
**预计工作量**：1-2 周

### Phase 4: 生态联动（Tailwind / HTML）（P1-P2）
**目标**：融入现代 Web 工作流。
| 任务 | 文件 | 验收标准 |
|------|------|---------|
| Tailwind 配置读取 | `TailwindResolver.swift` | 识别 config.js |
| Tailwind 补全 | `TailwindCompletion.swift` | 提供常用类名补全 |
| Class 名联动 | (与 HTML 插件协作) | HTML 中输入 Class 提示 CSS 定义 |
**预计工作量**：2-3 周

---

## 七、风险与应对

| 风险 | 影响 | 应对策略 |
|------|------|---------|
| SCSS 变量解析失败 | 补全不完整 | 扫描所有 `@import` 文件，构建全局符号表 |
| Tailwind 配置庞大 | 补全卡顿 | 按需懒加载，缓存配置解析结果 |
| 颜色递归解析性能差 | 渲染延迟 | 限制递归深度 (如 3 层)，后台异步解析 |
| `url()` 路径解析错误 | 补全无效 | 基于 `baseUrl` 和文件相对路径计算，支持 Webpack alias |

---

## 八、验收标准

### 8.1 基础验收（Phase 1 完成后）
- [ ] 打开 `.css`/`.scss` 文件，语法高亮正常
- [ ] 输入属性名有补全，输入属性值有建议
- [ ] SCSS 变量 (`$var`) 补全和嵌套语法支持正常
- [ ] 基础诊断（如拼写错误）正常

### 8.2 视觉验收（Phase 2 完成后）
- [ ] `background-color: #ff0000` 旁边显示红色块
- [ ] 点击色块可修改颜色，文本实时更新
- [ ] 输入 `var(--` 提示已定义的 CSS 变量

### 8.3 进阶验收（Phase 3~4 完成后）
- [ ] `@include` 和 `@apply` 补全生效
- [ ] 变量跳转功能正常
- [ ] Tailwind 类名补全提示正确

---

## 九、总结

CSSEditorPlugin 的核心在于 **"让样式看得见，让编辑有预见"**。

- **颜色是灵魂**：Inline Color Preview/Pickr 是 CSS 编辑器区别于普通文本编辑器的标志性功能。
- **预处理是基础**：SCSS/LESS 的变量和嵌套是现代前端标配，必须完美支持。
- **Tailwind 是未来**：集成 Tailwind 补全意味着拥抱了当前最流行的 CSS 框架生态。

实现本方案后，Lumi 将具备 **专业级 CSS/样式编辑能力**，并与 HTML/JS 插件无缝拼接，形成完整的 Web 前端开发闭环。
