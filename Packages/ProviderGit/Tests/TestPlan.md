# TestPlan — ProviderGit

## 包概述

ProviderGit 是编辑器侧的 Git **只读访问契约与数据模型**包。Provider 包只声明契约、
不含实现，也不依赖任何插件包——需要 Git 数据的插件依赖本包，而不是反向依赖
`PluginGit`。真实实现由 `PluginGit` 在 `onBoot` 通过
`registerProvider((any GitRepositoryReading).self, ...)` 发布。

核心组件:
- `GitRepositoryReading` - 只读契约（`status(atPath:)`、`log(atPath:count:branch:file:)`、
  `log(atPath:count:skip:)`、`recentCommits(atPath:count:)` 便捷重载）
- `InMemoryGitRepositoryReading` - 内存替身，供测试 / 预览 / 无真实 Git 时装配
- `GitStatus` - 仓库状态模型（分支、远程、五类变更文件）
- `GitCommitLog` - 单条提交记录
- `GitDateFormatting` - ISO-8601 及回退格式的日期解析
- `GitReadError` - 契约层读取错误（`repositoryNotFound` / `notAGitRepository`）

## 公开 API

### GitRepositoryReading（协议）
- `status(atPath path: String?) async throws -> GitStatus`
- `log(atPath:count:branch:file:) async throws -> [GitCommitLog]`
- `log(atPath:count:skip:) async throws -> [GitCommitLog]` - 分页读取
- `recentCommits(atPath:count:) async throws -> [GitCommitLog]` - 默认实现的便捷重载

### GitStatus
- `branch: String` / `remote: String?`
- `modified` / `added` / `deleted` / `renamed` / `staged`：`[String]`，默认空数组
- `allChangedFiles: [String]` - 五类变更**去重并按字典序排序**

### GitCommitLog
- `hash` / `author` / `email` / `message: String`，`date: String`（保留 ISO-8601 原串）

### GitDateFormatting
- `formatHandlers: [DateFormatter]` - 依次尝试的回退格式
- `date(from value: String) -> Date?` - 先试 `ISO8601DateFormatter`，再依次试回退格式

### InMemoryGitRepositoryReading
- `init(statuses:commits:)`
- `setStatus(_:forPath:)` / `setCommits(_:forPath:)`
- 实现全部契约方法；状态由串行队列保护

### GitReadError
- `repositoryNotFound(path: String?)` / `notAGitRepository(path: String)`，
  实现 `LocalizedError` + `Equatable`

## 关键行为契约（实现约定，非协议要求）

- **`allChangedFiles` 必须去重并排序**：同一文件可能同时出现在 `modified` 与 `staged`
  （暂存了部分改动后继续修改是 Git 的常态）。直接 `+` 拼接会让 UI 上同一文件出现两次，
  且顺序随 Git 输出漂移——排序保证渲染稳定、便于 diff 比对。
- **`date` 在契约层保持字符串**：`GitCommitLog.date` 保留 libgit2 产出的 ISO-8601 原串，
  契约层**不引入日期解析依赖**；需要 `Date` 的消费者自行调用 `GitDateFormatting.date(from:)`。
- **日期解析先 ISO 后回退**：不同 Git 后端与平台产出的格式不一致，
  `GitDateFormatting` 先试 `ISO8601DateFormatter`，失败再依次试
  `formatHandlers` 中的 5 种格式；全部失败返回 `nil` 而非抛错（调用方多为纯展示）。
- **`formatHandlers` 固定 `en_US_POSIX` 与 GMT**：日期格式串中的 `MMM` 等符号在非
  POSIX locale 下会被本地化，导致解析失败。锁定 locale 与时区是这条用例的真正目的。
- **`nil` 路径必须报错而非回落 cwd**：契约文档写明 `nil` 表示"使用进程当前目录"，
  但**内存实现明确抛 `repositoryNotFound(path: nil)`**。这是刻意的——
  契约层允许两种解读，内存实现选择严格解读，避免测试进程意外读到宿主工程的真实 Git 状态。
- **分页越界返回空数组**：`skip >= count` 时返回 `[]`，不抛错、不崩溃——
  UI 逐页加载到末尾属正常路径。
- **`log(branch:file:)` 重载委托给分页版本**：内存实现忽略 `branch` / `file` 过滤
  （内存数据无此维度），但必须走同一份数据源，不能自行返回另一份数据。
- **内存状态用串行队列而非 `NSLock`**：契约方法是 `async`，Swift 6 禁止用
  `NSLock` 跨 `await` 加锁，故用 `DispatchQueue.sync` + `@unchecked Sendable` 存储盒。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 模型 | `allChangedFiles` 汇总五类变更并去重排序 | `a.swift` 同时在 modified 与 staged | 读 `allChangedFiles` | 返回 `["a.swift","b.swift","c.swift"]`，`a.swift` 只出现一次且按字典序 | P0 | ✅ 已覆盖 | `statusCollectsAllChangedFiles` |
