# TestPlan — PluginMail

## 包概述

PluginMail 的实现包，包含 15 个主要类型；当前测试覆盖 113 条用例。

平台: macOS 14+, iOS 17+
测试文件: 12 个，用例总数: 113

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
- **MailAgentTools**（14 条）：由 `testRiskLevelsAndCapabilities`、`testListMessagesWithoutAccount`、`testListMessagesReturnsRecentSummaries` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MailDraftAutosave**（9 条）：由 `testSaveEncodesAndWritesOffMainThread`、`testTextOnlyEditDoesNotRewriteAttachments`、`testStaleSaveDoesNotOverwriteNewerDraft` 等用例锁定；连续击键必须合并落盘、编码与写入不得占用主线程、附件只在增删时重写，晚到的旧快照不得覆盖新草稿（issue #1188）。
- **Mail account_id 校验**（9 条）：由 `invalidAccountIDIsRejectedByEveryTool`、`nonStringAccountIDIsRejected`、`unknownAccountIDIsAnErrorNotAnEmptyResult`、`validAccountIDSelectsThatAccount` 锁定；只有完全省略 account_id 才能回落到第一个账户，传了但为空/格式非法/类型不对/账户不存在都必须在任何 IMAP/SMTP 操作前报错，否则发送工具会从错误的邮箱寄信（issue #840）。
- **Mail 账户身份变更与缓存隔离**（9 条）：由 `testEmailChangeDetected`、`testIdentityChangePurgesCache`、`testDeletePurgesCache`、`testUnchangedIdentityKeepsCache` 锁定；编辑账户改变邮箱/用户名/IMAP/SMTP 主机时必须清空旧缓存，否则新邮箱会读到旧邮箱的邮件（issue #845）。
- **MailHTMLContent**（5 条）：由 `testUnauthorizedHTMLBlocksRemoteSubresources`、`testLinkActivatedOpensExternallyEvenWithoutAuthorization` 等用例锁定；改动阅读器远程内容策略时优先跑对应测试文件。
- **MailWorkspace**（7 条）：由 `testColdStartOfflineFallsBackToCachedInbox`、`testSelectMessageFetchesBodyWithoutSyncService`、`testFirstPageKeepsNewestMailsAndPagesTowardOlder` 锁定；改动工作区账户/文件夹加载、阅读取正文或列表分页排序（#308 最新优先、#842 服务器翻页）时优先跑对应测试文件。
- **MailComposerService**（12 条）：由 `testSendBuildsMIMEAndAppendsToSent`、`testSendThrowsAuthFailedWithoutPassword`、`testSentFolderDiscoveryPrefersSentKind`、`testAppendDraftUsesDraftFlag` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MailSessionManager**（5 条）：由 `testSessionCachesByAccount`、`testSessionThrowsAuthFailedWhenPasswordMissing`、`testSessionThrowsAuthFailedOnBadCredentials` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MailSyncService**（11 条）：由 `testUpsertAndLastUID`、`testContainsAndOverwrite`、`testUnreadCounts` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MailPluginRuntime**（2 条）：由 `usesInjectedDirectory`、`refusesFallbackWithoutInjection` 锁定；改动数据目录解析时优先跑对应测试文件。
- **MailPluginLifecycle**（1 条）：由 `shutdownWithoutBootDoesNotInitializeLazyServices` 锁定；改动插件生命周期/关闭清理时优先跑对应测试文件。

