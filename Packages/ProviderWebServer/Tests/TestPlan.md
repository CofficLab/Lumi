# TestPlan — ProviderWebServer

## 包概述

ProviderWebServer 的实现包，包含 5 个主要类型；当前测试覆盖 12 条用例。

平台: macOS 14+, iOS 17+
测试文件: 2 个，用例总数: 12

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `DefaultWebServerProviding`
- `HTTPMethod`
- `WebRequestActivity`
- `WebRouteRequest`
- `WebServerEvent`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **DefaultWebServerProviding**（6 条）：由 `emitsServerEvents`、`emitsActivityAfterHandlingRoute`、`registerReplaceUnregister` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（6 条）：由 `requestActivityClassification`、`httpMethodRawValues`、`requestDecodesBody` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | DefaultWebServerProviding | 运行状态和路由变化会发出语义事件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `emitsServerEvents` |
| 2 | DefaultWebServerProviding | 命中路由后发出包含归属插件的活动事件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `emitsActivityAfterHandlingRoute` |
| 3 | DefaultWebServerProviding | 按插件注册/替换/注销路由 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registerReplaceUnregister` |
| 4 | DefaultWebServerProviding | 匹配 :param 占位符并区分 404/405 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `routeMatching` |
| 5 | DefaultWebServerProviding | start/stop 状态切换且可重复调用 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `startStop` |
| 6 | DefaultWebServerProviding | 可作为 any WebServerProviding 使用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `providerAsExistential` |
| 7 | 综合 | 请求活动区分写操作与成功状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `requestActivityClassification` |
| 8 | 综合 | HTTPMethod rawValue 与 HTTP 方法一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `httpMethodRawValues` |
| 9 | 综合 | WebRouteRequest 可构造并解码 JSON body | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `requestDecodesBody` |
| 10 | 综合 | WebRouteResponse 工厂方法 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `responseFactories` |
| 11 | 综合 | WebRoute 可创建并携带描述 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `webRouteConstruction` |
| 12 | 综合 | WebServerProviding 可注册实现并通过协议访问 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `providerAccessibleThroughProtocol` |

> 说明：全部 **12 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 1 / 1
- P1: 已覆盖 10 / 10
- P2: 已覆盖 1 / 1
- **合计: 12 / 12**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（1 条）
- **P1**: 其余功能性用例（10 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 12 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/ProviderWebServer
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
