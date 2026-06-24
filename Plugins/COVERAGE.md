# 插件纯逻辑单元测试覆盖率报告

量化方法：`Plugins/coverage_report.sh <Plugin>` → `swift test --enable-code-coverage`
+ `xcrun llvm-cov report`，仅统计各插件自身 `Sources/` 下的文件，排除 SwiftUI/AppKit 视图。

> 说明：UI（视图）按需求暂不纳入；SYSTEM-IO（单例、网络、文件系统、IOKit、shell 调用）不追求
> 高覆盖率。下表聚焦「纯逻辑」文件（解析、校验、计算、格式化、状态机）。

## 本轮新增测试后，代表性插件的纯逻辑覆盖率

| 插件 | 关键纯逻辑文件 | 行覆盖率 |
|---|---|---|
| AgentRAGPlugin | RAGMathUtils.swift | **100%** |
| AgentRAGPlugin | RAGPathUtils.swift | **100%** |
| AgentRAGPlugin | RAGTextUtils.swift | **100%** |
| AgentRAGPlugin | RAGChunker.swift | **97.73%** |
| AgentRAGPlugin | RAGFileScanner.swift (shouldSkipPath) | 92.86% |
| IdleTimePlugin | Models/RestWindow.swift | **93.33%** |
| IdleTimePlugin | Services/RestWindowInferencer.swift | **90.00%** |
| IdleTimePlugin | Models/IdleActivityEvent.swift | **100%** |
| IdleTimePlugin | Models/IdleInferenceSnapshot.swift | **100%** |
| ModelSelectorPlugin | Services/ModelSelectorFormatService.swift | **100%** |
| ModelSelectorPlugin | Models/ModelPerformanceStats.swift | **100%** |
| ModelSelectorPlugin | Services/ModelSelectorStatsService.swift | **96.34%** |
| GitPlugin | Models/GitDiffModels.swift（含 diff 计数） | 47.92% |
| GitPlugin | Services/GitBranchService.swift（validateBranchName） | 62.07% |

整插件「纯逻辑」合计行覆盖率（含仍难测的时钟/缓存类）：
- IdleTimePlugin：**70.66%**
- ModelSelectorPlugin：**79.28%**
- AgentRAGPlugin：32.90%（被 `RAGCache` 的 TTL/LRU 时钟逻辑拖低，其余纯逻辑均 ≥90%）

## 工具用法

```bash
cd Plugins
./coverage_report.sh AgentRAGPlugin          # 跑测试并打印纯逻辑覆盖率表
./coverage_report.sh IdleTimePlugin -- --filter "RestWindowContainsTests"
```

输出会逐文件给出 `LINES / COVERED / %`，并在末尾汇总「pure-logic」合计覆盖率，
可据此量化每次补测带来的提升。

## 本轮发现并修复的真实 Bug

1. **MemoryPlugin `sanitizeProjectPath`** — 哈希折叠进 `UInt8`（仅 256 桶），
   不同项目目录碰撞、共享记忆目录，造成跨项目记忆串扰。改用 FNV-1a 64 位哈希。
2. **AgentRAGPlugin `tokenize`** — CJK 属于 `alphanumerics`，被并入相邻 ASCII 词
   （`"swift代码"` 变单 token），中文检索失效。改为遇 CJK 先冲刷缓冲再单字成词。
3. **AppStoreConnectPlugin `ConnectCacheInvalidator`** — `A || B && C` 被解析为
   `A || (B && C)`，任何含 `/appScreenshotSets` 的缓存项被无条件失效。加括号修正。
4. **DiskManagerPlugin 既有测试** — 引用已删除的插件 API，整个测试目标无法编译；
   修正到当前 `LumiPlugin` 协议。

每个 bug 均配有回归测试。