> **#403 变异验证**（composer 调用点，2 个独立变异均 RED）：
> 1. 把 `send()` 归档到 Sent 的 `isDraft: false` 改为 `true`（复现原 bug）→ `testSendBuildsMIMEAndAppendsToSent` 与 `mail_send_message` 工具链的 `testSendMessageSendsAndAppends` 均失败（Sent 副本被标记为草稿），`testAppendDraftUsesDraftFlag` 仍 GREEN。
> 2. 把 `appendDraft()` 的 `isDraft: true` 改为 `false` → `testAppendDraftUsesDraftFlag` 失败（草稿丢失 `\Draft`）。
> 两个变异分别锁定「Sent 归档不得带草稿标记」「草稿必须保留草稿标记」两条调用点不变量；适配层标记选择的变异见 KitMail TestPlan。恢复修复后全部 GREEN。

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
| 78 | MailPluginLifecycle | 未 boot 即 onShutdown 不初始化 lazy 服务（回归 #137） | 注入尚不存在的兜底目录、未注册 StorageProviding | 未 boot 直接 onShutdown，等待 fire-and-forget Task | 数据目录不被创建（accountStore 未初始化） | P0 | ✅ 已覆盖 | `shutdownWithoutBootDoesNotInitializeLazyServices` |
| 79 | MailWorkspace | 未注入 sync（生产装配）时点选邮件仍经 session 取正文并置已读，不得永远停在加载态（**回归 #306**） | 缓存有 INBOX 邮件，VM 不传 sync（默认 nil） | 调用 `load()` 后 `selectMessage` | `selectedDetail` 非空且 uid 匹配、正文为 Hello，本地缓存未读计数归零 | P0 | ✅ 已覆盖 | `testSelectMessageFetchesBodyWithoutSyncService` |
| 80 | MailWorkspace | 缓存按 uid 升序投影时首页必须取最新一页，翻页继续向更旧扩展（**回归 #308**） | 缓存 51 封 INBOX 邮件（uid 1…51），会话离线 | 调用 `load()` 后 `loadMore()` | 首页 50 封为 uid 51…2，翻页后 51 封为 uid 51…1，整体最新优先 | P0 | ✅ 已覆盖 | `testFirstPageKeepsNewestMailsAndPagesTowardOlder` |
| 81 | MailComposerService | 保存草稿归档到 Drafts 时用 `\Draft`，与已发送归档区分（**回归 #403**） | mock 会话无 drafts 文件夹 | 调用 `composer.appendDraft(draft:account:)` | APPEND 到 Drafts 且 isDraft 为真，不触发 SMTP 发送 | P1 | ✅ 已覆盖 | `testAppendDraftUsesDraftFlag` |
| 82 | MailDraftAutosave | 编码与文件写入不得占用主线程（**回归 #1188**） | 注入记录线程的草稿存储 | 设置正文并添加 4 KB 附件后 `saveDraftNow()` | 落盘不在主线程，文本文件存在且 `draftSavedAt` 非空 | P0 | ✅ 已覆盖 | `testSaveEncodesAndWritesOffMainThread` |
| 83 | MailDraftAutosave | 纯文本编辑不得重写附件文件 | 已保存含附件的草稿 | 删除附件文件后只改正文再保存 | 附件文件不被重新写出，正文更新，草稿文本不内嵌附件字节/Base64 | P1 | ✅ 已覆盖 | `testTextOnlyEditDoesNotRewriteAttachments` |
| 84 | MailDraftAutosave | 附件增删必须重写附件文件 | 已保存含 1 个附件的草稿 | 删除该附件后保存 | 附件文件被重写为空数组 | P1 | ✅ 已覆盖 | `testAttachmentChangesRewriteAttachmentFile` |
| 85 | MailDraftAutosave | 恢复草稿后的首次纯文本编辑不重写附件 | 重开 VM 恢复到 1 个附件 | 删除附件文件后改正文并保存 | 附件文件不被写出，正文为编辑后的内容 | P1 | ✅ 已覆盖 | `testRestoredDraftSkipsAttachmentRewriteOnFirstTextEdit` |
| 86 | MailDraftAutosave | 旧版内嵌附件草稿必须仍能恢复，附件不得丢失 | 磁盘上是内嵌 Base64 附件的旧草稿 | 新建 VM 读取草稿 | 正文与 1 个附件（字节一致）都被恢复 | P0 | ✅ 已覆盖 | `testLegacyDraftWithEmbeddedAttachmentsStillRestores` |
| 87 | MailDraftAutosave | 旧草稿附件在首次保存时迁移到独立文件 | 磁盘上是旧版内嵌附件草稿 | 改正文后保存，再重开 VM | 正文为编辑后内容，附件迁移到独立文件且字节一致 | P1 | ✅ 已覆盖 | `testLegacyDraftMigratesAttachmentsOnFirstSave` |
| 88 | MailDraftAutosave | 连续击键必须合并成一次落盘 | 注入计数存储，防抖 60 ms | 连续 8 次改正文并 `scheduleDraftSave()`，等待 400 ms | 只落盘 1 次，内容为最后一次编辑 | P1 | ✅ 已覆盖 | `testContinuousEditsCoalesceIntoOneWrite` |
| 89 | MailDraftAutosave | 晚到的旧快照不得覆盖新草稿（**回归 #1188**） | 门闩卡住第一份快照 | 旧保存挂起时写入新正文并保存，再释放旧保存 | 磁盘上仍是新正文 | P0 | ✅ 已覆盖 | `testStaleSaveDoesNotOverwriteNewerDraft` |
| 90 | MailDraftAutosave | 发送成功后文本与附件草稿文件都删除 | 已保存含附件的草稿 | 调用 `send()` 并等待 phase 变为 sent | 文本与附件草稿文件均不存在 | P1 | ✅ 已覆盖 | `testSendSuccessRemovesTextAndAttachmentFiles` |
| 91 | Mail account_id 校验 | 四个工具都必须拒绝非法 account_id，且不触达 IMAP/SMTP（**回归 #840**） | 配置 A、B 两个账户，A 在前 | 对 list/read/search/send 传 `account_id: "not-a-uuid"` | 均抛 `ToolExecutionError` 且信息含 account_id；会话创建数为 0，无发送/归档/已读改动 | P0 | ✅ 已覆盖 | `invalidAccountIDIsRejectedByEveryTool` |
| 92 | Mail account_id 校验 | 空串与纯空白的 account_id 必须被拒绝（**回归 #840**） | 配置两个账户 | 对四个工具传 `""` / `"   "` / `"\n\t"` | 均抛参数错误，不创建会话、不寄信 | P0 | ✅ 已覆盖 | `emptyAndWhitespaceAccountIDAreRejected` |
| 93 | Mail account_id 校验 | 非字符串类型的 account_id 必须被拒绝（**回归 #840**） | 配置两个账户 | 对四个工具传数字、布尔、null、数组、对象 | 均抛参数错误，不创建会话、不寄信 | P0 | ✅ 已覆盖 | `nonStringAccountIDIsRejected` |
| 94 | Mail account_id 校验 | 格式合法但不存在的账户必须报错，不得伪装成空结果（**回归 #840**） | 配置两个账户 | list 与 send 传一个随机 UUID | list 抛 `ToolExecutionError`（不是「没有可用的邮件账户」成功文案），send 抛 `MailError.notFound`，不创建会话 | P0 | ✅ 已覆盖 | `unknownAccountIDIsAnErrorNotAnEmptyResult` |
| 95 | Mail account_id 校验 | 完全省略 account_id 时仍使用第一个账户 | 配置 A、B 两个账户，A 在前 | 不带 account_id 调用 list 与 send | 列出 A 的收件箱，MIME 的 From 为 A 邮箱且不含 B 邮箱 | P1 | ✅ 已覆盖 | `omittedAccountIDStillUsesFirstAccount` |
| 96 | Mail account_id 校验 | 传入合法 account_id 时必须使用该账户 | 配置 A、B 两个账户 | send 传 B 的 UUID | From 为 B 邮箱，不得回落到 A | P1 | ✅ 已覆盖 | `validAccountIDSelectsThatAccount` |
| 97 | Mail account_id 校验 | UUID 两侧空白被裁掉后仍视为合法 | 配置两个账户 | send 传 `"  <B 的 UUID>\n"` | 从 B 邮箱寄出 | P1 | ✅ 已覆盖 | `surroundingWhitespaceIsTrimmed` |
| 98 | Mail account_id 校验 | 搜索只读被请求账户的缓存 | 两个账户各有不同主题的缓存邮件 | search 传 B 的 UUID 与只匹配 B 的关键字 | 只返回 B 的命中，不混入 A 的缓存 | P1 | ✅ 已覆盖 | `searchReadsOnlyTheRequestedAccountCache` |
| 99 | Mail account_id 校验 | schema 必须说明省略与非法值的处理方式 | — | 读取四个工具 `inputSchema` 里 account_id 的 description | 同时说明可省略（Omit）与非法值会被拒绝（rejected） | P2 | ✅ 已覆盖 | `accountIDSchemaDocumentsRejection` |
| 100 | 账户身份与缓存隔离 | email 变更必须被检测为身份变更（**回归 #845**） | 已有账户 A | 比较 email 不同的新旧配置 | identityChanged 返回 true | P0 | ✅ 已覆盖 | `testEmailChangeDetected` |
| 101 | 账户身份与缓存隔离 | username 变更必须被检测为身份变更（**回归 #845**） | 已有账户 A | 比较 username 不同的新旧配置 | identityChanged 返回 true | P0 | ✅ 已覆盖 | `testUsernameChangeDetected` |
| 102 | 账户身份与缓存隔离 | imapHost 变更必须被检测为身份变更（**回归 #845**） | 已有账户 A | 比较 imapHost 不同的新旧配置 | identityChanged 返回 true | P0 | ✅ 已覆盖 | `testImapHostChangeDetected` |
| 103 | 账户身份与缓存隔离 | smtpHost 变更必须被检测为身份变更（**回归 #845**） | 已有账户 A | 比较 smtpHost 不同的新旧配置 | identityChanged 返回 true | P0 | ✅ 已覆盖 | `testSmtpHostChangeDetected` |
| 104 | 账户身份与缓存隔离 | 仅改显示名不算身份变更 | 已有账户 A | 比较 displayName 不同的新旧配置 | identityChanged 返回 false | P1 | ✅ 已覆盖 | `testDisplayNameChangeIsNotIdentityChange` |
| 105 | 账户身份与缓存隔离 | 仅改密码不算身份变更 | 已有账户 A | 比较密码不同但邮箱/主机相同的新旧配置 | identityChanged 返回 false | P1 | ✅ 已覆盖 | `testPasswordChangeIsNotIdentityChange` |
| 106 | 账户身份与缓存隔离 | 身份变更后旧缓存必须被清空（**回归 #845**） | 账户 A 有 2 封缓存邮件 | 编辑为不同邮箱后 purge | 缓存为空 | P0 | ✅ 已覆盖 | `testIdentityChangePurgesCache` |
| 107 | 账户身份与缓存隔离 | 删除账户后缓存必须被清空（**回归 #845**） | 账户 A 有缓存邮件 | 删除账户后 purge | 缓存为空 | P0 | ✅ 已覆盖 | `testDeletePurgesCache` |
| 108 | 账户身份与缓存隔离 | 身份未变时保留缓存 | 账户 A 有 1 封缓存邮件 | 仅改显示名，不 purge | 缓存仍有 1 封 | P1 | ✅ 已覆盖 | `testUnchangedIdentityKeepsCache` |
| 109 | MailAgentTools | mail_list_accounts 列出已配置账户且不含凭据（回归 #841） | 已配置两个账户 | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testListAccountsReturnsConfiguredAccountsWithoutCredentials` |
| 110 | MailAgentTools | 未配置账户时返回设置引导文案 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testListAccountsHintsSetupWhenNoAccountsConfigured` |
| 111 | MailAgentTools | mail_list_accounts schema 无必需参数 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testListAccountsSchemaHasNoRequiredArguments` |
| 112 | MailWorkspace | loadMore 向服务器请求上一页历史邮件并写入缓存（回归 #842） | 服务器 100 封、首页窗口 50 封 | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `testLoadMoreFetchesOlderPageFromServer` |
| 113 | MailWorkspace | 离线时 loadMore 退回本地缓存截断窗口 | 缓存 100 封、会话不可用 | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testLoadMoreOfflineFallsBackToCachedWindow` |

> 说明：全部 **113 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 28 / 28
- P1: 已覆盖 80 / 80
- P2: 已覆盖 5 / 5
- **合计: 113 / 113**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（27 条）
- **P1**: 其余功能性用例（76 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（5 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 99 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
