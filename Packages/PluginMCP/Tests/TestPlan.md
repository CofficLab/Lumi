# TestPlan — PluginMCP

## 包概述

PluginMCP 让 Lumi 成为 **Cursor 式通用 MCP 客户端**：在设置中添加"MCP 服务器"入口，用户可自由添加 / 配置任意 MCP 服务器；服务器暴露的工具自动桥接进 Agent 工具列表，随会话一起审批与执行。 ## 能力 - **通用 MCP 客户端**：stdio（本地子进程）与 Streamable HTTP 两种传输； - **Cursor 式设置页**：服务器列表、添加/编辑表单、内置模板（Xcode native 等）、工具清单与风险徽标、全局开关； - **工具桥接**：MCP 工具 → `SuperAgentTool`，注册进 `ToolManagerProviding`（归属本插件），LLM 可直接调用； - **风险分级**：默认分级表 + 未知工具默认 `high` + 单工具风险覆盖 + 注解启发（`readOnlyHint` / `destructiveHint`）； - **安全默认**：第三方服务器 = 本机任意代码执行面，添加时强提示；默认不自动连接。

平台: macOS 14+
测试文件: 4 个，用例总数: 23

核心组件（源码目录）:
- `Managers/`
- `Models/`
- `Providers/`
- `Support/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `MCPPlugin`
- `MCPServerConnectionState`
- `MCPServerRegistry`
- `MCPPermissionPolicy`
- `MCPToolAdapter`
- `MCPServerContributor`
- `MCPText`
- `MCPSettingsView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **MCPLocalization**（3 条）：由 `zhHansResolves`、`connectionStateKeys`、`miscKeys` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MCPPermissionPolicy**（6 条）：由 `xcodeExactTable`、`unknownDefault`、`overrideWins` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MCPServerRegistry**（7 条）：由 `seedsPreset`、`crud`、`persistenceRoundTrip` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MCPToolAdapter**（7 条）：由 `bridgeShape`、`riskLevels`、`executionCapability` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | MCPLocalization | xcstrings 中文翻译命中（简体） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `zhHansResolves` |
| 2 | MCPLocalization | 连接状态文案走本地化 key（不再硬编码中文） | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `connectionStateKeys` |
| 3 | MCPLocalization | 工具计数与风险等级文案翻译 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `miscKeys` |
| 4 | MCPPermissionPolicy | Xcode 精确规则表逐项匹配（本机 27.0 实测 54 工具） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `xcodeExactTable` |
| 5 | MCPPermissionPolicy | 未知工具默认 high，可配置 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `unknownDefault` |
| 6 | MCPPermissionPolicy | 用户覆盖优先于一切规则 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `overrideWins` |
| 7 | MCPPermissionPolicy | 注解启发：破坏性优先 high，只读 safe | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `annotations` |
| 8 | MCPPermissionPolicy | 名称关键词启发 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `heuristics` |
| 9 | MCPPermissionPolicy | 危险词优先于只读词（同一名称含两个特征） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `dangerBeforeRead` |
| 10 | MCPServerRegistry | 贡献的内置预设（Xcode 与 GitHub）以禁用态落库 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `seedsPreset` |
| 11 | MCPServerRegistry | CRUD：新增 / 更新 / 删除 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `crud` |
| 12 | MCPServerRegistry | 持久化往返：重建实例后状态一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `persistenceRoundTrip` |
| 13 | MCPServerRegistry | 重复初始化不重复写入贡献预设 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `noDuplicateSeed` |
| 14 | MCPServerRegistry | 加载时按 id 去重（自愈历史重复数据） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `loadDeduplicatesById` |
| 15 | MCPServerRegistry | 更新时替换全部同 id 条目，不产生重复 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `updateReplacesAllSameId` |
| 16 | MCPServerRegistry | 模拟 boot 序列：先贡献 Xcode 再贡献 GitHub，两个都应 seed | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `simulateBootContributions` |
| 17 | MCPToolAdapter | 桥接命名空间与 schema 直通 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bridgeShape` |
| 18 | MCPToolAdapter | 风险分级：策略判定与用户覆盖 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `riskLevels` |
| 19 | MCPToolAdapter | 只读工具声明并行，其余串行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `executionCapability` |
| 20 | MCPToolAdapter | executeResult 调用回传文本结果 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `executeText` |
| 21 | MCPToolAdapter | 图片结果映射为 ImageAttachment | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `executeImage` |
| 22 | MCPToolAdapter | 未连接会话调用报错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `notConnected` |
| 23 | MCPToolAdapter | mcpbridge 已知错误翻译为可操作提示 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `friendlyErrorHints` |

> 说明：全部 **23 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 4 / 4
- P1: 已覆盖 16 / 16
- P2: 已覆盖 3 / 3
- **合计: 23 / 23**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（4 条）
- **P1**: 其余功能性用例（16 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（3 条）

## 跨平台说明

- Package 声明: macOS 14+
- 23 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginMCP
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
