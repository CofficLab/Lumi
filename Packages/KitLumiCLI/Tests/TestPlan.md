# TestPlan — KitLumiCLI

## 包概述

KitLumiCLI `lumi` 命令行工具的安装包。负责挑选安装目录、生成脚本、写入磁盘与查询安装状态。

平台: macOS 14+
测试文件: 5 个，用例总数: 38

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `CLIInstallTarget`
- `CLIInstallOutcome`
- `CLIPathResolver`
- `CLIScriptBuilder`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **CLIEncodingConsistency**（4 条）：由 `scriptEncodingIsReversibleByApp`、`appEncodingIsReversibleByApp`、`scriptEncodingIsAcceptedByURLComponents` 等用例锁定；改动该模块时优先跑对应测试文件。
- **CLIInstallTargetResolver**（9 条）：由 `prefersWritablePathDirectory`、`excludesNonWritablePathDirectory`、`excludesMissingPathDirectory` 等用例锁定；改动该模块时优先跑对应测试文件。
- **CLIInstaller**（9 条）：由 `installCreatesExecutableScript`、`installReportsNotOnPath`、`installFailsForNonWritableTarget` 等用例锁定；改动该模块时优先跑对应测试文件。
- **CLIPathResolver**（6 条）：由 `parsesPathEntries`、`parsesEmptyPath`、`resolvedPathContainsSystemDirectories` 等用例锁定；改动该模块时优先跑对应测试文件。
- **CLIScriptBuilder**（10 条）：由 `scriptStartsWithShebang`、`defaultCommandNameIsLumi`、`usesExistingOpenProjectProtocol` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | CLIEncodingConsistency | 脚本编码可被 App 还原 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `scriptEncodingIsReversibleByApp` |
| 2 | CLIEncodingConsistency | App 自身构造的 URL 可被自己解析回来 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `appEncodingIsReversibleByApp` |
| 3 | CLIEncodingConsistency | 脚本产出的编码是合法的 URL query | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `scriptEncodingIsAcceptedByURLComponents` |
| 4 | CLIEncodingConsistency | 脚本中的 perl 编码表达式与测试中的一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `scriptUsesSameEncoderAsTest` |
| 5 | CLIInstallTargetResolver | PATH 中已存在且可写的目录排在最前 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `prefersWritablePathDirectory` |
| 6 | CLIInstallTargetResolver | 不可写的 PATH 目录被排除 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `excludesNonWritablePathDirectory` |
| 7 | CLIInstallTargetResolver | PATH 中不存在的目录被排除 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `excludesMissingPathDirectory` |
| 8 | CLIInstallTargetResolver | ~/.local/bin 始终作为兜底候选 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `alwaysOffersUserLocalBin` |
| 9 | CLIInstallTargetResolver | 没有 HOME 时不产生用户级候选 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `omitsUserTargetWithoutHome` |
| 10 | CLIInstallTargetResolver | bestTarget 优先返回已在 PATH 中的可写目录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bestTargetPrefersOnPath` |
| 11 | CLIInstallTargetResolver | 重复的 PATH 条目只产生一个候选 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `deduplicatesPathEntries` |
| 12 | CLIInstallTargetResolver | scriptURL 指向目标目录下的命令名 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `scriptURLPointsIntoDirectory` |
| 13 | CLIInstaller | 安装后脚本存在且可执行 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `installCreatesExecutableScript` |
| 14 | CLIInstaller | 安装到不在 PATH 中的目录时返回 installedButNotOnPath | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `installReportsNotOnPath` |
| 15 | CLIInstaller | 写入不可写目录时安装失败 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `installFailsForNonWritableTarget` |
| 16 | CLIInstaller | 安装到不存在的目录时自动创建 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `installCreatesMissingDirectory` |
| 17 | CLIInstaller | 未安装时状态为未安装 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `statusReportsNotInstalled` |
| 18 | CLIInstaller | 安装后状态能查到脚本路径 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `statusFindsInstalledScript` |
| 19 | CLIInstaller | 卸载后脚本被删除 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `uninstallRemovesScript` |
| 20 | CLIInstaller | 未安装时卸载也算成功 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `uninstallSucceedsWhenNotInstalled` |
| 21 | CLIInstaller | 安装的脚本内容包含 LUMI_APP 与 open-project 协议 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `installedScriptContentIsExpected` |
| 22 | CLIPathResolver | PATH 字符串按冒号拆分并去掉空项 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesPathEntries` |
| 23 | CLIPathResolver | 空 PATH 得到空列表 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `parsesEmptyPath` |
| 24 | CLIPathResolver | 解析出的用户 PATH 包含系统目录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resolvedPathContainsSystemDirectories` |
| 25 | CLIPathResolver | 解析用户 PATH 优先于进程 PATH | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resolvedPathPrefersUserShellPath` |
| 26 | CLIPathResolver | SHELL 无效时回落到进程 PATH | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `fallsBackToProcessPathWithInvalidShell` |
| 27 | CLIPathResolver | shell 解析不会挂起 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resolutionTerminatesPromptly` |
| 28 | CLIScriptBuilder | 脚本以 shebang 开头且带执行权限语义 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `scriptStartsWithShebang` |
| 29 | CLIScriptBuilder | 命令名默认为 lumi | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultCommandNameIsLumi` |
| 30 | CLIScriptBuilder | 脚本复用 Lumi 既有的 open-project 协议 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `usesExistingOpenProjectProtocol` |
| 31 | CLIScriptBuilder | 脚本显式用 open -g -a 指定 App | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `usesExplicitAppRouting` |
| 32 | CLIScriptBuilder | 脚本不修改用户的 shell 配置 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `doesNotModifyShellConfiguration` |
| 33 | CLIScriptBuilder | 脚本优先使用 LUMI_APP 环境变量 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `honorsAppPathEnvironmentVariable` |
| 34 | CLIScriptBuilder | 安装时记录的 App 路径被写入脚本 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `embedsRecordedAppPath` |
| 35 | CLIScriptBuilder | 未提供 App 路径时使用常见安装位置兜底 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fallsBackToCommonInstallLocations` |
| 36 | CLIScriptBuilder | scheme 从 App 的 Info.plist 读取并有兜底值 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readsSchemeFromInfoPlist` |
| 37 | CLIScriptBuilder | 生成的脚本通过 shell 语法检查 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `generatedScriptIsValidShell` |
| 38 | CLIInstallTargetResolver | PATH 中缺失的 `~/.local/bin` 仍作为可写兜底候选（**回归 #945**） | `HOME` 下 `.local/bin` 不存在，PATH 包含该路径 | 解析候选目录与 `bestTarget` | 候选包含该目录，`isOnPath` 与 `isWritable` 均为 true，`bestTarget` 返回它 | P1 | ✅ 已覆盖 | `missingUserPathDirectoryStillFallsBackToUserTarget` |

> 说明：全部 **38 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 2 / 2
- P1: 已覆盖 34 / 34
- P2: 已覆盖 2 / 2
- **合计: 38 / 38**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（2 条）
- **P1**: 其余功能性用例（34 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（2 条）

## 跨平台说明

- Package 声明: macOS 14+
- 38 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/KitLumiCLI
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
