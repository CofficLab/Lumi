# PluginProjectOverview

项目概览插件。

提供 Agent 工具，返回项目类型、顶层结构、Git 信息、清单文件、README 预览和关键文件。

## 结构

- `ProjectOverviewPlugin` — 插件主体
- `ProjectOverviewTool` — 项目概览工具
- `Sections/` — 各个分析模块（Git、结构、清单、README 等）

## 测试

```bash
cd Packages/PluginProjectOverview
swift test
```
