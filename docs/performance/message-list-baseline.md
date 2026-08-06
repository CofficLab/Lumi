# Message List Performance Baseline

> 归属：`MessageListAppKitPlugin` 性能验收（Task 1 / Task 15）。
> 本文件记录当前 SwiftUI `MessageListPlugin` 的基线测量结果，以及原生
> AppKit 版本必须达到的绝对目标。实际测量在 Task 15 用 Instruments 完成，
> 测量设备与结果在本文件中追加记录。

## 验收目标（绝对门槛）

以下目标来自 `docs/plans/2026-08-06-message-list-appkit-plugin.md` §1，
所有测量在**同一台机器**上对 SwiftUI 基线与本插件各做一遍。

| 指标 | 目标 |
|---|---|
| 60 Hz 滚动（300 行混合 Markdown，10s 自动滚动） | p95 帧时间 < 16.7 ms，p99 < 33 ms，>100 ms 卡顿 = 0 次 |
| 120 Hz 滚动（扩展目标） | p95 帧时间 < 8.3 ms |
| 常驻行视图数 | 仅可见行 + 少量预取边距，普通视口 < 30 个 cell |
| 重复滚动 | 不得重新解析未变更的 Markdown，不得重算未变更的行高 |
| 1000 行压力 fixture | 增量内存 < 250 MB；3 轮完整滚动后内存不再增长 |
| 单条 status/streaming 更新 | 只更新 1 行，禁止整体 `reloadData()` |
| 布局失效范围 | 宽度/主题/verbosity/内容变化只失效受影响条目 |

## 测量场景

1. 初始加载（40 行首屏）
2. 300 行持续滚动
3. 前置插入（加载更早消息，prepend）
4. status 行替换
5. V2 流式（streaming tail）
6. 会话切换
7. 主题切换

## 记录字段

每次测量记录：cell 实例数、布局缓存命中率、解析次数、高度测量次数、
主线程占用时间、帧时间分布（p95/p99/max，不允许用平均值掩盖卡顿）、内存峰值。

## SwiftUI 基线（占位，Task 15 填充）

| 场景 | p95 | p99 | max | cell 数 | 缓存命中 | 内存 |
|---|---|---|---|---|---|---|
| 初始加载 | — | — | — | — | — | — |
| 300 行滚动 | — | — | — | — | — | — |
| … | — | — | — | — | — | — |

## 测量环境

- 设备：_（待填：型号 / macOS 版本 / 芯片）_
- 工具：Instruments（Time Profiler / Core Animation / Allocations / Leaks）+ `os_signpost`
- 日期：_（待填）_

## 诊断基础设施（Task 15 完成）

`AppKitMessageListMetrics`（`Sources/Diagnostics/AppKitMessageListMetrics.swift`）
为以下热路径提供 `os_signpost` 区间：

| Signpost | 类别 | 含义 |
|---|---|---|
| `snapshot-build` | snapshot | 构造不可变快照 |
| `snapshot-apply` | snapshot | 将快照差异应用到 NSTableView |
| `cell-configure` | cell | 为一条行配置 cell（含 rowID） |
| `cell-reuse` | cell | `prepareForReuse` 重置 |
| `markdown-parse` | markdown | Markdown 块/内联解析 |
| `height-measure` | layout | 行高测量（含 rowID） |
| `syntax-highlight` | render | 代码块语法高亮 |
| `mermaid-render` | render | Mermaid 图表异步渲染 |
| `scroll-hitch` | scroll | 滚动期间的卡顿区间 |

`Counters` 单例提供内存诊断计数器（缓存命中/未命中等）。

`AppKitMessageListPerformanceTests` 自动化了下列门槛：

- 40 / 300 / 1000 行快照构造时间 < 500 / 1000 / 1000 ms
- 分页保持初始页面 40 行（即使总消息数达 1000）
- 布局缓存：相同 key 第二次命中
- 重复 refresh 后行数稳定
- 会话切换 < 500 ms

## 结论

（Task 16 替换前，由本文件给出 AppKit 版本是否通过全部门槛的结论。）

