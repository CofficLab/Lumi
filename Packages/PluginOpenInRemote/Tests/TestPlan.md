# TestPlan — PluginOpenInRemote

## 包概述

PluginOpenInRemote Lumi 编辑器插件：在默认浏览器中打开当前项目的远程仓库。

平台: macOS 14+, iOS 17+
测试文件: 4 个，用例总数: 35

核心组件（源码目录）:
- `Capabilities/`
- `Services/`
- `Tools/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `OpenInRemoteConstants`
- `OpenInRemoteLocalization`
- `OpenInRemotePlugin`
- `OpenInRemoteGitCapability`
- `OpenInRemoteProjectEvent`
- `OpenInRemoteToastCapability`
- `RemoteRepositoryOpener`
- `RemoteRepositoryResolver`
- `RemoteWebURLResolver`
- `OpenInRemoteTool`
- `OpenInRemoteToolbarViewModel`
- `OpenInRemoteAboutView`
- `OpenInRemoteManualView`
- `OpenInRemoteToolbarView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **OpenInRemotePlugin**（3 条）：由 `pluginRegistersAndRemovesToolDocumentationAndToolbarItem`、`pluginToleratesMissingProviders`、`pluginResolvesRemoteWebURLWithProviders` 等用例锁定；改动该模块时优先跑对应测试文件。
- **OpenInRemoteTool**（9 条）：由 `explicitPathWinsOverCurrentProject`、`fallsBackToCurrentProject`、`returnsNilWithoutAnyTarget` 等用例锁定；改动该模块时优先跑对应测试文件。
- **RemoteRepositoryResolver**（7 条）：由 `resolvesWebURLFromOriginRemote`、`resolvesWebURLFromNamedRemote`、`returnsNilWhenRemoteIsMissing` 等用例锁定；改动该模块时优先跑对应测试文件。
- **RemoteWebURLResolver**（13 条）：由 `convertsScpLikeRemote`、`convertsScpLikeRemoteWithoutGitSuffix`、`convertsScpLikeRemoteWithGroupPath` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | OpenInRemotePlugin | 启动时注册对应工具、文档和左侧工具栏贡献，关闭时一并撤回 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginRegistersAndRemovesToolDocumentationAndToolbarItem` |
| 2 | OpenInRemotePlugin | 缺少可选 Provider 时生命周期回调安全降级 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `pluginToleratesMissingProviders` |
| 3 | OpenInRemotePlugin | 注册 Git 与项目能力后可解析远程仓库 web 链接 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginResolvesRemoteWebURLWithProviders` |
| 4 | OpenInRemoteTool | 显式路径优先于当前项目路径 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `explicitPathWinsOverCurrentProject` |
| 5 | OpenInRemoteTool | 未提供路径时回退到当前项目路径 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fallsBackToCurrentProject` |
| 6 | OpenInRemoteTool | 既无显式路径也无当前项目时返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `returnsNilWithoutAnyTarget` |
| 7 | OpenInRemoteTool | 工具名与风险等级符合低风险只读约定 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `exposesToolMetadata` |
| 8 | OpenInRemoteTool | 没有项目且未提供路径时抛出工具执行错误 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reportsMissingTarget` |
| 9 | OpenInRemoteTool | 仓库没有远程地址时抛出工具执行错误 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reportsMissingRemoteURL` |
| 10 | OpenInRemoteTool | 显式路径参数被透传到解析链路 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `passesExplicitPathThrough` |
| 11 | RemoteRepositoryResolver | 读取 origin remote 并转换为 web 链接 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resolvesWebURLFromOriginRemote` |
| 12 | RemoteRepositoryResolver | 指定 remote 名称时按名称读取 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resolvesWebURLFromNamedRemote` |
| 13 | RemoteRepositoryResolver | 仓库没有 remote 地址时返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `returnsNilWhenRemoteIsMissing` |
| 14 | RemoteRepositoryResolver | remote 地址无法转换为 web 链接时返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `returnsNilWhenRemoteIsNotConvertible` |
| 15 | RemoteRepositoryResolver | 空路径不触发读取 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `skipsLookupForEmptyPath` |
| 16 | RemoteRepositoryResolver | 缺少 Git 能力时安全降级为 nil | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `degradesGracefullyWithoutGitProvider` |
| 17 | RemoteWebURLResolver | scp-like 地址转换为 HTTPS web 链接 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `convertsScpLikeRemote` |
| 18 | RemoteWebURLResolver | scp-like 地址缺少 .git 后缀时同样正确转换 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `convertsScpLikeRemoteWithoutGitSuffix` |
| 19 | RemoteWebURLResolver | scp-like 地址保留多级分组路径 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `convertsScpLikeRemoteWithGroupPath` |
| 20 | RemoteWebURLResolver | scp-like 地址丢弃 user@ 前缀 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stripsUserPrefixFromScpLikeRemote` |
| 21 | RemoteWebURLResolver | ssh:// 地址转换为 HTTPS web 链接并丢弃 SSH 端口 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `convertsSSHRemote` |
| 22 | RemoteWebURLResolver | git:// 地址转换为 HTTPS web 链接并丢弃 Git 协议端口 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `convertsGitProtocolRemote` |
| 23 | RemoteWebURLResolver | https 地址保持不变并去掉 .git 后缀 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `normalizesHTTPSRemote` |
| 24 | RemoteWebURLResolver | 忽略首尾空白字符 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `trimsWhitespaceAroundRemote` |
| 25 | RemoteWebURLResolver | 去掉结尾多余的斜杠 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stripsTrailingSlash` |
| 26 | RemoteWebURLResolver | 空地址与无法识别的地址返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `returnsNilForUnusableRemote` |
| 27 | RemoteWebURLResolver | webURLString 与 webURL 结果一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `webURLStringMatchesWebURL` |
| 28 | OpenInRemoteTool | 会话绑定项目优先于当前项目，显式 path 仍最优先 | 显式/会话/当前三条路径同时存在 | 调用 `resolvedTargetPath` | 依次取显式、会话、当前 | P1 | ✅ 已覆盖 | `conversationProjectWinsOverCurrentProject` |
| 29 | OpenInRemoteTool | 未传 path 时使用会话绑定项目 | 当前项目 `/current`，会话绑定 `/conversation` | 调用 `executeResult(context:arguments:)` | 输出指向 `/conversation`，不含 `/current` | P1 | ✅ 已覆盖 | `usesConversationProject` |
| 30 | RemoteWebURLResolver | 本地 `file://` remote 不产生 web 链接（**回归 #1067**） | — | 解析 `file:///tmp/repo.git`、`file://localhost/...`、`file:/tmp/...` | 全部返回 `nil`，不出现 `https://file/...` | P1 | ✅ 已覆盖 | `returnsNilForLocalFileRemote` |
| 31 | RemoteWebURLResolver | 未支持的 URI scheme 不按 SCP-like 拼装地址（**回归 #1067**） | — | 解析 `ftp://`、`s3://`、`git+ssh://` | 全部返回 `nil` | P1 | ✅ 已覆盖 | `returnsNilForUnsupportedURIScheme` |
| 32 | RemoteRepositoryResolver | 本地 `file://` remote 解析为 `nil`（**回归 #1067**） | Git 能力原样返回 `file:///tmp/repo.git` | 调用 `webURL(forRepositoryAt:)` | 返回 `nil` | P1 | ✅ 已覆盖 | `returnsNilForLocalFileRemote` |
| 33 | OpenInRemoteTool | 本地 `file://` remote 报告没有可打开的 web 地址（**回归 #1067**） | origin 为 `file:///tmp/repo.git` | 调用 `execute(arguments:)` | 抛出「No remote repository URL」类错误，不误报打开成功 | P1 | ✅ 已覆盖 | `reportsMissingWebURLForFileRemote` |
| 34 | RemoteWebURLResolver | SSH/Git 地址保留路径中的百分号编码，不把 `%23` 变成 fragment（**回归 #1095**） | origin 为 `ssh://git@code.example.com/acme/repo%23draft.git` | 解析为 web 链接 | 结果为 `https://code.example.com/acme/repo%23draft`，path 含 `#` 且无 fragment；`%3F`、`%25` 同样保留 | P0 | ✅ 已覆盖 | `preservesEncodedCharactersInSchemePath` |
| 35 | OpenInRemoteTool | 浏览器拒绝打开时抛出工具执行错误，不再以普通字符串报告成功（**回归 #1096**） | remote 可解析为 web 链接，注入的打开动作返回 `false` | 调用 `execute(arguments:)` | 抛出 `ToolExecutionError.executionFailed`，reason 指向浏览器无法打开 | P1 | ✅ 已覆盖 | `reportsBrowserOpenFailure` |

> 说明：全部 **35 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 3 / 3
- P1: 已覆盖 31 / 31
- P2: 已覆盖 1 / 1
- **合计: 35 / 35**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（3 条）
- **P1**: 其余功能性用例（31 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 35 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginOpenInRemote
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
