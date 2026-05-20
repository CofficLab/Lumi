# Project Issue Scanner

> 在空闲时自动扫描项目中的潜在问题，并在用户对话时将相关问题提示注入给 LLM。

## 工作原理

```
AppIdleTimeVM (isInRestWindow)
    ↓
ProjectIssueScannerRoot (监听空闲状态)
    ↓
IdleScannerService (调度扫描)
    ├── LocalRuleScanner  → 零成本：TODO/FIXME/空 catch/大文件
    └── DeepIssueAnalyzer → 有成本：LLM 深度分析（每日限流）
    ↓
ProjectIssueStore (JSON 持久化，插件专属目录)
    ↓
IssueHintSendMiddleware (注入 transientSystemPrompts)
```

## LLM 服务获取

插件通过 `addRootView` 返回的 `ProjectIssueScannerRoot` 视图，使用 `@EnvironmentObject` 获取 `AppLLMVM`，进而访问 `llmService` 和 `getCurrentConfig()`。

## 目录结构

```
ProjectIssueScannerPlugin/
├── ProjectIssueScannerPlugin.swift     # 插件主入口
├── ProjectIssueScanner.xcstrings       # 本地化字符串
├── Middleware/
│   └── IssueHintSendMiddleware.swift   # 注入问题提示
├── Models/
│   └── ProjectIssue.swift              # 问题模型
├── Services/
│   ├── IdleScannerService.swift        # 空闲调度器
│   ├── LocalRuleScanner.swift          # 本地规则扫描
│   ├── DeepIssueAnalyzer.swift         # LLM 深度分析
│   └── ProjectIssueStore.swift         # 问题持久化
└── Views/
    └── ProjectIssueScannerRoot.swift   # Root 视图（获取 LLM 服务）
```

## 数据存储

| 数据 | 格式 | 路径 |
|------|------|------|
| 问题列表 | JSON | `AppConfig.getDBFolderURL()/ProjectIssueScanner/issues.json` |

## 配置

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| 空闲扫描阈值 | 5 分钟 | 空闲多久后触发扫描 |
| 扫描间隔 | 30 分钟 | 两次扫描的最小间隔 |
| 每日 LLM 分析上限 | 5 次 | 控制成本 |
| 大文件行数阈值 | 500 行 | 超过此行数触发警告 |
