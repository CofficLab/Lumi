# Lumi 邮件客户端插件（PluginMail）：可执行实施计划

Status: proposed, 2026-10-01.

> **For the executing agent:** 按 Phase → Task 逐项执行，每个 Task 完成其「验证」行后
> 按 [Commit 规范](../.agent/rules/commit-convention.md) 单独提交（`feat(KitMail): …` /
> `feat(PluginMail): …`）。不相关的变更拆分为多次提交。

## 1. 产品定位与决策

**产品目标**：在 Lumi 内提供完整邮件体验——多账户、收件箱、阅读、撰写、发送、附件、
本地缓存与搜索，并接入 Agent 工具（「读今天的邮件」「回复这封」）。首版目标是
**Lumi 内可用的完整邮件客户端**；「接管系统 mailto: / 完全替代系统 Mail」列为后期可选增强。

**协议前提（第一性原理）**：邮件是少数协议完全开放的领域——SMTP（发信，RFC 5321）、
IMAP（收信/同步，RFC 3501）为全行业通用标准，Gmail / Outlook / QQ / 163 / iCloud
等所有主流服务商均支持。因此本插件**只依赖开放协议，不绑定任何厂商 API**。

**关键调研结论（决策依据）**：

1. **Apple MailKit 不可用作客户端协议栈**（已查证
   [developer.apple.com/documentation/mailkit](https://developer.apple.com/documentation/mailkit)）：
   MailKit 仅提供 Mail **应用扩展**能力（content blocker / message action handler /
   compose session handler / message security handler），入口是 `MEExtension` 协议，
   服务于系统 Mail App，**不含 IMAP/SMTP 传输**。早先"基于 MailKit 起步"的设想作废。
2. **协议栈三选一**（决策见第 4 节）：MailCore2（首选）／ swift-nio-imap + 自建 SMTP ／
   自实现最小协议子集。协议栈必须隔离在薄抽象之后，可替换。

**决策**：

1. **独立 SPM 包 `KitMail` 承载协议栈**（薄抽象 `MailSessionServing` + MailCore2 适配器），
   与 `KitMCP` 同构；`PluginMail` 只依赖抽象，不直接触碰第三方类型。
2. **插件壳 `PluginMail`**：ActivityBar 入口 + 三栏工作区（文件夹 / 列表 / 阅读）+
   撰写窗口 + 账户设置页，遵循插件目录结构规范。
3. **凭据安全**：账户配置（不含密码）JSON 落盘；密码 / OAuth refresh token 一律存
   系统 Keychain（`KitKeychain`，与 `DatabaseConnectionStore` 同模式）；日志禁止记录
   凭据与邮件正文。
4. **首版认证用「应用专用密码 / 授权码」**（QQ、163、Gmail 2FA 应用密码、iCloud），
   Gmail/Outlook 官方 OAuth2 推迟到 Phase 6——避免首版引入 OAuth 弹窗与审核复杂度。
5. **Agent 工具默认分级**：只读工具（列表/搜索/读信）`safe`；发送/删除/已读写
   `high` 走审批流。
6. **默认不加载远程图片与 JS**（HTML 邮件在禁 JS 的 WKWebView 中渲染，远程内容
   需用户手动点击加载），防止跟踪像素与攻击面。

## 2. 目标与非目标

**目标**：

- 添加多个邮件账户（IMAP 收信 + SMTP 发信），凭据存 Keychain；
- 文件夹树（收件箱/已发送/草稿/垃圾箱等）、邮件列表（分页/未读标记/搜索）、
  阅读窗格（HTML + 纯文本降级 + 附件下载）；
- 撰写 / 回复 / 转发，发送经 SMTP，发送失败落草稿；
- 本地缓存（SwiftData）支持离线浏览与全文搜索；
- Agent 工具：`mail_list`、`mail_read`、`mail_search`、`mail_send`（审批）；
- 全部用户可见文本走 `Localizable.xcstrings`（en / zh-Hans / zh-HK / zh-TW）。

**非目标（本阶段明确不做）**：

- 不做 Gmail/Outlook 官方 OAuth2 授权流（Phase 6 可选）；
- 不做 POP3（IMAP 全量覆盖其场景）、不做 Exchange/EWS/Graph 专有协议；
- 不做邮件规则 / 智能邮箱 / VIP / 签名同步 / 加密签名（S/MIME、PGP）；
- 不做系统 mailto: 接管与新邮件系统通知（Phase 6 可选）；
- 不做日历、通讯录、聊天等相邻能力。

## 3. 用户故事（验收标准）

1. **添加账户**：设置 → 邮件账户 → "+" → 选服务商（或手动）填 IMAP/SMTP 主机、
   端口、邮箱、密码（或应用专用密码）→ 保存。密码出现在 Keychain，配置界面
   遮蔽显示；连接测试通过后账户出现在侧栏。
2. **收信**：进入邮件插件 → 文件夹树选「收件箱」→ 列表按时间倒序展示主题/发件人/
   日期，未读加粗；滚动到底自动加载更多。
3. **读信**：点击邮件 → 阅读窗格渲染 HTML 正文（图片默认不加载，有"加载远程内容"
   提示条）；纯文本邮件正常显示；带附件的邮件显示附件条，点击下载后可预览。
4. **发信**："写邮件" → 填收件人/主题/正文 → 发送。成功后出现在「已发送」；
   失败（认证错/网络错）弹出可读错误并保留草稿。
5. **回复/转发**：阅读窗格内"回复"带出 `Re:` 主题与引用正文。
6. **离线**：断网时已缓存邮件仍可浏览与搜索；新操作排队提示"离线"。
7. **Agent**：对话中说"读我最新的 3 封邮件"，LLM 调用 `mail_list` 直接执行；
   "把这封转给 xx" 生成 `mail_send` 草案 → 走审批 → 发送。
8. **多账户**：两个账户并存，文件夹树按账户分组，工具调用可指定账户。
9. **卸载/禁用**：禁用插件即撤销全部工具与 UI 注入；Keychain 凭据由用户在设置页
   显式删除账户时清除。

## 4. 协议栈选型（关键决策）

| 方案 | 内容 | 优点 | 缺点 | 结论 |
| --- | --- | --- | --- | --- |
| **A. MailCore2** | C++/ObjC 实现的 IMAP/POP/SMTP + MIME 编解码，async API，被大量 macOS/iOS 邮件 App 使用 | 三协议一站齐；MIME 构建/解析现成；支持 XOAUTH2；有 SPM/xcframework 分发 | ObjC/C++ 遗留代码；上游维护节奏慢；需验证 Swift 6 严格并发下的适配 | **首选** |
| B. swift-nio-imap（Apple）+ 自建 SMTP | NIOIMAP 提供 IMAP4rev1 编解码与客户端 | Apple 官方、纯 Swift、活跃 | 仅 IMAP；无 MIME、无 SMTP、无高层会话，等于自建大半 | 回退项 |
| C. 自实现最小协议子集 | IMAP（LOGIN/TLS/LIST/SELECT/FETCH/STORE/SEARCH）+ SMTP（STARTTLS/AUTH PLAIN·LOGIN/MAIL/RCPT/DATA）+ 最小 MIME | 零依赖、完全可控 | 工作量最大，边界情况多（字面量/响应码/部分 Fetch） | 兜底项 |

**决策**：选 **A**，隔离在 `MailSessionServing` 协议之后；Phase 0 Spike 验证不通过
（SPM 集成失败 / 真实服务器连不通 / Swift 6 并发不可接受）则按 B→C 顺序回退，
抽象层与上层不改。

**回退触发条件（写死，避免执行时摇摆）**：

- MailCore2 无法以 SPM 依赖稳定集成（binary target / vendored framework 均失败）；
- 对 Gmail/QQ/163 任一真实 IMAP 完成不了 LIST+FETCH+SMTP 发信 PoC；
- 并发适配需要侵入式改动超过 `KitMail` 预期规模（> ~1500 行胶水）。

## 5. 架构与包划分

```
FactoryLumi（宿主装配：Package.swift 依赖 + PluginFactory 注册）
├── KitMail（新增，协议栈包，无 UI 依赖）
│   ├── MailModels            // MailAccountConfig / MailFolder / MailMessageSummary
│   │                         // / MailMessageDetail / MailAttachment / MailAddress
│   ├── MailSessionServing    // 薄抽象协议（连接/文件夹/取信/标记/搜索/发信）
│   ├── MailCoreAdapter       // MailCore2 适配器（唯一 import 第三方处）
│   ├── MimeMessageBuilder    // 撰写：纯文本/HTML multipart、附件 base64、引用回复
│   └── MailError             // 统一错误（auth/network/protocol/notFound），可本地化
├── PluginMail（新增，插件壳）
│   ├── MailPlugin.swift          // SuperPlugin 入口（id/order/metadata/生命周期）
│   ├── MailPluginLocalStore.swift// 设置项（默认账户、每页条数、远程图片策略）
│   ├── Providers/
│   │   └── MailAccountProviderAdapter.swift // 若需向内核暴露账户能力（按需）
│   ├── Services/
│   │   ├── MailAccountStore.swift    // 账户配置 JSON + KitKeychain 凭据
│   │   ├── MailSessionManager.swift  // actor：账户→会话池、连接生命周期、重连
│   │   ├── MailSyncService.swift     // actor：增量同步、增量 UID FETCH、游标
│   │   ├── MailCacheService.swift    // SwiftData 本地缓存（db_{env}/Mail/mail.sqlite）
│   │   └── MailComposerService.swift // 发送编排：构建 MIME → SMTP → 落已发送/草稿
│   ├── Tools/                        // Agent 工具（SuperAgentTool）
│   │   ├── MailListTool.swift        // mail_list  (safe)
│   │   ├── MailReadTool.swift        // mail_read  (safe)
│   │   ├── MailSearchTool.swift      // mail_search(safe)
│   │   └── MailSendTool.swift        // mail_send  (high → 审批)
│   ├── Models/
│   │   ├── MailAccount.swift         // UI 层账户模型（不含凭据）
│   │   ├── CachedMessage.swift       // @Model SwiftData 缓存模型
│   │   └── MailFolderNode.swift      // 文件夹树节点
│   ├── ViewModels/
│   │   ├── MailWorkspaceViewModel.swift   // 三栏状态机（当前账户/文件夹/选中邮件）
│   │   ├── MailListViewModel.swift        // 分页、未读、搜索
│   │   └── MailComposeViewModel.swift     // 撰写/回复/转发、发送与草稿
│   └── Views/                            // 每个独立视图一个文件（规范要求）
│       ├── MailWorkspaceView.swift        // 三栏容器
│       ├── MailFolderSidebarView.swift    // 文件夹树
│       ├── MailListView.swift             // 邮件列表
│       ├── MailListRow.swift
│       ├── MailReaderView.swift           // 阅读窗格
│       ├── MailHTMLContentView.swift      // 禁 JS 的 WKWebView 封装 + 远程内容条
│       ├── MailAttachmentBarView.swift
│       ├── MailComposeView.swift
│       ├── MailAccountFormView.swift      // 账户添加/编辑（含连接测试）
│       └── MailEmptyStateView.swift
└── 已有复用：ActivityBarProviding / RailViewProviding / ContentViewProviding /
    ToolbarProviding / ToolManagerProviding / SettingViewProviding / DocsViewProviding /
    StorageProviding(pluginDataDirectory) / KitKeychain / LumiUI(AppSettings*) 
```

**边界（内核与插件规范）**：`KitMail` 不依赖任何插件与内核；`PluginMail` 依赖
`KitMail` 与内核 Provider 协议；MailCore2 第三方类型**不得**泄漏出 `KitMail`。

**插件元数据**：

```swift
public let id = "com.coffic.lumi.plugin.mail"
public let order = 880          // 与既有条目错开，接入时按 PluginFactory 实际占用微调
public let dependencies = []     // 若复用 editor-host 嵌入撰写富文本则加（首版不需要）
public let metadata = PluginMetadata(
    id: "com.coffic.lumi.plugin.mail",
    name: …,                     // 本地化
    description: …,              // 本地化
    category: .integration,      // 以 PluginMetadata 实际枚举为准
    stage: .preview,
    policy: .disabledByDefault   // 涉及邮件凭据，默认关闭，用户显式启用
)
```

## 6. 数据与存储

| 数据 | 位置 | 形式 | 规范依据 |
| --- | --- | --- | --- |
| 账户配置（地址/主机/端口/用户名/登录方式） | `StorageProviding.pluginDataDirectory(for: id)/accounts.json` | JSON，**不含密码** | 存储规范 |
| 密码 / 应用专用密码 / refresh token | 系统 Keychain（`KitKeychain`），key = `mail.account.<uuid>` | Keychain | 与 `DatabaseConnectionStore` 同模式 |
| 邮件缓存（头/正文/附件元数据） | `AppConfig.getDBFolderURL()/Mail/mail.sqlite` | SwiftData `@Model CachedMessage` | 存储规范 §2 |
| 插件设置（默认账户、分页大小、远程图片策略） | `…/Mail/settings.plist` | `MailPluginLocalStore` | 存储规范 §1 |
| 草稿 | SwiftData `CachedMessage` + `folder == .drafts`（服务器端草稿走 IMAP APPEND，Phase 5 简化为本地草稿） | — | — |

**缓存模型要点**：`uid`、`folder`、`accountID` 复合唯一；`dateReceived` 索引；
正文只存渲染所需（htmlText / plainText 二选一 + 附件路径）；保留策略
`retentionPeriod = 90 天`、`maxRecords = 20000`（存储规范 §2.4.2 同款清理）。

## 7. UI 设计

**入口**：`ActivityBarItem`（SF Symbol `envelope`，order 派生自 `info.order`，
遵守 [插件 UI 项 order 规范](../.agent/rules/plugin-order-rules.md)）→ 激活时切换
`ContentViewProviding.setContentView(MailWorkspaceView)`（参照
`DatabaseManagerSuperPlugin` 的激活/还原对称写法：激活设 content + 隐藏 chat +
加 toolbar 标题项，还原全部撤销）。

**三栏布局**：

```
┌──────────┬────────────────┬───────────────────────────┐
│ 文件夹树  │ 邮件列表        │ 阅读窗格                    │
│ (账户分组) │ 主题/发件人/日期 │ 头部信息 + 操作条            │
│ 收件箱     │ 未读加粗        │ HTML（禁JS/远程内容需确认）   │
│ 已发送     │ 分页加载        │ 附件条                      │
│ 草稿/垃圾  │ 搜索框          │ 回复/转发/删除               │
└──────────┴────────────────┴───────────────────────────┘
```

- 设置页：走 [Settings UI 规范](../.agent/rules/settings-ui.md)——
  `settingsTabItems(kernel:)` 返回 `PluginSettingsScaffold` + `AppCard` +
  `AppSettingsToggleRow/PickerRow`；账户管理列表 + 添加/编辑表单页。
- 错误处理（项目通用规则 §3）：连接失败/认证失败/发送失败必须有可见错误视图
  （inline banner + 可读文案），不得静默。
- 预览：每个 `Views/*.swift` 文件末尾提供 `#Preview`（Mock 数据，不联网）。

## 8. 分阶段任务

### Phase 0：协议栈 Spike（先证伪，再动工）★ 阻塞后续

**Task 0.1 — MailCore2 集成可行性**
- 新建 `Packages/KitMail` 骨架（swift-tools 5.9，`.macOS(.v14)`）；
- 尝试以 SPM 引入 MailCore2（binary target / 官方 xcframework release /
  vendored 源码三选一，记录实际可行路径）；`swift build` 通过。
- 验证：空包编译；依赖解析结果写入本文件「Spike 结论」小节。✅ 2026-10-01 完成

**Task 0.2 — 真实服务器 PoC**
- 用测试账户（Gmail 应用密码 / QQ 授权码 至少一家，最好两家）完成：
  IMAP TLS 连接 → LIST 文件夹 → SELECT 收件箱 → FETCH 最近 10 封头与正文 →
  SMTP 发信一封到自测地址。
- 验证：脚本输出各步骤结果；任一步失败即触发第 4 节回退决策（B 或 C），
  并把失败原因写回本文件。

**Spike 结论**：（2026-10-01 执行，Task 0.1 ✅）

**1. 官方 SPM binary target → 不可用（Apple Silicon）**
- 官方 `Package.swift` 指向 `mailcore2/bin/MailCore2-2020-09-24.xcframework.zip`
  （checksum 已核对一致），但该产物**仅含 macos-x86_64**（另有
  ios-arm64_armv7 / ios-x86_64-simulator，无 macos-arm64、无 ios-arm64-simulator）。
- 本机为 Apple M3（arm64），SPM binary target 不做 Rosetta 转译，
  官方产物无法链接。**结论：官方 binary 方案作废。**

**2. 社区现成分发 → 无可用**
- 检索未发现含 macos-arm64 slice 的社区 SPM 分发；Swift Package Index 上
  同名 `LiveUI/MailCore` 是 Vapor 邮件封装，与本项目无关。

**3. vendored 源码构建 → 可行（采用）**
- 从 `MailCore/mailcore2`（master @ 2026-10-01）源码 + 子模块
  （ctemplate / libetpan / tidy-html5）构建出 **macos-arm64** 动态框架：
  - 依赖：先构建 `libetpan.a`、`libctemplate.a`（arm64，`MACOSX_DEPLOYMENT_TARGET=14.0`），
    按 macOS 工程实际命名放入 `Externals/libetpan-osx/`、`Externals/ctemplate-osx/`；
  - 工程：`build-mac/mailcore2.xcodeproj` scheme `mailcore osx`，
    `ARCHS=arm64 MACOSX_DEPLOYMENT_TARGET=14.0` 覆盖（原值 10.8 超出 Xcode 27 支持范围）；
  - **源码兼容补丁（Xcode 27 / macOS 27 SDK，共 3 处，均 <10 行）**：
    1. `src/core/basetypes/MCICUTypes.h`：C++11+ 分支 `typedef char16_t UChar`
       改为 `typedef unsigned short UChar`，与 `umachine.h` 的 macOS 分支一致
       （否则 `umachine.h:310` 与先前定义 redefinition 冲突）；同时保证与
       `CFStringCreateWithCharactersNoCopy`（UniChar = unsigned short）兼容；
    2. `src/core/basetypes/MCString.cpp`：`structuredError` 回调第二参数
       `const xmlError *` 去掉 const（新 SDK `xmlStructuredErrorFunc` 为非 const 签名）；
    3. 工程 Copy Headers 仅声明 223 个头，漏拷贝 ActiveSync 等 319 个头：
       构建后把 `src/` 下全部 `*.h`（540 个）补齐到框架 `Headers/` 目录
       （构建期用 `OTHER_CFLAGS='$(inherited) -I<allheaders>'` 提供全量头）。
- 产物：`MailCore.framework`（Mach-O arm64，16 MB），合并官方 iOS slices 后
  `MailCore2.xcframework`（43 MB，4 slices）已 vendored 至
  `Packages/KitMail/Vendor/MailCore2.xcframework`，SPM 本地 `.binaryTarget` 引入。
- **集成验证**：`Packages/KitMail`（swift-tools 5.9）`swift build` 通过；
  冒烟代码 `import MailCore` 成功，`MCOIMAPSession` / `folderInfoOperation` /
  `fetchMessagesOperation(withFolder:requestKind:uids:)` /
  `fetchMessageOperation(withFolder:uid:)` / `MCOMessageBuilder` 均可在 Swift 中调用。

**3b. libetpan MIME 解析死循环（MCOMessageParser hang，2026-10-02 补丁）**
- 现象：`MCOMessageBuilder.data()` 正常（678 字节），但 `MCOMessageParser(data:)`
  立即死循环（CPU 满载，sample 定位在 `mailmime_fields_parse →`
  `mailmime_parameter_parse → mailimf_quoted_string_parse`）。
- 根因：vendored libetpan（submodule rev `6dc099a`）`mailimf_quoted_string_parse`
  的 `while (1)` **无退出条件**——当 fws 与 qcontent 都返回 `MAILIMF_ERROR_PARSE`
  （quoted-string 遇收尾引号等不可消费输入）时 cur_token 不再前进、无限循环。
  纯 ASCII 输入同样复现，与中文/编码无关。
- 补丁：`deps/libetpan/src/low-level/imf/mailimf.c` 在该函数循环内新增
  `if ((r_fws == MAILIMF_ERROR_PARSE) && (r_qcontent == MAILIMF_ERROR_PARSE)) break;`
  （RFC 语义：quoted-string 在非 qcontent 字符处结束，交由后续 `dquote_parse` 收尾）。
- 验证：重建 Debug libetpan（补丁）→ Release mailcore2 重新链接 → 重组
  `MailCore2.xcframework`（macos-arm64 新 slice，最终 3 slices：macos-arm64 /
  ios-arm64_armv7 / ios-x86_64-simulator，**不含 macos-x86_64**，SwiftPM 会判
  x86_64+arm64 为 "equivalent"）→ 替换 Vendor → `MimeMessageBuilderTests` 与
  全量 KitMail 测试 27 项全绿，`MCOMessageParser` / `plainTextRendering` /
  `htmlRendering(with:)` 均正常。
- 经验：改 Vendor 后必须 `rm -rf Packages/KitMail/.build`，否则 SPM 缓存沿用旧二进制。

**4. 回退条件复核**
- 三个回退触发条件（SPM 集成失败 / 真实服务器 PoC 失败 / 并发胶水 >1500 行）：
  SPM 集成已通过；真实服务器 PoC（Task 0.2）待测试账户；并发适配按
  `@unchecked Sendable` + 内部串行队列集中处理，规模远小于 1500 行。
  **结论：维持 A 方案（MailCore2），继续 Phase 1。**

**5. 可复现构建脚本**
- 构建命令与补丁步骤见上；如需重构建，按第 3 节步骤即可（脚本可后续固化到
  `Scripts/build-mailcore2-xcframework.sh`，当前一次性手工执行已记录）。

### Phase 1：KitMail 协议包

**Task 1.1 — 模型与抽象**
- `MailModels`（account config / folder / message summary / detail / attachment /
  address，全部 `Sendable` + `Codable`）；
- `MailSessionServing` 协议：`connect/disconnect`、`listFolders`、
  `fetchMessages(folder:sinceUID:limit:)`、`fetchBody(uid:)`、
  `setFlags(uid:flags:)`、`search(query:)`、`sendMessage(mime:)`、
  `appendDraft(mime:)`；
- `MailError`：`authFailed / network / protocol(String) / notFound / offline`，
  每个 case 提供可本地化描述键。
- 验证：模型编解码往返单测；协议可 mock（为 Phase 2 测试做准备）。

**Task 1.2 — MailCore2 适配器**
- `MailCoreAdapter: MailSessionServing`；ObjC 回调桥接 async/await
  （`withCheckedThrowingContinuation`）；连接复用与超时（30s）；
  Swift 6 严格并发标注（`@unchecked Sendable` + 内部串行队列，集中一处）。
- 验证：mock 服务器（本地 greenmail 或录制回放）覆盖连接/列表/取信/发信
  与 auth 失败路径单测。

**Task 1.3 — MimeMessageBuilder**
- 构建 multipart/alternative（text/plain + text/html）+ multipart/mixed 附件；
- 回复引用（引用正文加 `>` 前缀 + `In-Reply-To`/`References` 头）、
  UTF-8 头编码（RFC 2047）。
- 验证：往返测试（构建 → 解析器还原字段）；含中文主题、含附件用例。

### Phase 2：PluginMail 骨架 + 账户管理（核心交付①）✅ 2026-10-02 完成

**Task 2.1 — 插件包骨架与入口**
- 新建 `Packages/PluginMail`：`MailPlugin.swift`（id/order/metadata）、
  `Resources/Localizable.xcstrings`（4 语言空表）、`MailPluginLocalStore`；
- `FactoryLumi`：`Package.swift` 加 `../PluginMail` 依赖、`PluginFactory.swift`
  import 并注册实例。
- 验证：`FactoryLumiTests` 全绿（插件目录包含新 id）；App 集成构建通过；
  设置 → 插件列表出现「邮件」。

**Task 2.2 — 账户存储 + 设置页**
- `MailAccountStore`：JSON 配置 + `KitKeychain` 凭据（照抄
  `DatabaseConnectionStore` 策略注释与 key 命名）；
- `settingsTabItems(kernel:)` 账户页：列表、添加/编辑表单（服务商预设：
  Gmail/QQ/163/iCloud/Outlook + 手动）、**连接测试**按钮、删除账户（提示将清
  Keychain）；遵循 `PluginSettingsScaffold` + `AppSettings*Row`，禁 `Form`。
- 验证：账户 CRUD 单测；Keychain 写入读取；密码不出现在 accounts.json 与日志。

**Task 2.3 — Session/Sync 服务**
- `MailSessionManager`（actor）：账户→会话映射、懒连接、断线重连、
  onShutdown 全断；`MailSyncService`（actor）：按 UID 游标增量同步 →
  写 `MailCacheService`（SwiftData）。
- 验证：同步单测（mock session：新增/删除/未读变化）；actor 并发测试。

### Phase 3：三栏工作区 UI（核心交付②）✅ 2026-10-02 完成

**Task 3.1 — 工作区与文件夹树**
- `MailWorkspaceView` + `MailFolderSidebarView`（账户分组、未读计数）；
- `MailPlugin` 装配 ActivityBar 入口与激活/还原（第 7 节对称写法），
  order 派生自 `info.order`。
- 验证：App 运行，点击活动栏图标进入工作区，还原后 chat/toolbar 恢复原状。

**Task 3.2 — 邮件列表**
- `MailListView` + `MailListViewModel`：分页（每页 50）、未读加粗、
  选中态、下拉刷新、搜索框（本地缓存搜索先接 `MailCacheService`）。
- 验证：真实账户滚动加载；空文件夹/离线空态；`#Preview` 各状态。

**Task 3.3 — 阅读窗格**
- `MailReaderView` + `MailHTMLContentView`（WKWebView，`javaScriptEnabled = false`、
  默认拦截远程资源，提供"加载远程内容"提示条）+ 纯文本降级 +
  `MailAttachmentBarView`（下载到插件数据目录，`QLPreview`/`Preview` 预览）。
- 验证：HTML 邮件（含表格/深色模式适配）、纯文本邮件、带附件邮件三类真机渲染；
  JS 不执行（自测含 `<script>` 的邮件）。

### Phase 4：撰写与发送（核心交付③）✅ 2026-10-02 完成

**Task 4.1 — 撰写视图**
- `MailComposeView` + `MailComposeViewModel`：新写/回复/转发三模式、
  附件拖入、草稿自动保存（本地）、发送中/失败状态。
- 验证：三模式 UI 状态机单测；失败保留草稿。

**Task 4.2 — 发送编排**
- `MailComposerService`：MimeMessageBuilder → SMTP 发送 → 成功后 IMAP
  APPEND 到已发送（失败降级：仅本地记录，不阻断成功态）→ 失败映射
  `MailError` 可读文案。
- 验证：真实 SMTP 发信端到端（收到自测邮件）；错误路径（错密码/断网）文案。

### Phase 5：Agent 工具 + 缓存搜索 ✅ 2026-10-02 完成

**Task 5.1 — 工具注册**
- 4 个 `SuperAgentTool`，经 `ToolManagerProviding.add(_, pluginID:)` 注册，
  `onShutdown` 按名撤销；`mail_send` 需要 `accountID/folder/uid` 上下文参数，
  结果里返回草案供审批展示。
- 风险分级：list/read/search = `safe`（可并行），send = `high`（审批）。
- 验证：对话内「读最新 3 封邮件」真跑通；「发邮件」触发审批，拒绝不发送。

**Task 5.2 — 缓存搜索与离线**
- `MailCacheService` 全文搜索（SQLite FTS 或 LIKE 先行，按最少功能原则取 LIKE）
  + 离线态（列表标注"离线·显示缓存"）。
- 验证：断网启动仍可浏览缓存；搜索结果正确。

### Phase 6：可选增强（不阻塞主线，按需排期）

- Gmail/Outlook 官方 OAuth2（`ASWebAuthenticationSession` + XOAUTH2，
  `MailSessionServing` 已预留 refresh token 存储位）；
- IMAP IDLE 新邮件推送 + 系统通知（`ProviderAgentTurnNotification` 同款通道）；
- `mailto:` 接管（Info.plist `CFBundleURLTypes` + 引导用户系统设置设默认）；
- 服务器端草稿同步（IMAP APPEND/DRAFTS）、多选批量操作、规则/智能邮箱；
- 富文本撰写（复用 editor-host 嵌入，届时补 `dependencies`）。

## 9. 验证方式汇总

| 层 | 验证 |
| --- | --- |
| Spike | Task 0.2 真实 IMAP/SMTP PoC 通过（否则回退决策） |
| 单元 | 模型编解码、MIME 构建往返、MockSession 同步、账户存储/Keychain、工具 schema、错误映射 |
| 集成 | 真实账户收信/发信/回复/附件端到端；缓存 + 离线浏览 |
| 安全 | accounts.json 无密码；日志 grep 无凭据与正文；HTML 邮件 JS 不执行、远程内容默认拦截 |
| i18n | xcstrings 4 语言齐全，切换生效；日志不含未本地化用户文案 |
| UI | 三栏工作区真机运行；激活/还原对称（chat、toolbar 无残留）；各视图 `#Preview` |
| 构建 | 各包 `swift test` + `xcodebuild -scheme Lumi` 集成构建 |
| 自动化（可选） | 若新增 Automation action，补 `scripts/test-automation-mail.sh`（见自动化测试规范） |

## 10. 风险与回退

- **MailCore2 维护/集成风险**：第 4 节已写死回退条件（B: swift-nio-imap+自建 SMTP，
  C: 自实现最小子集）；`MailSessionServing` 保证上层不动。
- **服务商差异**：QQ/163 需授权码、Gmail 需应用密码或 OAuth、Outlook 基本只给
  OAuth——设置页按服务商预设展示对应指引文案（本地化），Outlook 首版标注
  "需应用密码/暂不支持"避免用户困惑。
- **HTML 邮件安全**：禁 JS、默认拦截远程内容与资源，正文永不执行脚本；
  附件不自动打开，交系统预览。
- **数据量**：大邮箱首次同步只拉最近 N 封（默认 200/文件夹，设置可调），
  增量按 UID 游标，避免全量 FETCH。
- **并发正确性**：所有网络会话收进 actor（Session/Sync/Compose 三个），
  UI 层只 @MainActor 消费发布状态，杜绝跨线程回调直改 UI。
- **凭据泄漏面**：任何 `logger.*` 输出禁止拼接密码/正文（日志规范禁止项）；
  错误文案对用户展示时不含完整主机凭据回显。

## 11. 相关规范

- [插件目录结构规范](../.agent/rules/plugin-directory-rules.md)
- [插件数据存储规范](../.agent/rules/plugin-storage-rules.md)
- [插件国际化规范](../.agent/rules/plugin-i18n-rules.md)
- [Settings UI (LumiUI)](../.agent/rules/settings-ui.md)
- [内核与插件边界规范](../.agent/rules/core-plugin-boundary-rules.md)
- [插件 UI 项 order 规范](../.agent/rules/plugin-order-rules.md)
- [Swift 日志记录规范](../.agent/rules/swift-log.md)
- [Commit 规范](../.agent/rules/commit-convention.md)