| 2 | 模型 | `GitStatus` / `GitCommitLog` 经 Codable 往返一致 | 构造含各字段的实例 | JSON 编码后解码 | 与原实例 `Equatable` 相等（含 `remote: nil`） | P0 | ✅ 已覆盖 | `modelsRoundTripThroughCodable` |
| 3 | 日期 | 解析 ISO-8601 提交时间 | 字符串 `"2026-09-16T05:26:39Z"` | 调 `GitDateFormatting.date(from:)` | 得到 2026-09-16（GMT 下校验年月日） | P0 | ✅ 已覆盖 | `parsesISO8601CommitDates` |
| 4 | 日期 | 解析回退格式且拒绝非法输入 | `"2026-09-16 05:26:39 +0000"`、`"...39"`、`"not a date"` | 逐个解析 | 前两个非 nil；非法串返回 `nil` 而非抛错 | P1 | ✅ 已覆盖 | `parsesFallbackDateFormats` |
| 5 | 内存实现 | 内存实现可服务 `status` 与分页 `log` | 预置 5 条 commit + 1 个 status | 读 status；`skip:2,count:2`；`skip:99`；`recentCommits` | branch 正确；分页返回 `h3,h4`；越界返回空；便捷重载返回全部 5 条 | P0 | ✅ 已覆盖 | `inMemoryImplementationServesStatusAndLog` |
| 6 | 内存实现 | 未知仓库与 `nil` 路径都抛 `repositoryNotFound` | 空内存实现 | 读 `/missing` 与 `nil` | 两者都抛 `GitReadError`，不返回空状态、不回落 cwd | P0 | ✅ 已覆盖 | `inMemoryImplementationReportsUnknownRepository` |

> 说明：全部 **6 条场景**已在 macOS 上实跑通过（`swift test` → 6 tests in 1 suite passed）。
>
> 本包是纯契约包，用例少而边界密，三处易错约定已在用例里显式锁定：
> - **`allChangedFiles` 的去重是业务必需而非洁癖**（ID 1）：`a.swift` 同时出现在
>   `modified` 与 `staged` 是 Git 的常态（暂存了部分改动后继续编辑）。直接拼接会让
>   同一文件在变更列表里出现两次；排序则保证多次读取顺序一致，便于 diff 比对与快照测试。
> - **契约层刻意不解析日期**（ID 3/4）：`GitCommitLog.date` 保持 libgit2 的原始
>   ISO-8601 字符串，`GitDateFormatting` 作为可选工具独立提供。放进契约会让
>   Provider 包平白依赖 Foundation 日期栈，并强迫所有实现方统一格式。
> - **`nil` 路径的严格解读是刻意的**（ID 6）：契约文档写 `nil` 表示"使用进程当前目录"，
>   但内存实现选择抛错而非回落——否则测试进程会读到宿主工程的真实 Git 状态，
>   测试结果随开发者的 shell 目录漂移。
> - **分页越界是正常路径而非异常**（ID 5）：`skip` 超出总量返回 `[]`，UI 逐页加载
>   到末尾依赖这个行为；若改成抛错，列表翻页会在最后一页报错。
> - **`NSLock` 不能跨 `await`**：Swift 6 禁止，因此内存实现用 `DispatchQueue.sync`
>   保护可变存储（Swift 6 迁移期容易被误改成 `NSLock` 并触发编译错误或数据竞争）。

## 覆盖率统计

- P0: 已覆盖 5 / 5
- P1: 已覆盖 1 / 1
- **合计: 6 / 6**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 模型语义（去重排序、Codable 往返）、ISO-8601 解析、内存实现的分页与错误路径
- **P1**: 回退日期格式与非法输入处理

> 本包未列 P2：作为纯契约 + 数据模型包，没有可降级的边缘行为；
> `GitReadError.errorDescription` 的文案属于展示细节，随文案调整即可。

## 跨平台说明

- Package 声明 macOS 14+ / iOS 17+，全部用例为**跨平台**——仅依赖 Foundation 的
  `Codable` / `DateFormatter` / `ISO8601DateFormatter` 与 `DispatchQueue`，无平台专属 API
- `GitRepositoryReading` 协议为 `Sendable`，消费者可跨 actor 边界共享；
  内存实现以 `@unchecked Sendable` 标注，靠串行队列保证实际安全

## 测试执行

```bash
cd Packages/ProviderGit
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **契约变更需同步 `PluginGit`** → 本包只声明契约，真实实现在 `PluginGit`；
   增删契约方法时必须确认实现方已跟上，否则运行期才暴露缺失
3. **`allChangedFiles` 的去重 + 排序不可省略** → 若有人改为直接拼接，
   须同时说明如何避免同一文件在变更列表中重复出现
4. **日期格式扩充** → 往 `GitDateFormatting.formatHandlers` 追加格式即可，
   不要在契约层引入解析逻辑；追加后补一条对应用例（ID 4）
5. **内存实现的行为分歧须有意识地维持** → 例如 `nil` 路径抛错、`branch`/`file` 不过滤；
   这些是刻意的简化，不是待补的缺口，改动前先确认不会破坏下游测试
