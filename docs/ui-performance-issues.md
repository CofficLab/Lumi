# Lumi 仓库 · UI 流畅性 / 性能相关 Issue 清单

仓库：CofficLab/Lumi

> 判定口径：标题涉及主线程/UI 线程阻塞、同步 IO 与编解码、高频轮询与定时器、SwiftUI 重渲染与布局快照重建、N²/全量重扫算法、后台 CPU 占用。

> 数据来源：`gh api repos/CofficLab/Lumi/issues`（全量 issue 标题关键词筛选）


---


## 处理进度总览

| 状态 | 数量 | 说明 |
|---|---|---|
| ✅ 本轮已修复并提交 | 16 | 每条有对应提交与守卫测试 |
| ✔️ 此前已修复（本次核实并关闭 issue） | 4 | 代码已正确，issue 状态滞后 |
| 📦 属外置仓库（PluginDevice） | 4 | 本仓库无法修复，已在 issue 留言指明方案 |
| ⬜ 待处理 | — | 见下方各分类 |

### 本轮修复清单

| Issue | 提交 | 说明 |
|---|---|---|
| [#418](https://github.com/CofficLab/Lumi/issues/418) | `0be0fc533` | 修复：取消后不再忙轮询 |
| [#423](https://github.com/CofficLab/Lumi/issues/423) | `40307bf47` | 修复：禁用后停止采集 + 在途处理失效 |
| [#775](https://github.com/CofficLab/Lumi/issues/775) | `40307bf47` | 修复：缩短轮询窗口 |
| [#1192](https://github.com/CofficLab/Lumi/issues/1192) | `40a7c3b43` | 修复：剪贴板搜索防抖 + 关键词长度上界 |
| [#1211](https://github.com/CofficLab/Lumi/issues/1211) | `b23314d93` | 修复：图表几何量一次求值 |
| [#1224](https://github.com/CofficLab/Lumi/issues/1224) | `1d16f1672` | 修复：hover 移出 Canvas 重绘路径 |
| [#1245](https://github.com/CofficLab/Lumi/issues/1245) | `97850fb00` | 修复：文件元数据探测移出主线程 |
| [#1267](https://github.com/CofficLab/Lumi/issues/1267) | `6eea7572b` | 修复：去二次方扫描 |
| [#1272](https://github.com/CofficLab/Lumi/issues/1272) | `d2c21ba4d` | 修复：定向查询窗口存在性 |
| [#1273](https://github.com/CofficLab/Lumi/issues/1273) | `867dc2b2b` | 修复：摘要反向扫描 |
| [#1279](https://github.com/CofficLab/Lumi/issues/1279) | `669aeb38d` | 修复：查找匹配防抖 + 正则缓存 |
| [#1295](https://github.com/CofficLab/Lumi/issues/1295) | `e3f355ca4` | 修复：章节字数与故事总字数缓存 |
| [#1298](https://github.com/CofficLab/Lumi/issues/1298) | `80ce4fad9` | 修复：附件位图解码缓存 |
| [#1300](https://github.com/CofficLab/Lumi/issues/1300) | `fe62ff3bd` | 修复：workingChanges 缓存 |
| [#1304](https://github.com/CofficLab/Lumi/issues/1304) | `87ac26b0d` | 修复：记忆搜索防抖 + 单次过滤 |
| [#1329](https://github.com/CofficLab/Lumi/issues/1329) | `c1818bff6` | 修复：总行数走行偏移表缓存 |

### 此前已修复（本次核实）

| Issue | 提交 | 说明 |
|---|---|---|
| [#128](https://github.com/CofficLab/Lumi/issues/128) | `3912fa25e / ba2f8f2d8` | 已修复：nettop 生命周期 + 图标解析 + stdin 忙循环（已关闭 issue） |
| [#129](https://github.com/CofficLab/Lumi/issues/129) | `c5bbeb20c` | 已修复：轮询 2s→15s（已关闭 issue） |
| [#1213](https://github.com/CofficLab/Lumi/issues/1213) | `b92a3c66b` | 已修复：网络原子快照 |
| [#1301](https://github.com/CofficLab/Lumi/issues/1301) | `0f5a7fd` | 已修复：底部追踪器身份守卫 + 扫描缓存 |

### 属外置仓库 `LumiPluginDevice`

`PluginDevice` 已于 `d8473e736` 迁出本仓库，由 `https://github.com/lumi-softworks/LumiPluginDevice.git` 提供。以下 issue 的代码在外部仓库，已在 issue 留言指明修复方案：

- [#1206](https://github.com/CofficLab/Lumi/issues/1206) — PluginDevice（外置仓库）
- [#1209](https://github.com/CofficLab/Lumi/issues/1209) — PluginDevice（外置仓库）
- [#1210](https://github.com/CofficLab/Lumi/issues/1210) — PluginDevice（外置仓库）
- [#1306](https://github.com/CofficLab/Lumi/issues/1306) — PluginDevice（外置仓库）

## 输入即卡（每次按键 / 每次输入）（10）

- ✅ 已修复 `c1818bff6` · OPEN **#1329** [Code editor still recounts totalLines from the full document on every keystroke after the #1278 line-table fix](https://github.com/CofficLab/Lumi/issues/1329)
- ⬜ 待处理 · CLOSED **#1317** [Code editor bracket matching rescans the document on the main actor on every edit and cursor move](https://github.com/CofficLab/Lumi/issues/1317)
- ✅ 已修复 `87ac26b0d` · OPEN **#1304** [Memory settings search re-filters the whole list four times per keystroke with no debounce or memoization](https://github.com/CofficLab/Lumi/issues/1304)
- ✅ 已修复 `80ce4fad9` · OPEN **#1298** [Input attachment preview re-decodes every pending image from Base64 on the main actor on each keystroke](https://github.com/CofficLab/Lumi/issues/1298)
- ✅ 已修复 `e3f355ca4` · OPEN **#1295** [Story Writer recomputes the uncached chapter word count on the main actor for every keystroke](https://github.com/CofficLab/Lumi/issues/1295)
- ✅ 已修复 `669aeb38d` · OPEN **#1279** [Code editor re-runs a full-document find regex on every keystroke, even after the find panel is closed](https://github.com/CofficLab/Lumi/issues/1279)
- ⬜ 待处理 · CLOSED **#1278** [Code editor rebuilds the full line-offset table on every keystroke and cursor move](https://github.com/CofficLab/Lumi/issues/1278)
- ✅ 已修复 `6eea7572b` · OPEN **#1267** [Brief/V1 performs quadratic parent-window rebuilds on every insertion](https://github.com/CofficLab/Lumi/issues/1267)
- ⬜ 待处理 · CLOSED **#1218** [Quick Launcher scans and rebuilds all app and command results on the main actor for every keystroke](https://github.com/CofficLab/Lumi/issues/1218)
- ✅ 已修复 `40a7c3b43` · OPEN **#1192** [Clipboard search scans up to 5,000 full-text records on every keystroke](https://github.com/CofficLab/Lumi/issues/1192)

## 主线程同步阻塞（IO / 编解码 / 导出）（173）

- ⬜ 待处理 · OPEN **#1327** [Workspace search eagerly splits and walks the entire unbounded ripgrep output on the main actor](https://github.com/CofficLab/Lumi/issues/1327)
- ⬜ 待处理 · OPEN **#1326** [Text Actions reads the selection through synchronous Accessibility IPC on the main actor with no messaging timeout](https://github.com/CofficLab/Lumi/issues/1326)
- ⬜ 待处理 · OPEN **#1324** [Conversation Fork decodes every history attachment Base64 payload on the main actor before keeping the last 60 messages](https://github.com/CofficLab/Lumi/issues/1324)
- ⬜ 待处理 · OPEN **#1323** [Draining a queued message re-encodes its image/file attachments on the main actor](https://github.com/CofficLab/Lumi/issues/1323)
- ⬜ 待处理 · OPEN **#1311** [Conversation store settings observer runs a synchronous main-actor message COUNT on every message event, even while the settings page is closed](https://github.com/CofficLab/Lumi/issues/1311)
- ⬜ 待处理 · OPEN **#1310** [Tool output re-encodes the entire 64 KiB tail on the main actor for every shell chunk](https://github.com/CofficLab/Lumi/issues/1310)
- ⬜ 待处理 · OPEN **#1308** [CAD Designer re-tessellates the whole SceneKit assembly on the main actor for every single-component property edit](https://github.com/CofficLab/Lumi/issues/1308)
- ⬜ 待处理 · OPEN **#1305** [Every clipboard change refetches the full 5,000-item history on the main actor, even when the panel is hidden](https://github.com/CofficLab/Lumi/issues/1305)
- ⬜ 待处理 · OPEN **#1303** [Tool Manager record detail lays out the entire multi-MB payload as one selectable Text on the main thread](https://github.com/CofficLab/Lumi/issues/1303)
- ⬜ 待处理 · OPEN **#1302** [Tool Manager stats fetch the entire call history and aggregate it on the main actor with no re-entry guard](https://github.com/CofficLab/Lumi/issues/1302)
- ⬜ 待处理 · OPEN **#1297** [browser_evaluate parses and pretty-prints an unbounded result on the main actor](https://github.com/CofficLab/Lumi/issues/1297)
- ⬜ 待处理 · OPEN **#1296** [File tree Open in Terminal runs a synchronous AppleScript on the main actor](https://github.com/CofficLab/Lumi/issues/1296)
- ⬜ 待处理 · CLOSED **#1294** [LLM Context save-as-image PNG-encodes and writes the export on the main actor](https://github.com/CofficLab/Lumi/issues/1294)
- ⬜ 待处理 · OPEN **#1293** [Device device_status(scope:processes) samples and sorts all processes on the main actor](https://github.com/CofficLab/Lumi/issues/1293)
- ⬜ 待处理 · OPEN **#1291** [App Icon Xcode icon-set export runs lint, render, PNG/manifest encode, and atomic file writes on the main actor](https://github.com/CofficLab/Lumi/issues/1291)
- ⬜ 待处理 · OPEN **#1290** [Prototype Designer re-lists every project and re-reads screen HTML from disk on the main actor on every rail click](https://github.com/CofficLab/Lumi/issues/1290)
- ⬜ 待处理 · OPEN **#1289** [App Icon preview_icon/review_icon rasterize and PNG-encode up to 4 MP on the main actor every agent iteration](https://github.com/CofficLab/Lumi/issues/1289)
- ⬜ 待处理 · OPEN **#1288** [project_overview blocks a cooperative thread on an untimed, uncancellable DispatchSemaphore (4× per call), starving the pool that schedules MainActor](https://github.com/CofficLab/Lumi/issues/1288)
- ⬜ 待处理 · OPEN **#1287** [Title placeholder runs a full-message ICU regex on the main actor to keep 40 characters](https://github.com/CofficLab/Lumi/issues/1287)
- ⬜ 待处理 · OPEN **#1286** [API-key card resolves the Keychain synchronously on the main actor, with Thread.sleep retries and blocking SecItemCopyMatching](https://github.com/CofficLab/Lumi/issues/1286)
- ⬜ 待处理 · OPEN **#1285** [v4 conversation migration copies the DB, opens a ModelContainer, and fetches all conversations on the main actor](https://github.com/CofficLab/Lumi/issues/1285)
- ⬜ 待处理 · OPEN **#1284** [Web API messages route materializes the whole conversation on the main actor before paginating](https://github.com/CofficLab/Lumi/issues/1284)
- ⬜ 待处理 · OPEN **#1282** [browser_screenshot encodes TIFF→PNG on the main actor, up to 3 times for full-page](https://github.com/CofficLab/Lumi/issues/1282)
- ⬜ 待处理 · OPEN **#1280** [HTML preview re-reads and re-compares the whole file from disk on every SwiftUI update, even when nothing changed](https://github.com/CofficLab/Lumi/issues/1280)
- ⬜ 待处理 · CLOSED **#1277** [Opening a file in the code editor reads the whole document synchronously on the main actor](https://github.com/CofficLab/Lumi/issues/1277)
- ⬜ 待处理 · CLOSED **#1276** [Code-editor highlight prewarm reads and tree-sitter-parses whole documents on the main actor](https://github.com/CofficLab/Lumi/issues/1276)
- ⬜ 待处理 · OPEN **#1275** [MCP tool schemas are re-decoded from JSON and re-serialized on the main actor on every LLM request](https://github.com/CofficLab/Lumi/issues/1275)
- ⬜ 待处理 · OPEN **#1274** [Tool-call renderer dispatch Base64-decodes every result image on the main actor, then discards it](https://github.com/CofficLab/Lumi/issues/1274)
- ⬜ 待处理 · OPEN **#1271** [Git repository watcher hashes the whole index and refs on the main actor](https://github.com/CofficLab/Lumi/issues/1271)
- ⬜ 待处理 · OPEN **#1270** [Non-streaming LLM responses are fully parsed three times on the main actor](https://github.com/CofficLab/Lumi/issues/1270)
- ⬜ 待处理 · OPEN **#1269** [Every streaming LLM request re-encodes all history images on the main actor](https://github.com/CofficLab/Lumi/issues/1269)
- ⬜ 待处理 · OPEN **#1268** [Every LLM request Base64-decodes all prepared-history images on the main actor](https://github.com/CofficLab/Lumi/issues/1268)
- ⬜ 待处理 · OPEN **#1266** [Screenshot dragging invalidates every full-screen overlay on every mouse update](https://github.com/CofficLab/Lumi/issues/1266)
- ⬜ 待处理 · OPEN **#1265** [Screenshot completion scales, JPEG-encodes, and Base64-encodes on the main actor](https://github.com/CofficLab/Lumi/issues/1265)
- ⬜ 待处理 · OPEN **#1264** [HTML Canvas cards synchronously reopen snapshot PNGs during view evaluation](https://github.com/CofficLab/Lumi/issues/1264)
- ⬜ 待处理 · OPEN **#1263** [show_html writes and rasterizes full-page snapshots on the main actor](https://github.com/CofficLab/Lumi/issues/1263)
- ⬜ 待处理 · OPEN **#1259** [Dropped image validation and Base64 encoding block the main actor](https://github.com/CofficLab/Lumi/issues/1259)
- ⬜ 待处理 · OPEN **#1254** [Database toolbar splits the whole SQL script on every SwiftUI invalidation](https://github.com/CofficLab/Lumi/issues/1254)
- ⬜ 待处理 · OPEN **#1253** [Database results recompute all column widths for every rendered cell](https://github.com/CofficLab/Lumi/issues/1253)
- ⬜ 待处理 · OPEN **#1251** [RAG idle scheduling synchronously probes every project path on the main actor](https://github.com/CofficLab/Lumi/issues/1251)
- ⬜ 待处理 · OPEN **#1250** [Editor configuration repeats whole-plist I/O on the main actor for every key](https://github.com/CofficLab/Lumi/issues/1250)
- ⬜ 待处理 · OPEN **#1248** [Story export writes the complete Markdown document synchronously on the UI thread](https://github.com/CofficLab/Lumi/issues/1248)
- ⬜ 待处理 · OPEN **#1243** [Explorer watcher rebuilds synchronously probe expanded paths and the project root on the UI thread](https://github.com/CofficLab/Lumi/issues/1243)
- ⬜ 待处理 · OPEN **#1241** [Project storage refreshes synchronously probe volumes from SwiftUI on the main actor](https://github.com/CofficLab/Lumi/issues/1241)
- ⬜ 待处理 · OPEN **#1240** [File-tree actions perform synchronous filesystem mutations on the main actor](https://github.com/CofficLab/Lumi/issues/1240)
- ⬜ 待处理 · OPEN **#1239** [Every project event rebuilds and republishes the O(F²) open-file tab projection](https://github.com/CofficLab/Lumi/issues/1239)
- ⬜ 待处理 · OPEN **#1238** [Open-file changes synchronously rewrite and reread the all-project JSON snapshot on the main actor](https://github.com/CofficLab/Lumi/issues/1238)
- ⬜ 待处理 · OPEN **#1237** [File-tree rebuild cancellation leaves detached filesystem traversals running](https://github.com/CofficLab/Lumi/issues/1237)
- ⬜ 待处理 · OPEN **#1236** [Every file-tree bridge update rebuilds and reapplies the full visible snapshot](https://github.com/CofficLab/Lumi/issues/1236)
- ⬜ 待处理 · OPEN **#1235** [Targeted file-tree refreshes recursively enumerate directories on the main actor](https://github.com/CofficLab/Lumi/issues/1235)
- ⬜ 待处理 · OPEN **#1234** [Every terminal shell start rewrites integration files on the main actor](https://github.com/CofficLab/Lumi/issues/1234)
- ⬜ 待处理 · OPEN **#1233** [Terminal accessibility value rebuilds scrollback plus visible text on the UI thread](https://github.com/CofficLab/Lumi/issues/1233)
- ⬜ 待处理 · OPEN **#1231** [Unselected terminal tabs keep full main-thread output and display work](https://github.com/CofficLab/Lumi/issues/1231)
- ⬜ 待处理 · OPEN **#1229** [Tool-result updates synchronously fetch, encode, and save SwiftData on the main actor](https://github.com/CofficLab/Lumi/issues/1229)
- ⬜ 待处理 · OPEN **#1226** [Conversation toolbars rebuild full message histories even while their popovers are closed](https://github.com/CofficLab/Lumi/issues/1226)
- ⬜ 待处理 · OPEN **#1225** [Conversation metric PNG exports rasterize, encode, and write on the main actor](https://github.com/CofficLab/Lumi/issues/1225)
- ⬜ 待处理 · OPEN **#1223** [Disk Manager performs uncached synchronous workspace icon lookups inside row bodies](https://github.com/CofficLab/Lumi/issues/1223)
- ⬜ 待处理 · OPEN **#1217** [Display slider and restore writes run DDC/I2C retry loops on the main actor](https://github.com/CofficLab/Lumi/issues/1217)
- ⬜ 待处理 · OPEN **#1216** [Display refresh performs DDC/I2C reads and retry sleeps on the main actor every five seconds](https://github.com/CofficLab/Lumi/issues/1216)
- ⬜ 待处理 · OPEN **#1215** [White Noise holds its render lock across the full audio buffer, blocking main-actor controls](https://github.com/CofficLab/Lumi/issues/1215)
- ⬜ 待处理 · OPEN **#1214** [Recent-only Network samples refilter the unchanged 30-day history chart](https://github.com/CofficLab/Lumi/issues/1214)
- ⬜ 待处理 · OPEN **#1212** [Network plugin configuration bypasses its background loader and decodes history on the main actor](https://github.com/CofficLab/Lumi/issues/1212)
- ⬜ 待处理 · OPEN **#1208** [Hosts backup import and export perform whole-file I/O on the main actor](https://github.com/CofficLab/Lumi/issues/1208)
- ⬜ 待处理 · OPEN **#1205** [Every Hosts entry toggle rewrites, rereads, and reparses the whole file on the main actor](https://github.com/CofficLab/Lumi/issues/1205)
- ⬜ 待处理 · OPEN **#1204** [Diagnostics export copies and installs the complete archive on the main actor](https://github.com/CofficLab/Lumi/issues/1204)
- ⬜ 待处理 · OPEN **#1203** [Git activity refresh reparses every commit and writes its cache on the main actor](https://github.com/CofficLab/Lumi/issues/1203)
- ⬜ 待处理 · OPEN **#1200** [Large HTTP body export formats and writes the entire payload on the UI thread](https://github.com/CofficLab/Lumi/issues/1200)
- ⬜ 待处理 · OPEN **#1199** [App Store Connect screenshot import opens every selected image on the main actor](https://github.com/CofficLab/Lumi/issues/1199)
- ⬜ 待处理 · OPEN **#1198** [Copying a clipboard image synchronously reloads its file on the main actor](https://github.com/CofficLab/Lumi/issues/1198)
- ⬜ 待处理 · OPEN **#1197** [ImageToPDF export copies every PDF synchronously on the main actor](https://github.com/CofficLab/Lumi/issues/1197)
- ⬜ 待处理 · OPEN **#1196** [ImageToPDF input rows synchronously open every image during view rendering](https://github.com/CofficLab/Lumi/issues/1196)
- ⬜ 待处理 · OPEN **#1195** [CAD PNG export rasterizes and encodes the complete viewport on the main actor](https://github.com/CofficLab/Lumi/issues/1195)
- ⬜ 待处理 · OPEN **#1194** [Editor Preview synchronously opens the selected image in its view body](https://github.com/CofficLab/Lumi/issues/1194)
- ⬜ 待处理 · OPEN **#1193** [Prototype export rasterizes and writes every screen on the main actor](https://github.com/CofficLab/Lumi/issues/1193)
- ⬜ 待处理 · OPEN **#1190** [Every MindMap edit rereads and decodes the entire map collection on the main actor](https://github.com/CofficLab/Lumi/issues/1190)
- ⬜ 待处理 · OPEN **#1189** [ImageToPDF output rows synchronously open and rasterize PDFs during view rendering](https://github.com/CofficLab/Lumi/issues/1189)
- ⬜ 待处理 · OPEN **#1186** [Opening tool arguments synchronously parses and pretty-prints the entire JSON payload](https://github.com/CofficLab/Lumi/issues/1186)
- ⬜ 待处理 · OPEN **#1184** [Markdown cache lock can block the main actor for the duration of a background parse](https://github.com/CofficLab/Lumi/issues/1184)
- ⬜ 待处理 · OPEN **#1180** [App Store Promo export encodes and writes every PNG on the main actor](https://github.com/CofficLab/Lumi/issues/1180)
- ⬜ 待处理 · OPEN **#1179** [Resume PNG export rasterizes and writes every page on the main actor](https://github.com/CofficLab/Lumi/issues/1179)
- ⬜ 待处理 · OPEN **#1177** [Resume Designer scans and reads documents synchronously on the main actor](https://github.com/CofficLab/Lumi/issues/1177)
- ⬜ 待处理 · CLOSED **#1176** [CAD Save and Load perform JSON coding and disk I/O on the main actor](https://github.com/CofficLab/Lumi/issues/1176)
- ⬜ 待处理 · CLOSED **#1167** [Whole-JSON Anthropic fallback drops redacted thinking blocks](https://github.com/CofficLab/Lumi/issues/1167)
- ⬜ 待处理 · OPEN **#1160** [Redesign compaction: fold-once hierarchical summary blocks and prefix-preserving compression, instead of rolling summary-of-summary](https://github.com/CofficLab/Lumi/issues/1160)
- ⬜ 待处理 · CLOSED **#1149** [Responses API refusal blocks are decoded as empty successful replies](https://github.com/CofficLab/Lumi/issues/1149)
- ⬜ 待处理 · CLOSED **#977** [network_download_file 绕过 HTTPExchangeStore，下载不会出现在 HTTP 日志](https://github.com/CofficLab/Lumi/issues/977)
- ⬜ 待处理 · CLOSED **#912** [打开仓库子目录时 Git Changes 识别为仓库却无法读取状态和提交](https://github.com/CofficLab/Lumi/issues/912)
- ⬜ 待处理 · CLOSED **#911** [内置编辑器保存不会触发 Git 工作区刷新，已打开的 Changes 保持旧状态](https://github.com/CofficLab/Lumi/issues/911)
- ⬜ 待处理 · CLOSED **#902** [Device About 的 Memory Monitor 缺少本地化资源，中文界面保留英文](https://github.com/CofficLab/Lumi/issues/902)
- ⬜ 待处理 · OPEN **#882** [The input field treats the dragged HTTPS/mailto links as file attachments and blocks the default text handling](https://github.com/CofficLab/Lumi/issues/882)
- ⬜ 待处理 · OPEN **#865** [DisplayControl leaks the CoreDisplay Create-rule dictionary on every refresh](https://github.com/CofficLab/Lumi/issues/865)
- ⬜ 待处理 · OPEN **#853** [The Conversation Fork waits for the whole automatic reply to end, so the popover stays in the summary loading state for a long time](https://github.com/CofficLab/Lumi/issues/853)
- ⬜ 待处理 · OPEN **#842** [The Mail "load more" only re-reads the first page cache, so the older mails on the server can never be displayed](https://github.com/CofficLab/Lumi/issues/842)
- ⬜ 待处理 · OPEN **#835** [The state and the snapshot of the Browser still show the old title after document.title is changed at runtime](https://github.com/CofficLab/Lumi/issues/835)
- ⬜ 待处理 · OPEN **#832** [browser_interact still reports success when the click on a covered non-link element is blocked](https://github.com/CofficLab/Lumi/issues/832)
- ⬜ 待处理 · OPEN **#826** [The computer_act of the A3 autonomous mode is blocked by the persisted native authorization check](https://github.com/CofficLab/Lumi/issues/826)
- ⬜ 待处理 · OPEN **#817** [Neither of the two cache layers of the version localization list is invalidated after a localization update](https://github.com/CofficLab/Lumi/issues/817)
- ⬜ 待处理 · OPEN **#816** [The L1 cache is not invalidated after an Xcode Cloud mutation, so a new build is immediately overwritten by the old list](https://github.com/CofficLab/Lumi/issues/816)
- ⬜ 待处理 · OPEN **#813** [The context calibration factor is not used for the deterministicFallback trimming, so the emergency retry can resend an over-budget history unchanged](https://github.com/CofficLab/Lumi/issues/813)
- ⬜ 待处理 · CLOSED **#809** [delete_memory still reports a successful deletion for a memory that does not exist](https://github.com/CofficLab/Lumi/issues/809)
- ⬜ 待处理 · OPEN **#808** [The Git change count of the project card misses the untracked files and counts some staged files twice](https://github.com/CofficLab/Lumi/issues/808)
- ⬜ 待处理 · OPEN **#806** [The activity card of the empty state does not invalidate the same-day cache, so the message and token statistics stay stale](https://github.com/CofficLab/Lumi/issues/806)
- ⬜ 待处理 · OPEN **#802** [The Running indicator stays wrongly lit while waiting for the answer to ask_user](https://github.com/CofficLab/Lumi/issues/802)
- ⬜ 待处理 · OPEN **#794** [An app without a Bundle ID cannot be uninstalled and the app itself is not added to the list of the files to delete](https://github.com/CofficLab/Lumi/issues/794)
- ⬜ 待处理 · OPEN **#788** [recall_memory misreports an existing but unreadable memory as Not Found](https://github.com/CofficLab/Lumi/issues/788)
- ⬜ 待处理 · OPEN **#787** [A suspension waiting for the user input is notified as the end of the turn, and the same turn notifies again after the resume](https://github.com/CofficLab/Lumi/issues/787)
- ⬜ 待处理 · OPEN **#780** [The asynchronous read of a dropped attachment is not bound to the conversation, so an old file ends up in the pending pool of the new conversation](https://github.com/CofficLab/Lumi/issues/780)
- ⬜ 待处理 · OPEN **#776** [The Caffeinate plugin does not release the power assertion when it is disabled, so it keeps preventing sleep after a failed uninstall recovery](https://github.com/CofficLab/Lumi/issues/776)
- ⬜ 待处理 · CLOSED **#741** [Memory 不同 ID 清洗后碰撞，会互相覆盖、召回和删除](https://github.com/CofficLab/Lumi/issues/741)
- ⬜ 待处理 · CLOSED **#697** [Goal 分叉保留 blocked 状态却丢失阻塞原因](https://github.com/CofficLab/Lumi/issues/697)
- ⬜ 待处理 · CLOSED **#669** [set_age_rating cannot set 'socialMedia', which blocks review submission with a 409 that the tool can never resolve](https://github.com/CofficLab/Lumi/issues/669)
- ⬜ 待处理 · CLOSED **#665** [get_http_exchange_detail 声明支持按 ID 查询，schema 却强制要求 URL](https://github.com/CofficLab/Lumi/issues/665)
- ⬜ 待处理 · CLOSED **#663** [get_http_exchange_detail 只查最新 1000 条，按 UUID 找不到仍保留的旧记录](https://github.com/CofficLab/Lumi/issues/663)
- ⬜ 待处理 · OPEN **#656** [The Homebrew uninstall executes immediately on a single click, without the confirmation step of the documentation](https://github.com/CofficLab/Lumi/issues/656)
- ⬜ 待处理 · OPEN **#655** [The Homebrew Tap Formula loses its full_name and the installation falls onto the same-named Core package](https://github.com/CofficLab/Lumi/issues/655)
- ⬜ 待处理 · OPEN **#647** [The app uninstall only matches by the directory name of the same name and moves the data of another vendor's app to the Trash](https://github.com/CofficLab/Lumi/issues/647)
- ⬜ 待处理 · OPEN **#642** [The refresh of the skill settings page still reads the 30-second cache, so external file changes are invisible](https://github.com/CofficLab/Lumi/issues/642)
- ⬜ 待处理 · OPEN **#632** [The new conversation suggestion card forgets that it was started after a rebuild and can send the same task again](https://github.com/CofficLab/Lumi/issues/632)
- ⬜ 待处理 · OPEN **#608** [Switching the automation level in an existing conversation silently changes the default mode of the new conversations](https://github.com/CofficLab/Lumi/issues/608)
- ⬜ 待处理 · OPEN **#607** [The Memory tools ignore the conversation project, so a background turn reads and writes the memories of the currently open project](https://github.com/CofficLab/Lumi/issues/607)
- ⬜ 待处理 · OPEN **#572** [After renaming an already open file in the Explorer the tab still points at the old path and the changes cannot be saved](https://github.com/CofficLab/Lumi/issues/572)
- ⬜ 待处理 · OPEN **#568** [A nullable SQLite primary key row is updated and deleted with = NULL, so the original row stays unchanged](https://github.com/CofficLab/Lumi/issues/568)
- ⬜ 待处理 · OPEN **#562** [The context degradation truncates the tool call arguments, produces invalid JSON and blocks the subsequent request](https://github.com/CofficLab/Lumi/issues/562)
- ⬜ 待处理 · OPEN **#554** [Editing a database text cell silently changes the value, the type or clears the content](https://github.com/CofficLab/Lumi/issues/554)
- ⬜ 待处理 · OPEN **#528** [A description containing --- in a Memory breaks the frontmatter parsing and the body](https://github.com/CofficLab/Lumi/issues/528)
- ⬜ 待处理 · OPEN **#508** [A new message sent during a Retry-After wait inherits the retry budget of the previous turn](https://github.com/CofficLab/Lumi/issues/508)
- ⬜ 待处理 · OPEN **#505** [The Activity Heatmap ignores headChanged, so it keeps showing the old commits after a branch switch](https://github.com/CofficLab/Lumi/issues/505)
- ⬜ 待处理 · OPEN **#504** [The Activity Heatmap permanently counts the same message and tokens twice after a time zone change](https://github.com/CofficLab/Lumi/issues/504)
- ⬜ 待处理 · OPEN **#495** [Sending a block to the assistant mixes the Lumi floating button into the source HTML](https://github.com/CofficLab/Lumi/issues/495)
- ⬜ 待处理 · OPEN **#490** [The CLI uninstall treats an executable directory as a script and recursively deletes the whole lumi directory](https://github.com/CofficLab/Lumi/issues/490)
- ⬜ 待处理 · OPEN **#466** [The startup title backfill overwrites a new title that was set during the asynchronous read](https://github.com/CofficLab/Lumi/issues/466)
- ⬜ 待处理 · OPEN **#461** [The IdleTime listener waits for a save notification that is never sent, so no file save activity is recorded at all](https://github.com/CofficLab/Lumi/issues/461)
- ⬜ 待处理 · OPEN **#456** [A fresh install never requests the system authorization for the turn completion notification and the sound](https://github.com/CofficLab/Lumi/issues/456)
- ⬜ 待处理 · OPEN **#455** [The White Noise stops permanently after an output device or sample rate change and still shows as playing](https://github.com/CofficLab/Lumi/issues/455)
- ⬜ 待处理 · OPEN **#419** [Cancelling browser_open or a navigation does not stop the page load and the task still waits for the 30 second timeout](https://github.com/CofficLab/Lumi/issues/419)
- ⬜ 待处理 · OPEN **#397** [A local dirty edit is wrongly reported as an external file conflict even when the disk has not changed at all](https://github.com/CofficLab/Lumi/issues/397)
- ⬜ 待处理 · OPEN **#383** [The Device initialization order prevents the memory history from loading and it gets overwritten by the new session](https://github.com/CofficLab/Lumi/issues/383)
- ⬜ 待处理 · OPEN **#376** [Reopening the Cmd+P search panel does not trigger a rebuild of the expired index](https://github.com/CofficLab/Lumi/issues/376)
- ⬜ 待处理 · OPEN **#371** [A refs change of the current repository wrongly clears the heatmap of another project](https://github.com/CofficLab/Lumi/issues/371)
- ⬜ 待处理 · OPEN **#357** [The Git workspace watcher permanently drops the last change within the throttle window](https://github.com/CofficLab/Lumi/issues/357)
- ⬜ 待处理 · OPEN **#355** [A numeric ACP JSON-RPC ID changes after a Double round trip, so the response cannot be correlated with the original request](https://github.com/CofficLab/Lumi/issues/355)
- ⬜ 待处理 · OPEN **#340** [The Markdown incremental cache treats a blank line inside a code block as a stable boundary, so the code block is split wrongly after an append](https://github.com/CofficLab/Lumi/issues/340)
- ⬜ 待处理 · OPEN **#324** [The official ../assets path of a Prototype is blocked by the WebKit read permission, so the preview and the export fail](https://github.com/CofficLab/Lumi/issues/324)
- ⬜ 待处理 · OPEN **#311** [include_body=true of get_http_exchange_detail still completely misses the response body](https://github.com/CofficLab/Lumi/issues/311)
- ⬜ 待处理 · OPEN **#304** [Clicking Close after a failed uninstall only restores the window, and the stopped and unregistered kernel is never restored](https://github.com/CofficLab/Lumi/issues/304)
- ⬜ 待处理 · OPEN **#293** [The App Icon export failure is hidden by the early synchronization of objectWillChange, and an old error can never be cleared](https://github.com/CofficLab/Lumi/issues/293)
- ⬜ 待处理 · OPEN **#271** [Cancelling a DOCX read does not terminate textutil, so the Job still waits for the process to finish](https://github.com/CofficLab/Lumi/issues/271)
- ⬜ 待处理 · OPEN **#268** [browser_read renumbers refs even when the page has not changed, so later operations may hit the wrong control](https://github.com/CofficLab/Lumi/issues/268)
- ⬜ 待处理 · OPEN **#263** [The file selection can be cleared or changed during a video conversion, so the old task's result is written into the new file's state](https://github.com/CofficLab/Lumi/issues/263)
- ⬜ 待处理 · OPEN **#262** [VideoConverter's synchronous waitUntilExit blocks the actor, so there is no progress during the conversion and Cancel cannot get in](https://github.com/CofficLab/Lumi/issues/262)
- ⬜ 待处理 · OPEN **#241** [DisplayControl performs DDC retries and sleeps on the main thread every five seconds, stalling the whole app](https://github.com/CofficLab/Lumi/issues/241)
- ⬜ 待处理 · OPEN **#239** [The timed sleep prevention shows as indefinite in the menu, and switching the mode also clears the countdown](https://github.com/CofficLab/Lumi/issues/239)
- ⬜ 待处理 · OPEN **#235** [After switching the update channel, a waiting old check bypasses the new channel's feed probe](https://github.com/CofficLab/Lumi/issues/235)
- ⬜ 待处理 · OPEN **#229** [System monitoring never samples disk I/O, so the read/write rate stays at zero](https://github.com/CofficLab/Lumi/issues/229)
- ⬜ 待处理 · CLOSED **#212** [The Homebrew cask's installed string is discarded, so installed software still shows Install and a wrong version](https://github.com/CofficLab/Lumi/issues/212)
- ⬜ 待处理 · OPEN **#209** [The video converter fully decodes the file to probe the duration, so the stderr pipe can deadlock and Cancel has no effect](https://github.com/CofficLab/Lumi/issues/209)
- ⬜ 待处理 · OPEN **#208** [The toolbar's Current Project list does not observe project switches, so it still shows the old project's conversations after the title has changed](https://github.com/CofficLab/Lumi/issues/208)
- ⬜ 待处理 · CLOSED **#207** [The paginated list can load the 41st conversation, but deleting it returns immediately because the in-memory cache is missing](https://github.com/CofficLab/Lumi/issues/207)
- ⬜ 待处理 · OPEN **#206** [The async re-read of an external file does not verify the current tab, so A's content can overwrite B and be saved](https://github.com/CofficLab/Lumi/issues/206)
- ⬜ 待处理 · OPEN **#204** [When the input block Provider replays multiple blocks at startup, the single-slot pendingBlock keeps only the last one](https://github.com/CofficLab/Lumi/issues/204)
- ⬜ 待处理 · OPEN **#201** [The WebServer StartGate loses startup results that arrive before the continuation, so start hangs forever](https://github.com/CofficLab/Lumi/issues/201)
- ⬜ 待处理 · CLOSED **#198** [The id of save_memory allows path traversal, allowing Markdown files to be written outside the Memory root directory](https://github.com/CofficLab/Lumi/issues/198)
- ⬜ 待处理 · CLOSED **#197** [The Memory project path sanitization collides, so different projects read, overwrite and delete the same memory](https://github.com/CofficLab/Lumi/issues/197)
- ⬜ 待处理 · OPEN **#188** [A Goal stays permanently in in_progress after some tasks succeed and some fail, and blocks the creation of new Goals](https://github.com/CofficLab/Lumi/issues/188)
- ⬜ 待处理 · CLOSED **#183** [The file tree watcher explicitly skips the project root, so external additions, deletions and changes to root-level files do not refresh](https://github.com/CofficLab/Lumi/issues/183)
- ⬜ 待处理 · OPEN **#178** [Cancelling an MCP tool call only cancels the outer Task, so the underlying request never ends and the Job can wait forever](https://github.com/CofficLab/Lumi/issues/178)
- ⬜ 待处理 · OPEN **#175** [The PTY master descriptor is not closed after the terminal shell exits naturally, leaking file descriptors over long runs](https://github.com/CofficLab/Lumi/issues/175)
- ⬜ 待处理 · CLOSED **#169** [The conversation language preference is only updated in memory, so neither creating nor modifying a conversation persists it](https://github.com/CofficLab/Lumi/issues/169)
- ⬜ 待处理 · OPEN **#168** [After a crash in the second round or later, the previous round's final reply blocks the resume prompt](https://github.com/CofficLab/Lumi/issues/168)
- ⬜ 待处理 · CLOSED **#156** [The HEAD snapshot of a linked worktree is always nil, so commits and branch switches cannot trigger headChanged](https://github.com/CofficLab/Lumi/issues/156)
- ⬜ 待处理 · OPEN **#141** [MCPPlugin weakly captures the manager on shutdown and immediately releases it, so the asynchronous session disconnect may be skipped](https://github.com/CofficLab/Lumi/issues/141)
- ⬜ 待处理 · OPEN **#134** [CLI install and uninstall do not verify file ownership, overwriting and deleting a pre-existing program with the same name](https://github.com/CofficLab/Lumi/issues/134)
- ⬜ 待处理 · CLOSED **#125** [ProviderChatSection 测试用 1ms 固定 sleep 等待异步通知，整包运行时稳定失败](https://github.com/CofficLab/Lumi/issues/125)

## 高频轮询与定时器（6）

- ✅ 已修复 `d2c21ba4d` · OPEN **#1272** [App-window screen recording enumerates every on-screen window on the main actor once per second](https://github.com/CofficLab/Lumi/issues/1272)
- ✅ 已修复 `97850fb00` · OPEN **#1245** [Editor Preview polls Markdown file metadata synchronously on the main actor every second](https://github.com/CofficLab/Lumi/issues/1245)
- ✔️ 此前已修复 `b92a3c66b` · OPEN **#1213** [Each 1 Hz Network sample records four history points and four UI updates](https://github.com/CofficLab/Lumi/issues/1213)
- ✅ 已修复 `40307bf47` · OPEN **#775** [Multiple copies within the same 500ms polling interval only keep the last value](https://github.com/CofficLab/Lumi/issues/775)
- ✅ 已修复 `40307bf47` · OPEN **#423** [After the clipboard plugin is disabled at runtime, the monitoring timer and the image processing keep running](https://github.com/CofficLab/Lumi/issues/423)
- ✅ 已修复 `0be0fc533` · OPEN **#418** [After cancelling browser_wait the polling keeps running and the navigation condition busy-waits until the timeout](https://github.com/CofficLab/Lumi/issues/418)

## SwiftUI 重渲染与布局快照重建（7）

- ✔️ 此前已修复 `0f5a7fd` · OPEN **#1301** [ZCode bottom tracker re-scans the entire window's NSView hierarchy on every layout pass](https://github.com/CofficLab/Lumi/issues/1301)
- ✅ 已修复 `fe62ff3bd` · OPEN **#1300** [Git chat-toolbar button recomputes the full sorted workingChanges() twice per body evaluation](https://github.com/CofficLab/Lumi/issues/1300)
- ✅ 已修复 `867dc2b2b` · OPEN **#1273** [Collapsed ZCode reasoning blocks re-scan the entire reasoning text on every body evaluation](https://github.com/CofficLab/Lumi/issues/1273)
- ✅ 已修复 `1d16f1672` · OPEN **#1224** [Conversation metric charts rebuild full-history paths during hover interaction](https://github.com/CofficLab/Lumi/issues/1224)
- ✅ 已修复 `b23314d93` · OPEN **#1211** [Network 30-day chart recomputes full-history geometry many times per hover update](https://github.com/CofficLab/Lumi/issues/1211)
- 📦 外置仓库 · OPEN **#1206** [Device 30-day charts rebuild and linearly scan every point on each hover update](https://github.com/CofficLab/Lumi/issues/1206)
- ⬜ 待处理 · CLOSED **#147** [The Detailed history fingerprint omits reasoning and tool result content, so real updates skip the redraw](https://github.com/CofficLab/Lumi/issues/147)

## N² / 全量重扫算法复杂度（10）

- ⬜ 待处理 · OPEN **#1309** [Streaming provider re-copies the entire accumulated response on every chunk (quadratic main-thread work)](https://github.com/CofficLab/Lumi/issues/1309)
- ⬜ 待处理 · OPEN **#1292** [App Icon document store re-scans and decodes every document from disk on the main actor per list call and after every write tool](https://github.com/CofficLab/Lumi/issues/1292)
- ⬜ 待处理 · OPEN **#1283** [Git Workspace panel renders the working tree in O(N²) on the main actor](https://github.com/CofficLab/Lumi/issues/1283)
- ⬜ 待处理 · OPEN **#1260** [Tool Activity rescans and resorts all jobs for every output event](https://github.com/CofficLab/Lumi/issues/1260)
- ⬜ 待处理 · OPEN **#1256** [Compaction duplicate detection reloads full history on the main actor](https://github.com/CofficLab/Lumi/issues/1256)
- ⬜ 待处理 · OPEN **#1255** [Model selector rescans the whole model pool for every rendered row](https://github.com/CofficLab/Lumi/issues/1255)
- ⬜ 待处理 · OPEN **#1220** [App Manager refresh performs O(N²) main-actor search filtering during size updates](https://github.com/CofficLab/Lumi/issues/1220)
- ⬜ 待处理 · OPEN **#1202** [MindMap export blocks the UI with quadratic Markdown traversal and synchronous writes](https://github.com/CofficLab/Lumi/issues/1202)
- ⬜ 待处理 · OPEN **#1191** [MindMap pan and zoom recompute an O(N²) layout for every gesture update](https://github.com/CofficLab/Lumi/issues/1191)
- ⬜ 待处理 · OPEN **#1178** [Every App Store Promo selection rescans all tasks on the main actor](https://github.com/CofficLab/Lumi/issues/1178)

## 后台进程与 CPU 占用（7）

- 📦 外置仓库 · OPEN **#1306** [Device CPU detail renders the full process list non-lazily, re-materializing every row on each 1 Hz update](https://github.com/CofficLab/Lumi/issues/1306)
- 📦 外置仓库 · OPEN **#1210** [Each 1 Hz CPU update records six history points and publishes six UI updates](https://github.com/CofficLab/Lumi/issues/1210)
- 📦 外置仓库 · OPEN **#1209** [1 Hz CPU samples invalidate and refilter the unchanged 30-day history chart](https://github.com/CofficLab/Lumi/issues/1209)
- ⬜ 待处理 · OPEN **#1207** [Device plugin boot reads and decodes the full CPU history on the main actor](https://github.com/CofficLab/Lumi/issues/1207)
- ⬜ 待处理 · OPEN **#382** [Device writes several CPU/Memory history points per sample, so a one-hour window only holds 10/30 minutes](https://github.com/CofficLab/Lumi/issues/382)
- ✔️ 此前已修复 `c5bbeb20c` · OPEN **#129** [FileLogCoordinator polls logs with a synchronous XPC OSLogStore.getEntries call every 2 seconds, dragging OSLogService to 60-80% CPU after long runs](https://github.com/CofficLab/Lumi/issues/129)
- ✔️ 此前已修复 `3912fa25e / ba2f8f2d8` · OPEN **#128** [PluginNetworkManager enables a permanently looping nettop child process by default and fetches icons through synchronous LaunchServices calls on every flush, still burning 130% CPU while idle](https://github.com/CofficLab/Lumi/issues/128)
