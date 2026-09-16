# PluginProjectOverview

项目概览插件。

提供 Agent 工具，返回项目类型、顶层结构、Git 信息、清单文件、README 预览和关键文件。

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。

## 结构

- `ProjectOverviewPlugin` — 插件主体
- `ProjectOverviewTool` — 项目概览工具
- `Sections/` — 各个分析模块（Git、结构、清单、README 等）

## 测试

```bash
cd Plugins/PluginProjectOverview
swift test
```

