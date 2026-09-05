# Lumi 磁盘清理功能改进计划

> 计划日期：2026-09-05
> 范围：Lumi 磁盘清理相关能力（`Packages/PluginAppManager`、`Packages/PluginDevice`）
> 依据：对 Lumi 现有源码的静态审读，所有改动点均标注代码位置

---

## 目录

- [一、目标](#一目标)
- [二、P0 — 高价值改进](#二p0--高价值改进)
- [三、P1 — 安全机制强化](#三p1--安全机制强化)
- [四、P2 — 性能与体验](#四p2--性能与体验)
- [五、落地顺序与依赖](#五落地顺序与依赖)
- [六、附录：涉及代码路径](#六附录涉及代码路径)

---

## 一、目标

当前磁盘清理能力实质上是「应用卸载器」：扫描已安装应用 → 计算大小 → 按 Bundle ID / 应用名匹配关联文件 → 移入废纸篓；叠加 PluginDevice 的磁盘容量 / I/O 监控。本计划将其扩展为**系统级磁盘清理能力**，按优先级分三档落地：

- **P0**：补齐功能缺口（磁盘空间分析、系统级分类清理、孤儿数据检测、共享数据保护）
- **P1**：强化删除安全机制（二次校验、符号链接拒绝、进程守卫、白名单）
- **P2**：性能与体验（并行计算、清理报告、批量卸载、年龄分类、废纸篓入口）

---

## 二、P0 — 高价值改进

### 1. 磁盘空间分析页

**现状**：仅有卷级容量（总量 / 可用 / 使用率）与 I/O 速度监控（`StorageModels.swift`、`SystemMonitorView.swift`），用户看到磁盘满了却不知道空间被谁占用。

**要做什么**：

- 新增目录级空间分布视图：扫描用户主目录及关键位置，按目录大小排序展示，支持选中后移入废纸篓。
- 内置"洞察入口"，直接定位典型空间大户：
  - iOS 备份：`~/Library/Application Support/MobileSync/Backup`
  - 旧下载文件：`~/Downloads` 下 90 天以上未修改的文件
  - Xcode 残留：`~/Library/Developer/Xcode/DerivedData`、`Archives`、`~/Library/Developer/CoreSimulator/Devices`
  - Docker / 容器数据：`~/Library/Containers` 下的大体积应用容器
  - 各语言包管理器缓存：`~/Library/Caches` 下的 Homebrew / pip / gradle / CocoaPods 等
- 界面形态：SwiftUI 列表或树图，展示路径 / 大小 / 类型标签；删除前展示确认清单。

**实现要点**：

- 大小统计复用 `AppService.calculateSize` 的语义，但必须并行化并加超时预算（见 P2-9）。
- 洞察入口按"路径存在才展示"原则构建，避免空目录噪音。
- 删除通道沿用 `trashItem` 移入废纸篓。

**涉及位置**：新增，可基于 `PluginDevice` 扩展；复用 `AppService.swift` 的路径与删除逻辑。

### 2. 系统级分类清理

**现状**：关联文件清理仅覆盖"选中应用的 Caches / Logs 等目录"（`AppCleanerHelper.scanRelatedFiles`），无面向全系统的分类清理入口。

**要做什么**：

- 新增分类清理页，按类别聚合展示可回收项：
  - **浏览器缓存**：Safari / Chrome / Edge 等缓存与 Service Worker 缓存；保护登录态与正在使用的站点数据。
  - **开发工具缓存**：npm / uv / pip / gradle / CocoaPods 等包管理器缓存。
  - **系统日志与临时文件**：`~/Library/Logs`、`/private/var/folders` 下的用户临时文件。
  - **废纸篓**：一键清空（带预览与确认）。
- 每类展示"预计可回收大小"，执行前提供干跑预览（仅统计不删除），确认后执行。

**实现要点**：

- 新增分类扫描 Service，各分类独立实现扫描与统计，避免相互阻塞。
- 干跑预览返回结构化清单（路径 + 大小），与真实删除共用同一份清单生成逻辑，保证"预览即所见"。
- 删除前对浏览器类做进程检查（见 P1-7）。

**涉及位置**：新增 Service；删除通道可复用 `AppService.deleteFiles`。

### 3. 孤儿应用数据检测

**现状**：应用卸载只清理当前选中应用的关联文件；应用被直接拖入废纸篓后，其在 `~/Library` 下的残留无人处理。

**要做什么**：

- 基于 `scanInstalledApps` 已扫描的已安装应用清单，反向扫描 `~/Library/Caches`、`~/Library/Application Support`、`~/Library/Containers` 等目录。
- 找出不在已安装清单中的 Bundle ID 目录，视为孤儿残留候选。
- 增加**未活动时间阈值**（默认 30 天）：目录最后修改时间早于阈值才进入候选，避免误伤活跃数据。
- 增加**敏感数据保护**：对含密钥、凭据、会话等安全关键数据的模式（如 Keychain 相关目录、`.plist` 中的认证类文件）一律跳过或默认不选。
- 删除前用 Spotlight（`mdls` / `mdfind`）交叉验证该 Bundle ID 确实不存在对应安装应用。

**实现要点**：

- 复用 `AppService.scanInstalledApps` 的扫描结果作为"有效 Bundle ID 集合"。
- 候选列表默认**全部不勾选**，由用户显式确认后清理（与现有卸载流程默认全选相反，安全优先）。

**涉及位置**：新增；基于 `AppService.scanInstalledApps`、`AppCleanerHelper` 的目录策略扩展。

### 4. 共享数据保护

**现状**：`AppCleanerHelper.scanRelatedFiles` 按**应用名**匹配 `Application Support` 下的目录（如 "Adobe"）。卸载单个 Adobe 应用时，同名目录可能被多个 Adobe 应用共享，直接删除会误伤其他仍安装的应用的数据。

**要做什么**：

- 删除关联文件前，校验每个候选目录是否被其他**已安装应用**引用：
  - 方式一：检查其他 app Bundle 的 Info.plist / 沙盒容器路径是否引用该目录。
  - 方式二：对匹配到的共享目录（尤其 Application Support 下按名称匹配的目录），列出"可能共享此目录的其他应用"，由用户确认。
- 被判定为共享且仍被其他应用使用的目录，从删除清单中剔除并注明原因。

**实现要点**：

- 在 `scanRelatedFiles` 收集阶段增加"共享引用检查"步骤，产出每个候选的 `isShared` 标记。
- 界面在共享项上显示警示标记，默认不勾选。

**涉及位置**：`AppCleanerHelper.scanRelatedFiles`、`AppService.scanRelatedFiles`。

---

## 三、P1 — 安全机制强化

### 5. 删除前二次校验（防 TOCTOU）

**现状**：`deleteFiles` 直接对扫描时得到的路径执行 `trashItem`，扫描与删除之间存在时间窗口，目标路径可能被替换（TOCTOU 竞态）。

**要做什么**：

- 扫描阶段为每个候选记录路径身份快照：inode / 文件系统对象 ID、父目录身份、目标类型。
- 删除前对快照二次校验：路径的 inode 与父目录未变化才允许删除；身份不一致则跳过并记录。
- 若目标为目录，校验其仍位于预期的父目录内（拒绝越界）。

**涉及位置**：`AppService.deleteFiles`、`AppService.scanRelatedFiles`。

### 6. 符号链接拒绝

**现状**：删除前仅做字符串级路径检查（`AppCleanerHelper.isValidDeletionTarget`），不解析符号链接，存在经符号链接删除外部对象的风险。

**要做什么**：

- 扫描与删除两个阶段均解析真实路径（`URL.resolvingSymlinksInPath`）。
- 候选路径经符号链接指向缓存根目录之外时，拒绝该候选。
- 目录级删除前验证"物理路径"与"扫描时路径"一致。

**涉及位置**：`AppCleanerHelper.scanRelatedFiles`、`AppService.deleteFiles`。

### 7. 进程守卫

**现状**：清理缓存不检查目标应用是否正在运行。

**要做什么**：

- 清理 Safari / Chrome 等浏览器缓存、Xcode / Simulator 相关缓存前，用 `NSRunningApplication` 检查对应进程。
- 进程运行中则跳过该类清理，并在结果中注明"跳过原因：应用正在运行"。

**涉及位置**：新增守卫逻辑，接入分类清理（P0-2）与关联文件删除流程。

### 8. 白名单机制

**现状**：无用户可配置的受保护路径。

**要做什么**：

- 提供"受保护路径"配置，用户可添加任意路径；配置持久化到本地（如 `~/Library/Application Support/<bundleID>/` 下的配置文件）。
- 所有清理流程（扫描、预览、删除）统一尊重白名单：命中白名单的候选一律跳过并标注。

**涉及位置**：新增配置存储 + 在 `AppCleanerHelper`、分类清理 Service 中接入检查。

---

## 四、P2 — 性能与体验

### 9. 大小计算并行化

**现状**：`AppService.calculateSize` 使用 `FileManager.enumerator` 串行递归统计文件大小，对 Xcode 缓存等大目录可能阻塞数秒，且无超时。

**要做什么**：

- 目录大小统计改用 `du` 子进程，或并行分块枚举 + 结果合并。
- 为单目录统计设置超时预算，超时返回部分结果并标记"估算值"。
- 按机器核数控制并行度，避免 IO 打满。

**涉及位置**：`AppService.calculateSize`。

### 10. 清理报告与审计日志

**现状**：删除后无汇总反馈，无操作记录。

**要做什么**：

- 每次清理结束展示报告：释放总量、分项明细（每类 / 每项释放大小）、清理前后磁盘剩余变化。
- 清理操作写入本地审计日志（时间、路径、大小、结果），提供查看入口。

**涉及位置**：`AppManagerViewModel` 删除流程 + 新增日志存储。

### 11. 批量卸载

**现状**：`AppManagerViewModel` 逐应用扫描 / 删除，无批量流程。

**要做什么**：

- 应用列表增加多选模式，支持一次选择多个应用批量卸载。
- 批量流程复用单应用的安全检查与确认，展示合计可释放空间。

**涉及位置**：`AppManagerViewModel`、`Views/AppManagerDetailView.swift`。

### 12. 按文件年龄分类

**现状**：关联文件清理不区分新旧，全部展示。

**要做什么**：

- 缓存 / 日志类候选按最后修改时间分组：30 天以上为"可安全清理"，30 天以内为"活跃缓存"。
- 活跃缓存默认不勾选，避免删除正在使用的数据。

**涉及位置**：`AppCleanerHelper.scanRelatedFiles`、`RelatedFile` 模型。

### 13. 废纸篓与残留清理入口

**现状**：无废纸篓一键清理、最近使用项清理、未完成下载清理。

**要做什么**：

- 废纸篓：展示当前占用大小，一键清空（带确认）。
- 最近使用项：清理 `~/Library/Application Support/com.apple.sharedfilelist` 等位置的过期条目。
- 未完成下载：扫描 `~/Downloads` 下 `.download` / `.crdownload` 后缀的未完成文件，确认后清理。

**涉及位置**：新增，并入分类清理页（P0-2）。

---

## 五、落地顺序与依赖

| 顺序 | 改进项 | 依赖 |
| --- | --- | --- |
| 1 | P1-8 白名单机制 | 无（基础能力，后续所有清理流程复用） |
| 2 | P2-9 大小计算并行化 | 无（性能基础） |
| 3 | P0-2 系统级分类清理 | 依赖 P1-8、P2-9、P1-7 |
| 4 | P0-1 磁盘空间分析页 | 依赖 P2-9 |
| 5 | P1-5 / P1-6 删除安全 | 依赖 P0-2 上线后接入 |
| 6 | P0-3 孤儿数据检测 | 依赖 P1-5 / P1-6 |
| 7 | P0-4 共享数据保护 | 无 |
| 8 | P2-10 / P2-11 / P2-12 / P2-13 | 依赖 P0-2 |

建议先落地 1-2（基础能力），再实现 3-4（核心功能），随后以安全机制（5）兜底上线删除流程，最后补齐孤儿检测与体验项。

---

## 六、附录：涉及代码路径

| 功能 | 路径 |
| --- | --- |
| 应用扫描 / 大小计算 / 关联文件 / 删除 | `Packages/PluginAppManager/Sources/Services/AppService.swift` |
| 关联文件扫描（名称匹配风险点） | `Packages/PluginAppManager/Sources/Services/AppCleanerHelper.swift` |
| SwiftData 应用元数据缓存 | `Packages/PluginAppManager/Sources/Services/CacheManager.swift` |
| 视图模型 / 界面 | `Packages/PluginAppManager/Sources/ViewModels/AppManagerViewModel.swift`、`Views/AppManagerDetailView.swift` |
| 磁盘容量 / I/O 监控 | `Packages/PluginDevice/Sources/PluginDevice/Models/StorageModels.swift`、`Views/SystemMonitorView.swift` |
| 相关文件模型 | `Packages/PluginAppManager/Sources/Models/RelatedFile.swift` |
