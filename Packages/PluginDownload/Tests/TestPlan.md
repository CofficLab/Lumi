# TestPlan — PluginDownload

## 包概述

DownloadPlugin Lumi plugin: Download file management.

平台: macOS 14+, iOS 17+
测试文件: 1 个，用例总数: 15

核心组件（源码目录）:
- `Services/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `DownloadListV2Tool`
- `DownloadPluginSupport`
- `DownloadRuntime`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **DownloadPlugin**（15 条）：由 `testPluginInfo`、`testDefaultDownloadDirectory`、`testExtractFilenameFromURL`、`testValidatedDestinationAcceptsSafeFilenames`、`testValidatedDestinationRejectsUnsafeFilenames`、`testDownloadFileRejectsTraversalFilenameWithoutWriting`、`testDownloadFileRejectsTraversalFromURLQuery` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | DownloadPlugin | testPluginInfo | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPluginInfo` |
| 2 | DownloadPlugin | testDefaultDownloadDirectory | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testDefaultDownloadDirectory` |
| 3 | DownloadPlugin | testExtractFilenameFromURL | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testExtractFilenameFromURL` |
| 4 | DownloadPlugin | testExtractFilenameFallback | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testExtractFilenameFallback` |
| 5 | DownloadPlugin | testExtractFilenameFromQueryFilenameParam | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testExtractFilenameFromQueryFilenameParam` |
| 6 | DownloadPlugin | testExtractFilenameFromQueryFileParam | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testExtractFilenameFromQueryFileParam` |
| 7 | DownloadPlugin | testExtractFilenameDecodesPercentEncodedQueryValue | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testExtractFilenameDecodesPercentEncodedQueryValue` |
| 8 | DownloadPlugin | testExtractFilenameSkipsMalformedQueryPairs | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testExtractFilenameSkipsMalformedQueryPairs` |
| 9 | DownloadPlugin | 批量 URL 分类保留无效项及其原始顺序 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testClassifyBatchURLsKeepsInvalidEntriesInOrder` |
| 10 | DownloadPlugin | 批量结果有失败项时汇总标记为部分完成 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testBatchSummaryFlagsPartialCompletion` |
| 11 | DownloadPlugin | 工具失败以抛出表达而非返回错误字符串 | 无 | 调用 `DownloadFileV2Tool` 传非法 URL、`DownloadProgressV2Tool` 缺 task_id | 均抛出 `ToolExecutionError` | P1 | ✅ 已覆盖 | `testToolsThrowForInvalidArguments` |
| 12 | DownloadPlugin | 校验接受安全的单一文件名组件 | 目录 `/tmp/lumi-downloads` | 对 `file.bin`、`my report.pdf`、`archive.zip`、`报告.pdf` 调用 `validatedDestination` | 均返回非 nil，组件名与传入一致且落在目录内 | P1 | ✅ 已覆盖 | `testValidatedDestinationAcceptsSafeFilenames` |
| 13 | DownloadPlugin | 校验拒绝非法文件名（路径穿越、分隔符、空字节） | 目录 `/tmp/lumi-downloads` | 对 `../victim`、`a/b`、`..`、`.`、空串、`/etc/passwd`、`victim/`、反斜杠名、含空字节名调用 `validatedDestination` | 全部返回 nil | P0 | ✅ 已覆盖 | `testValidatedDestinationRejectsUnsafeFilenames` |
| 14 | DownloadPlugin | download_file 拒绝穿越文件名且不写入目录外 | 临时目录 `downloads`，filename 为 `../victim` | 调用 `DownloadFileV2Tool` 传 url+filename+directory | 抛 `ToolExecutionError`，目录外无 `victim`，`downloads` 为空 | P0 | ✅ 已覆盖 | `testDownloadFileRejectsTraversalFilenameWithoutWriting` |
| 15 | DownloadPlugin | download_file 拒绝来自 URL 查询参数的穿越文件名 | 临时目录 `downloads`，url 查询 `?filename=../victim` | 不传 filename 调用 `DownloadFileV2Tool` | 抛 `ToolExecutionError`，目录外无 `victim` | P0 | ✅ 已覆盖 | `testDownloadFileRejectsTraversalFromURLQuery` |

> 说明：全部 **15 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

> 回归 #470（download_file 文件名路径穿越）变异验证：
> - M1 去掉 execute 中的 `validatedDestination` 守卫（恢复 `directory.appendingPathComponent(filename)`）→ 用例 14、15 RED（穿越名不再抛出）。
> - M2 让 `validatedDestination` 无条件返回目标（移除全部校验）→ 用例 13、14、15 RED。
> - M3 仅移除分隔符黑名单（斜杠与反斜杠）→ 用例 13 RED（`a/b` 等被接受），用例 14、15 仍 GREEN（`../victim` 被标准化包含检查拦截）。
> 三处变异各自命中对应守卫，恢复后全部 GREEN。

## 覆盖率统计

- P0: 已覆盖 3 / 3
- P1: 已覆盖 11 / 11
- P2: 已覆盖 1 / 1
- **合计: 15 / 15**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（3 条）
- **P1**: 其余功能性用例（11 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 15 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginDownload
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
