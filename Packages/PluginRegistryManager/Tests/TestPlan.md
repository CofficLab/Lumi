# TestPlan — PluginRegistryManager

## 包概述

RegistryManagerPlugin Manage Lumi registries

平台: macOS 14+, iOS 17+
测试文件: 1 个，用例总数: 12

核心组件（源码目录）:
- `Models/`
- `Services/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `RegistryManagerPlugin`
- `RegistryType`
- `RegistryService`
- `RegistryManagerServicing`
- `RegistryCard`
- `RegistryManagerAboutView`
- `RegistryManagerManualView`
- `RegistryManagerView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **Docker 配置合并**（4 条）：由 `dockerDaemonMergePreservesExistingKeys`、`dockerDaemonMergeRejectsUnparsableConfig` 等用例锁定；改动 daemon.json 写入逻辑时优先跑对应测试文件。
- **综合**（3 条）：由 `v2PluginMetadataIsStable`、`staleRefreshDoesNotOverwriteNewerRegistryResult`、`staleSetDoesNotOverwriteNewerRegistryChoice` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 综合 | v2PluginMetadataIsStable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `v2PluginMetadataIsStable` |
| 2 | 综合 | staleRefreshDoesNotOverwriteNewerRegistryResult | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `staleRefreshDoesNotOverwriteNewerRegistryResult` |
| 3 | 综合 | staleSetDoesNotOverwriteNewerRegistryChoice | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `staleSetDoesNotOverwriteNewerRegistryChoice` |
| 4 | Docker 配置合并 | 切换镜像源时保留 daemon.json 的其它键 | 现有配置含 debug、storage-driver、旧镜像源 | 合并新镜像源 | debug/storage-driver 保留，镜像源被替换 | P0 | ✅ 已覆盖 | `dockerDaemonMergePreservesExistingKeys` |
| 5 | Docker 配置合并 | daemon.json 无法解析时中止并抛错 | 现有文件为非法 JSON | 合并新镜像源 | 抛 `RegistryServiceError`，不返回可写数据 | P0 | ✅ 已覆盖 | `dockerDaemonMergeRejectsUnparsableConfig` |
| 6 | Docker 配置合并 | 根节点不是 JSON 对象时中止 | 现有文件内容为 `[]` | 合并新镜像源 | 抛 `RegistryServiceError` | P1 | ✅ 已覆盖 | `dockerDaemonMergeRejectsNonObjectRoot` |
| 7 | Docker 配置合并 | 文件不存在时只写入镜像源 | 无现有文件 | 合并新镜像源 | 结果仅含 registry-mirrors | P2 | ✅ 已覆盖 | `dockerDaemonMergeCreatesConfigWhenMissing` |
| 8 | Pip 入口 | 仅装 pip3 时选择 pip3，装了 pip 时仍优先 pip | 可用入口集合分别为 {pip3, python3 -m pip} 与 {pip, pip3} | 调用入口选择 | 分别得到 pip3 与 pip | P1 | ✅ 已覆盖 | `pipCommandFallsBackToPip3WhenPipIsMissing` |
| 9 | Pip 入口 | 所有入口都不可用才判定未安装，模块入口用 --version 探测 | 可用入口集合为空 | 调用入口选择与探测命令构造 | 返回 nil；`python3 -m pip` 探测命令为 `python3 -m pip --version` | P1 | ✅ 已覆盖 | `pipCommandReturnsNilOnlyWhenEveryEntryIsUnavailable` |
| 10 | 命令执行 | 命令非零退出时即使有 stdout 也抛错 | `printf 'startup-noise'; exit 7` | 调用 `RegistryService.execute` | 抛 `commandFailed`，status 为 7 且保留 stdout 文本 | P0 | ✅ 已覆盖 | `executeThrowsOnNonZeroExitEvenWithStdout` |
| 11 | 命令执行 | 命令成功时返回 stdout | `printf 'https://registry.example/'` | 调用 `RegistryService.execute` | 返回内容包含该地址 | P1 | ✅ 已覆盖 | `executeReturnsStdoutOnSuccess` |
| 12 | 命令执行 | profile 启动噪音不会被当成 registry 值 | stdout 含启动文本与目标值两行 | 调用 `RegistryService.configValue` | 只保留最后一行非空内容；全空白返回空串 | P2 | ✅ 已覆盖 | `configValueKeepsOnlyTheLastLine` |

> 说明：全部 **12 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 3 / 3
- P1: 已覆盖 6 / 6
- P2: 已覆盖 3 / 3
- **合计: 12 / 12**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（3 条）
- **P1**: 其余功能性用例（6 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（3 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 12 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginRegistryManager
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
