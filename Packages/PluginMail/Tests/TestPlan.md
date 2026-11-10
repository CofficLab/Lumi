# TestPlan — PluginMail

## 包概述

PluginMail 的实现包，包含 15 个主要类型；当前测试覆盖 77 条用例。

平台: macOS 14+, iOS 17+
测试文件: 8 个，用例总数: 77

核心组件（源码目录）:
- `Agent/`
- `Services/`
- `Support/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `MailPlugin`
- `MailAgentToolService`
- `MailAccountDraft`
- `MailAccountDraftError`
- `MailAccountStore`
- `MailCacheItem`
- `MailCacheService`
- `MailComposerService`
- `MailProviderPreset`
- `MailSessionManager`
- `MailSyncStats`
- `MailPluginLocalStore`
- `MailPluginRuntime`
- `MailAccountFormView`
- `MailComposeView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **MailAccountStore**（26 条）：由 `testUpsertAndLoad`、`testUpsertUpdatesExistingByID`、`testDeleteRemovesAccountAndPassword` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MailAgentTools**（11 条）：由 `testRiskLevelsAndCapabilities`、`testListMessagesWithoutAccount`、`testListMessagesReturnsRecentSummaries` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MailHTMLContent**（5 条）：由 `testUnauthorizedHTMLBlocksRemoteSubresources`、`testLinkActivatedOpensExternallyEvenWithoutAuthorization` 等用例锁定；改动阅读器远程内容策略时优先跑对应测试文件。
- **MailWorkspace**（1 条）：由 `testColdStartOfflineFallsBackToCachedInbox` 锁定；改动工作区账户/文件夹加载时优先跑对应测试文件。
- **MailComposerService**（11 条）：由 `testSendBuildsMIMEAndAppendsToSent`、`testSendThrowsAuthFailedWithoutPassword`、`testSentFolderDiscoveryPrefersSentKind` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MailSessionManager**（5 条）：由 `testSessionCachesByAccount`、`testSessionThrowsAuthFailedWhenPasswordMissing`、`testSessionThrowsAuthFailedOnBadCredentials` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MailSyncService**（11 条）：由 `testUpsertAndLastUID`、`testContainsAndOverwrite`、`testUnreadCounts` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MailPluginRuntime**（2 条）：由 `usesInjectedDirectory`、`refusesFallbackWithoutInjection` 锁定；改动数据目录解析时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | MailAccountStore | testUpsertAndLoad | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testUpsertAndLoad` |
| 2 | MailAccountStore | testUpsertUpdatesExistingByID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testUpsertUpdatesExistingByID` |
| 3 | MailAccountStore | testDeleteRemovesAccountAndPassword | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDeleteRemovesAccountAndPassword` |
| 4 | MailAccountStore | testPasswordRoundTrip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPasswordRoundTrip` |
| 5 | MailAccountStore | testStoredConfigLandsInPluginDirectoryWithoutPassword | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testStoredConfigLandsInPluginDirectoryWithoutPassword` |
| 6 | MailAccountStore | testLoadEmptyWhenNoConfigFileExists | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testLoadEmptyWhenNoConfigFileExists` |
| 7 | MailAccountStore | testPresetHostsAndPorts | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPresetHostsAndPorts` |
| 8 | MailAccountStore | testInferFromIMAPHost | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testInferFromIMAPHost` |
| 9 | MailAccountStore | testToConfigMapsTypes | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testToConfigMapsTypes` |
| 10 | MailAccountStore | testApplyPresetKeepsCustomHosts | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testApplyPresetKeepsCustomHosts` |
| 11 | MailAgentTools | testRiskLevelsAndCapabilities | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRiskLevelsAndCapabilities` |
| 12 | MailAgentTools | testListMessagesWithoutAccount | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testListMessagesWithoutAccount` |
| 13 | MailAgentTools | testListMessagesReturnsRecentSummaries | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testListMessagesReturnsRecentSummaries` |
| 14 | MailAgentTools | testReadMessageMarksAsReadAndReturnsBody | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testReadMessageMarksAsReadAndReturnsBody` |
| 15 | MailAgentTools | testSearchMessagesFindsCachedHits | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSearchMessagesFindsCachedHits` |
| 16 | MailAgentTools | testSendMessageSendsAndAppends | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSendMessageSendsAndAppends` |
| 17 | MailAgentTools | testSendMessageThrowsAuthFailedWithoutCredentials | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSendMessageThrowsAuthFailedWithoutCredentials` |
| 18 | MailComposerService | testSendBuildsMIMEAndAppendsToSent | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSendBuildsMIMEAndAppendsToSent` |
| 19 | MailComposerService | testSendThrowsAuthFailedWithoutPassword | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSendThrowsAuthFailedWithoutPassword` |
| 20 | MailComposerService | testSentFolderDiscoveryPrefersSentKind | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSentFolderDiscoveryPrefersSentKind` |
| 21 | MailComposerService | testNewModeDefaultsEmpty | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testNewModeDefaultsEmpty` |
| 22 | MailComposerService | testReplyModePrefills | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testReplyModePrefills` |
| 23 | MailComposerService | testReplyPrefixNotDuplicated | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testReplyPrefixNotDuplicated` |
| 24 | MailComposerService | testForwardModePrefills | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testForwardModePrefills` |
| 25 | MailComposerService | testSendFailureRetainsDraftState | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSendFailureRetainsDraftState` |
| 26 | MailSessionManager | testSessionCachesByAccount | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSessionCachesByAccount` |
| 27 | MailSessionManager | testSessionThrowsAuthFailedWhenPasswordMissing | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSessionThrowsAuthFailedWhenPasswordMissing` |
| 28 | MailSessionManager | testSessionThrowsAuthFailedOnBadCredentials | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSessionThrowsAuthFailedOnBadCredentials` |
| 29 | MailSessionManager | testDisconnectAndDisconnectAll | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testDisconnectAndDisconnectAll` |
| 30 | MailSessionManager | testTestConnectionDoesNotCache | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testTestConnectionDoesNotCache` |
| 31 | MailAccountStore | testDefaults | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `testDefaults` |
| 32 | MailSyncService | testUpsertAndLastUID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testUpsertAndLastUID` |
| 33 | MailSyncService | testContainsAndOverwrite | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testContainsAndOverwrite` |
| 34 | MailSyncService | testUnreadCounts | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testUnreadCounts` |
| 35 | MailSyncService | testRemoveKeepingAndPurge | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRemoveKeepingAndPurge` |
| 36 | MailSyncService | testSearchMatchesSubjectAndFrom | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSearchMatchesSubjectAndFrom` |
| 37 | MailSyncService | testIncrementalSyncInsertsNewOnly | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testIncrementalSyncInsertsNewOnly` |
| 38 | MailSyncService | testIncrementalSyncSkipsAlreadyCached | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testIncrementalSyncSkipsAlreadyCached` |
| 39 | MailSyncService | testFullSyncRemovesDeleted | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testFullSyncRemovesDeleted` |
| 40 | MailSyncService | testIncrementalSyncDoesNotDelete | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testIncrementalSyncDoesNotDelete` |
| 41 | MailSyncService | testSyncMultipleFolders | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testSyncMultipleFolders` |
| 42 | MailAccountDraft | 端口为 -1/0/65536/70000 时 toConfig 抛校验错误而非 UInt16 转换 trap | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testToConfigRejectsOutOfRangePorts` |
| 43 | MailAccountDraft | 端口边界 1 与 65535 可正常转换 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testToConfigAcceptsPortBoundaries` |
| 44 | MailAgentTools | 读取邮件 uid 超过 UInt32.max 时返回参数错误且不触达会话层 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testReadMessageRejectsUIDAboveUInt32` |
| 45 | MailAccountStore | testEmptyStringPasswordIsTreatedAsDelete | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testEmptyStringPasswordIsTreatedAsDelete` |
| 46 | MailAccountStore | testAccountsSurviveANewStoreInstance | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testAccountsSurviveANewStoreInstance` |
| 47 | MailAccountStore | testCorruptConfigIsQuarantinedAndReadsAsEmpty | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testCorruptConfigIsQuarantinedAndReadsAsEmpty` |
| 48 | MailAccountStore | testLegacyAccountsAreImportedIntoPlist | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testLegacyAccountsAreImportedIntoPlist` |
| 49 | MailAccountStore | testLegacyKeyIsClearedAfterSuccessfulMigration | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testLegacyKeyIsClearedAfterSuccessfulMigration` |
| 50 | MailAccountStore | testMigrationIsIdempotentAcrossRestarts | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testMigrationIsIdempotentAcrossRestarts` |
| 51 | MailAccountStore | testNoLegacyDataLeavesStoreEmpty | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testNoLegacyDataLeavesStoreEmpty` |
| 52 | MailAccountStore | testCorruptLegacyDataIsPreservedAndNotMarkedMigrated | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testCorruptLegacyDataIsPreservedAndNotMarkedMigrated` |
| 53 | MailAccountStore | testExistingAccountsAreNotOverwrittenByLegacyData | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testExistingAccountsAreNotOverwrittenByLegacyData` |
| 54 | MailAccountStore | testRoundTrip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testRoundTrip` |
| 55 | MailAccountStore | testPreferencesLandInPluginDirectory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPreferencesLandInPluginDirectory` |
| 56 | MailAccountStore | testPreferencesSurviveNewStoreInstance | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testPreferencesSurviveNewStoreInstance` |
| 57 | MailAccountStore | testCorruptPreferencesAreQuarantined | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testCorruptPreferencesAreQuarantined` |
| 58 | MailPluginRuntime | usesInjectedDirectory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `usesInjectedDirectory` |
| 59 | MailPluginRuntime | refusesFallbackWithoutInjection | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `refusesFallbackWithoutInjection` |
| 60 | MailAgentTools | limit 为 -1/0/51 时返回参数错误，避免 `suffix` 负数导致进程终止 | 已配置账户 | 以越界 `limit` 调用 `mail_list_messages` | 抛出 `ToolExecutionError`，错误信息指出 limit 非法 | P0 | ✅ 已覆盖 | `testListMessagesRejectsOutOfRangeLimit` |
| 61 | MailAgentTools | limit schema 声明 1...50 范围 | — | 读取 `mail_list_messages` 的 inputSchema | `minimum` 为 1、`maximum` 为 50 | P1 | ✅ 已覆盖 | `testListMessagesLimitSchemaDeclaresRange` |
| 62 | MailSyncService | 跨文件夹搜索不按裸 UID 合并结果 | INBOX 与 Archive 各有一封 uid=7 的邮件 | 不带 folder 搜索 `quarterly` | 仅返回 INBOX 的命中，Archive 同 UID 邮件不被误报 | P1 | ✅ 已覆盖 | `testSearchDoesNotMergeSameUIDAcrossFolders` |
| 63 | MailAgentTools | 会话连接失败时继续读取本地缓存并标识来源 | 缓存已有邮件，会话工厂 connect 抛错 | 调用 `mail_list_messages` | 返回缓存邮件，且提示内容来自本地缓存 | P1 | ✅ 已覆盖 | `testListMessagesFallsBackToCacheWhenSessionConnectFails` |
| 64 | MailComposerService | 相同账户/模式/上下文重新创建撰写 ViewModel 时恢复草稿全部字段 | 新建模式已填写收件人/抄送/主题/正文并添加附件 | 以相同上下文再次创建 ViewModel | 收件人、抄送、主题、正文、附件与保存时间均恢复 | P1 | ✅ 已覆盖 | `testDraftRestoreRestoresAllFields` |
| 65 | MailComposerService | 草稿 JSON 损坏时回退到模式默认内容 | 草稿文件写入非法 JSON | 创建回复模式 ViewModel | 使用回复预填内容，不抛错、无保存时间 | P1 | ✅ 已覆盖 | `testCorruptDraftFallsBackToModeDefaults` |
| 66 | MailComposerService | 发送成功后删除本地草稿，再次打开不残留旧内容 | 新建模式已保存草稿，mock 发送成功 | 发送后重新创建 ViewModel | 正文为空，旧草稿不恢复 | P1 | ✅ 已覆盖 | `testSuccessfulSendClearsLocalDraft` |
| 67 | MailWorkspace | 冷启动离线时会话创建失败仍展示 INBOX 与本地缓存摘要 | 缓存已有 INBOX 邮件，会话工厂 connect 抛错 | 调用 `load()` 选择首个账户 | `isOffline` 为真，文件夹保留 INBOX，列表显示缓存邮件 | P1 | ✅ 已覆盖 | `testColdStartOfflineFallsBackToCachedInbox` |
| 68 | MailHTMLContent | 未授权时 HTML 注入 CSP，拦截全部远程子资源 | 默认 `allowsRemoteContent = false` | 生成渲染用 HTML | 含 `Content-Security-Policy` 与 `default-src 'none'`，保留内联样式 | P0 | ✅ 已覆盖 | `testUnauthorizedHTMLBlocksRemoteSubresources` |
| 69 | MailHTMLContent | 授权后不再注入限制性 CSP | `allowsRemoteContent = true` | 生成渲染用 HTML | 不含 `Content-Security-Policy`，正文原样保留 | P1 | ✅ 已覆盖 | `testAuthorizedHTMLOmitsRestrictivePolicy` |
| 70 | MailHTMLContent | 用户点击的远程链接交给系统浏览器，不被远程开关取消 | `allowsRemoteContent = false`，导航类型为 linkActivated | 请求 https 链接 | 决策为 `openExternally`，不返回 cancel | P0 | ✅ 已覆盖 | `testLinkActivatedOpensExternallyEvenWithoutAuthorization` |
| 71 | MailHTMLContent | 非用户触发的远程导航仅在授权后放行 | `.other` 类型的 https 导航 | 分别以未授权/已授权求值 | 未授权为 cancel，已授权为 allow | P1 | ✅ 已覆盖 | `testNonUserRemoteNavigationRequiresAuthorization` |
| 72 | MailHTMLContent | 本地与无 URL 导航始终放行 | `allowsRemoteContent = false` | 以 nil 与 about:blank 求值 | 均为 allow | P2 | ✅ 已覆盖 | `testLocalNavigationAlwaysAllowed` |
| 73 | MailWorkspace | 旧邮件正文晚到时不能覆盖后来点开的邮件 | INBOX 两封邮件，uid=1 的 fetchBody 延迟 300ms | 先点 uid=1，50ms 后点 uid=2，等旧任务结束 | `selectedDetail` 与 `selectedMessage` 都停留在 uid=2 | P0 | ✅ 已覆盖 | `testStaleBodyDoesNotOverrideNewerSelection` |
| 74 | MailWorkspace | 旧文件夹同步晚到不能覆盖新文件夹列表，且不能关闭新同步的转圈 | INBOX 同步延迟 300ms、Archive 延迟 900ms | 在 INBOX 同步中切到 Archive，旧同步结束后检查 | 列表为 Archive 邮件；旧同步结束时 `isSyncing` 仍为真，全部结束后为假 | P0 | ✅ 已覆盖 | `testStaleFolderSyncKeepsNewerFolderAndSpinner` |
| 75 | MailAccountDraft | 新建草稿默认 Gmail 时立即填入预设主机与端口（**回归 #1074**） | — | 调用 `MailAccountDraft.forNewAccount()` | `imap.gmail.com` / `smtp.gmail.com`，端口 993/465，启用 TLS | P1 | ✅ 已覆盖 | `testNewAccountDraftStartsWithGmailPresetHosts` |
| 76 | MailAccountDraft | 新建草稿按指定服务商应用预设 | — | 调用 `forNewAccount(provider: .outlook)` | Outlook 主机与 587 端口被填入 | P1 | ✅ 已覆盖 | `testNewAccountDraftAppliesRequestedPreset` |
| 77 | MailAccountDraft | 自定义服务商新建草稿保留空主机 | — | 调用 `forNewAccount(provider: .custom)` | IMAP/SMTP 主机为空，等待用户填写 | P1 | ✅ 已覆盖 | `testNewAccountDraftLeavesCustomHostsEmpty` |

> 说明：全部 **77 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 11 / 11
- P1: 已覆盖 62 / 62
- P2: 已覆盖 4 / 4
- **合计: 77 / 77**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（11 条）
- **P1**: 其余功能性用例（62 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（4 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 74 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginMail
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
