# TestPlan — PluginWebServer

## 包概述

PluginWebServer 的实现包，包含 2 个主要类型；当前测试覆盖 15 条用例。

平台: macOS 14+, iOS 17+
测试文件: 2 个，用例总数: 15

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `WebServerPlugin`
- `WebServerSettingsView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **WebServerPlugin**（4 条）：由 `installsServerAndRoutes`、`contributesRoutesOnReady`、`keepsCoreAndToolRoutesTogether`、`exposesRegistrar` 等用例锁定；改动该模块时优先跑对应测试文件。
- **WebRouteRegistrar**（4 条）：由 `registersRoutes`、`replacesOnSecondRegistration`、`revokesRoutes`、`aggregatesByPlugin` 锁定。
- **WebRouteContributionHost**（7 条）：由 `publishesRoutes`、`skipsDisabledPlugins`、`routesComeOnlineOnEnable` 等用例锁定。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | WebServerPlugin | 启动时以真实服务替换默认 WebServer Provider，并注册旧主题路由 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `installsServerAndRoutes` |
| 2 | WebRouteRegistrar | 登记端点后可读回 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registersRoutes` |
| 3 | WebRouteRegistrar | 重复登记整体替换旧端点 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `replacesOnSecondRegistration` |
| 4 | WebRouteRegistrar | 撤销后端点清空 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `revokesRoutes` |
| 5 | WebRouteRegistrar | 登记表按插件分组聚合 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `aggregatesByPlugin` |
| 6 | WebRouteContributionHost | 发布后端点下发到服务 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `publishesRoutes` |
| 7 | WebRouteContributionHost | 被禁用的插件其端点不下发 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `skipsDisabledPlugins` |
| 8 | WebRouteContributionHost | 插件启用后其端点自动上线 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `routesComeOnlineOnEnable` |
| 9 | WebRouteContributionHost | 插件禁用后其端点自动下线 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `routesGoOfflineOnDisable` |
| 10 | WebRouteContributionHost | 撤销贡献后端点下线 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `revokesContribution` |
| 11 | WebRouteContributionHost | 停止观察后不再响应启停事件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stopsObserving` |
| 12 | WebRouteContributionHost | 取消全部发布后服务上无残留路由 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unpublishesAll` |
| 13 | WebServerPlugin | 插件可声明式贡献端点并在 ready 后下发 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `contributesRoutesOnReady` |
| 14 | WebServerPlugin | 核心控制面与工具桥接的路由同时生效 | — | 在同一插件下注册控制面与工具桥接路由 | `/api/v1/status`、`/api/v1/conversations`、`/api/v1/tools` 同时存在 | P1 | ✅ 已覆盖 | `keepsCoreAndToolRoutesTogether` |
| 15 | WebServerPlugin | 插件可取得自己的路由登记器 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `exposesRegistrar` |

> 说明：全部 **15 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 0 / 0
- P1: 已覆盖 15 / 15
- P2: 已覆盖 0 / 0
- **合计: 15 / 15**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（0 条）
- **P1**: 其余功能性用例（15 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 15 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginWebServer
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
