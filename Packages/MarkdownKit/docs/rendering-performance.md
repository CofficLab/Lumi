# MarkdownKit 渲染性能设计

面向维护本包、或将其接入高频重渲染场景(如聊天流式输出)的开发者。
描述渲染链路的成本结构、各级缓存的设计契约、可测试性模式与基准测量方法。

---

## 1. 性能模型:成本在哪里

聊天流式渲染的本质矛盾:**页面重渲染的频率远高于单个视图内容变化的频率**。
逐 token 广播、kernel `objectWillChange`、列表滚动都会驱动整页 body 重新求值,
而其中绝大多数重渲染发生时,某个代码块的文本内容并没有变。

本包的三类昂贵操作:

| 操作 | 成本量级 | 触发条件 |
|---|---|---|
| 全量 Markdown 解析 | 与全文长度线性相关 | 每个未缓存的字符串 |
| 行内 `AttributedString` 构建 | 与段落长度相关 | 每个未缓存的行内文本 |
| `NSHostingView.fittingSize` | 与内容布局复杂度相关,长代码块可达毫秒级 | 每次 `sizeThatFits` 缓存未命中 |

因此核心设计原则是:

> **昂贵的重测量必须由"内容变化"驱动,而不是由"重渲染"驱动。**
> 任何"每次 update 都失效缓存"的写法,都会把重渲染频率直接转化为主线程成本。

---

## 2. 缓存体系总览

| 缓存 | 位置 | 作用域 / 容量 | 键 | 失效条件 |
|---|---|---|---|---|
| `MarkdownBlockCache` | `MarkdownBlockRenderer.swift` | 进程级 LRU,384 | Markdown 全文 | 内容变化(键含全文) |
| `MarkdownInlineParseCache` | `MarkdownBlockRenderer.swift` | 进程级 LRU,2048 | 行内文本 | 内容变化 |
| `CodeHighlightCache` | `HighlightedCodeView.swift` | 进程级 LRU,512 | provider ID + 语言 + 代码 | 任一变化 |
| `HorizontalFittingSizeCache` | `HorizontalFittingSizeCache.swift` | **每视图实例,单槽** | 内容指纹 + 宽度分桶 | 任一变化 |

前三者是内容寻址的数据缓存(进程级共享);第四者是**测量决策缓存**(视图私有),
也是唯一需要调用方主动参与构造键的——见下节。

---

## 3. HorizontalScrollView 与测量缓存

### 3.1 组件职责

`HorizontalScrollView`(`MarkdownBlockRenderer.swift`)是仅水平滚动的
`NSScrollView` 包装,用于代码块:垂直滚轮转发给外层聊天列表,
并通过 `sizeThatFits` 向 SwiftUI 报告内容真实高度,
避免行高被 `List` 的估算截断。

### 3.2 为什么需要测量缓存

`NSHostingView.fittingSize` 是全内容布局测量,长代码块单次可达毫秒级。
SwiftUI 在每次布局协商时都会调用 `sizeThatFits`;若此时缓存未命中,
主线程就要为一段没有变化的内容付出整帧预算。

### 3.3 设计:指纹 × 宽度分桶

`HorizontalFittingSizeCache<Fingerprint: Hashable>` 是纯值类型,
只保存**最近一次**测量结果 `(fingerprint, bucketedWidth, height)`:

- **内容指纹**(`Fingerprint`):由调用方构造,标识"渲染结果的一切输入";
- **宽度分桶**:proposal.width 按 16pt 一档量化,
  容忍窗口缩放期间的小幅抖动,跨桶才重新测量。

命中条件 = 指纹一致 **且** 宽度同桶。命中时 `sizeThatFits` 直接返回缓存高度,
完全不触碰 `fittingSize`。

配套的 `updateNSView` 指纹守卫:`Coordinator.installedFingerprint` 记录
当前已安装进 `NSHostingView` 的指纹,未变化时直接跳过
`rootView` 重设——既保留测量缓存,也避免 rootView 赋值触发的内部失效。
缓存无需显式失效:`cachedHeight` 的指纹校验天然拒绝过期结果。

### 3.4 使用契约(重要)

`HorizontalScrollView` 的初始化器**强制**传入 `contentFingerprint`,
没有默认值——这是刻意的,防止调用方无意中回到"每次重渲染都重测量"的旧行为。

契约只有一条:

> **指纹必须是渲染输入的超集。**
> 渲染结果的任何输入变化都必须导致指纹变化。

- 宁可多失效(多算一次测量,只是浪费),不可漏失效(画面过期,是正确性 bug);
- 正确范例见 `HighlightedCodeView.ScrollContentFingerprint`:
  覆盖异步高亮结果、原始代码、语言、字体、高亮提供者 ID;
- 常见反例:只用代码文本当指纹——字体或主题变化时画面将保持陈旧渲染;
- 测试辅助等"内容静态不变"的场景,用一次性 `UUID()` 即可。

### 3.5 契约测试

`Tests/MarkdownKitTests/HorizontalFittingSizeCacheTests.swift` 固化两类关键语义:

| 用例 | 语义 |
|---|---|
| 不变内容连续 120 帧 update | 仅第一次测量(回归防线:旧行为是每帧测量) |
| 逐 token 追加 100 步 | 每步都失效(防止"修过头"返回过期高度) |
| 其余 | 分桶边界、桶内抖动命中、跨桶失效、store 覆盖 |

修改 `HorizontalFittingSizeCache` 或 `HorizontalScrollView` 布局逻辑前,
先确认这套契约仍然成立。

---

## 4. 可测试性模式:NSViewRepresentable 的决策抽离

`NSViewRepresentable` 的 `updateNSView` / `sizeThatFits` 需要 SwiftUI 内部
构造的 `Context`,单测无法创建,缓存命中也没有外部可观察信号。
因此直接对视图回调写单测是不可行的。

本包采用的模式:

```
纯值类型决策单元(可单测)        视图层接线(不可单测,保持薄)
┌─────────────────────────┐    ┌──────────────────────────┐
│ HorizontalFittingSizeCache│ ← │ Coordinator / updateNSView│
│ 何时命中、何时重测          │    │ 指纹比较、rootView 重设    │
└─────────────────────────┘    └──────────────────────────┘
```

决策逻辑(能否复用、何时失效)全部进纯类型,由 `@testable` 单测覆盖;
视图层只做"取指纹 → 问缓存 → 必要时测量并写回"的机械接线。

后续给 `NSViewRepresentable` 加任何缓存/节流行为时,应沿用此模式:
**先抽决策单元并写测试,再接线**。

---

## 5. 基准与回归测量

### 5.1 方法要点

测量该链路的性能时,遵守以下方法(经验来自实际对比实验):

1. **tick 内同步计时**:每次状态变更后调用 `layoutSubtreeIfNeeded()`
   强制同步布局,用 `CFAbsoluteTime` 包住整段——比帧率采样更可控;
2. **重复 ≥5 次取中位数**:单次运行方差很大(环境噪声、定时器合并),
   单次对比会得出错误结论;
3. **比较 mean 而非 total/tick 数**:runloop 拥塞时 Timer 触发会合并,
   不同运行完成的 tick 数不可比;
4. **用 os_signpost 标注测量相位**,便于 Instruments 时间轴对齐;
5. **无头采集**:`xctrace record --template 'Time Profiler' --launch <binary>`;
   注意 1ms 采样 + 启动噪声下,符号级归因可能无法区分组间差异,
   tick 级计时才是主要证据,trace 用于复核。

### 5.2 两种场景语义

| 场景 | 构造 | 测什么 |
|---|---|---|
| **内容恒定 + 无关重渲染** | markdown 固定,其他状态每 16ms 变化 | 测量缓存的隔离信号(推荐) |
| 逐 token 追加 | 每 16ms 追加内容 | 复合场景,被全量解析成本主导,不适合单点归因 |

评估"重渲染频率转化为主线程成本"类优化时,一律用第一种;
第二种用于观察解析/流式链路(属于另一个问题域)。

### 5.3 参考基线

以下为 Apple Silicon(M 系列)开发机上,400 行代码块、
8 秒 16ms 间隔无关重渲染、每版本 5 次取中位数的参考值,
量级仅供回归时对照,绝对值随硬件浮动:

| 指标(中位数) | 无指纹守卫(旧实现) | 指纹守卫 + 测量缓存 |
|---|---|---|
| 每 tick 主线程耗时 | ~2.4ms | ~0.8ms |
| 超 16ms 预算的 tick | 数次 | 0 次 |
| 最大尖刺 | 可达数百 ms | 数十 ms |

若回归测得"内容恒定场景"每 tick 耗时回到毫秒级以上,
优先怀疑指纹守卫被绕过(如新增了无条件 `rootView` 赋值路径)。

---

## 6. 陷阱清单

- **不要**在 `updateNSView` 里无条件清缓存或重设 `rootView`
  ——这会把重渲染频率直接变成测量成本(本文档讨论的核心问题);
- **不要**用渲染输入的部分子集当指纹(如只传代码文本);
- `MarkdownBlockRenderer` 的 `.task` 继承 MainActor,
  缓存未命中时的全量解析发生在主线程
  ——接入方应保证高频路径命中 `MarkdownBlockCache`;
- 进程级缓存(`MarkdownBlockCache` 等)的键含全文,
  流式场景键随内容增长而变化属预期行为,不要试图"稳定"它们。
