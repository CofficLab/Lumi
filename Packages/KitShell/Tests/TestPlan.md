# TestPlan — KitShell

## 包概述

KitShell 是可复用的异步 Shell 命令执行工具包，封装 Foundation `Process`，
提供 async/await API、流式输出回调、超时与取消、进程树终止与结构化结果。

核心组件:
- `ShellExecutor` - 执行入口（`execute` / `executeStreaming` / `findCommand` / `findCommandSync`）
- `ShellResult` - 结构化结果（`exitCode` / `stdout` / `stderr` / 截断标记 / `duration`）
- `ShellOptions` - 执行选项（shell 可执行文件、工作目录、环境变量、超时、QoS、
  `throwsOnError`、进程树终止、宽限期、输出上限、排空超时）
- `ShellError` - 错误类型（`commandFailed` / `timeout` / `launchFailed` / `cancelled` /
  `decodingError`，均实现 `LocalizedError`）
- `ProcessPipeCleanup` - 管道 fd 显式回收
- `KitShellLocalization` - 本地化字符串

## 公开 API

### ShellExecutor
- `execute(_ command: String, options:) async throws -> ShellResult` - 命令串执行（走 shell）
- `execute(executable:arguments:options:) async throws -> ShellResult` - 显式可执行文件执行
- `executeStreaming(...)` - 两个重载，流式回调
- `findCommand(_:) async -> String?` / `findCommandSync(_:) -> String?` - 在 PATH 中查找命令

### ShellResult
- `exitCode: Int32` / `stdout: String` / `stderr: String`
- `stdoutTruncated` / `stderrTruncated: Bool` - 截断标记
- `isSuccess: Bool` - 由 `exitCode` 派生
- `duration: TimeInterval?`

### ShellOptions
- `shellExecutable` / `workingDirectory` / `environment` / `timeout` / `qos`
- `throwsOnError` / `terminatesProcessTree` / `terminationGracePeriod`
- `maxOutputBytes` / `outputDrainTimeout`
- `static let defaultOptions`

### ShellError
- `commandFailed(exitCode:stdout:stderr:)` / `timeout(command:seconds:)` /
  `launchFailed(command:reason:)` / `cancelled(command:)` / `decodingError(command:)`

## 关键行为契约（实现约定，非协议要求）

- **超时不受 `throwsOnError` 影响**：`throwsOnError == false` 只放宽**非零退出码**，
  超时依然抛 `.timeout`。把超时也吞掉会让调用方拿到一个"卡住但成功"的假象。
- **输出上限只约束聚合结果**：`maxOutputBytes` 限制 `ShellResult.stdout/stderr` 的
  最终长度并置位 `*Truncated`，但**实时流式回调仍收到完整增量**——回调是给进度
  UI 看的，聚合才是给落库/展示看的，两者语义不同。
- **截断保留尾部**：输出超限时丢弃最旧字节（`overflowDropsOldestBytes`），
  因为诊断价值集中在命令的末尾输出。
- **恰好填满不算截断**：`exactFitIsNotTruncated` 锁定 `>=` 与 `>` 的边界差异。
- **管道 fd 必须显式关闭**：`Pipe` 占 2 个 fd（读端 + 写端），释放依赖
  autorelease pool 排空或对象析构。chat/agent 主线程在长回合内不排空 pool，
  `Process` + `Pipe` 同步反复创建会让 fd 持续堆积，最终耗尽进程上限，
  表现为 `URLSession` 无法新建 socket 报 `Too many open files` (EMFILE)，
  也就是"聊得越久越容易报网络错误"。**修复方式是每个管道用完立即
  `Pipe.closeFileDescriptors()`，而不是等 ARC/autorelease。**
- **测量必须发生在 autoreleasepool 内部**：pool 一旦排空，未关闭的管道 fd 也会被
  回收，就测不到累积。因此用例把"执行 N 次"与"测量"放在同一个显式 pool 内，
  且该套件标记 `.serialized` 避免并发干扰。
- **进程树终止**：超时与取消都需要终止**子孙进程**（`testCancellationTerminatesGrandchildProcess`），
  只杀直接子进程会留下持有管道的孤儿进程。
- **子进程继承管道时靠排空超时兜底**：`testPipeDrainHasTimeout` 锁定
  `outputDrainTimeout`——子进程 fork 出的孙进程若继承了 stdout 写端，
  父进程退出后管道仍不 EOF，`readDataToEndOfFile` 会永久阻塞。
- **findCommand 不得创建 shell**：`findCommandSync` 直接扫 PATH，
  避免为一次存在性判断付出进程创建代价。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 执行 | 简单命令返回正确输出 | — | 执行 `echo` 类命令 | stdout 正确、exitCode 为 0 | P0 | ✅ 已覆盖 | `testSimpleCommand` |
| 2 | 执行 | 管道命令生效 | — | 执行含 `\|` 的命令串 | 管道两侧输出均正确 | P1 | ✅ 已覆盖 | `testPipedCommand` |
| 3 | 执行 | 多级管道生效 | — | 执行含两个 `\|` 的命令串 | 三段输出均正确 | P1 | ✅ 已覆盖 | `testMultiplePipes` |
| 4 | 执行 | 显式可执行文件绕过 shell | — | 用 `executable:arguments:` 执行 | 不经 shell 解析，参数原样传递 | P1 | ✅ 已覆盖 | `testExplicitExecutable` |
| 5 | 执行 | 命令串可指定 shell 为 zsh | `shellExecutable = /bin/zsh` | 执行含 zsh 特有语法的命令 | 语法被正确解释 | P1 | ✅ 已覆盖 | `testShellExecutableOptionUsesZsh` |
| 6 | 执行 | 在指定工作目录执行 | `workingDirectory` 指向临时目录 | 执行 `pwd` | 返回该目录 | P0 | ✅ 已覆盖 | `testWorkingDirectory` |
| 7 | 执行 | 工作目录影响相对路径解析 | `workingDirectory` 指向临时目录 | 写文件后按相对名读取 | 相对路径基于工作目录解析 | P0 | ✅ 已覆盖 | `testWorkingDirectoryRelativePath` |
| 8 | 环境 | 自定义环境变量可读 | `environment` 含自定义键 | 执行 `env`/`echo $KEY` | 变量可见 | P1 | ✅ 已覆盖 | `testCustomEnvironment` |
| 9 | 环境 | 覆盖环境不丢失系统 PATH | `environment` 只给自定义键 | 执行依赖 PATH 的命令 | 仍能按系统 PATH 找到可执行文件 | P0 | ✅ 已覆盖 | `testEnvironmentPreservesPath` |
| 10 | 错误 | 非零退出码抛 `commandFailed` | 默认 `throwsOnError = true` | 执行 `false` 类命令 | 抛 `.commandFailed`，携带 exitCode/stdout/stderr | P0 | ✅ 已覆盖 | `testCommandFailureThrows` |
| 11 | 错误 | `throwsOnError = false` 时返回结果而非抛错 | `throwsOnError = false` | 同上 | 返回 `ShellResult`，`isSuccess == false` | P0 | ✅ 已覆盖 | `testCommandFailureNoThrow` |
| 12 | 错误 | 非法可执行文件抛 `launchFailed` | 传入不存在的路径 | 执行 | 抛 `.launchFailed` 而非崩溃 | P0 | ✅ 已覆盖 | `testInvalidExecutable` |
| 13 | 超时 | 超时终止长时间命令并抛 `.timeout` | `timeout` 极短 | 执行 `sleep` 类命令 | 抛 `.timeout`，命令被终止 | P0 | ✅ 已覆盖 | `testTimeout` |
| 14 | 超时 | 超时不受 `throwsOnError = false` 影响 | 两者同时设置 | 执行长命令 | **仍抛 `.timeout`** | P0 | ✅ 已覆盖 | `testTimeoutIgnoresThrowsOnErrorFalse` |
| 15 | 超时 | 超时终止子进程 | 父命令派生子进程 | 超时 | 子进程一并被终止，不留孤儿 | P0 | ✅ 已覆盖 | `testTimeoutTerminatesChildProcess` |
| 16 | 超时 | 快速命令在超时前完成 | `timeout` 宽松 | 执行短命令 | 正常返回，不误触发超时 | P1 | ✅ 已覆盖 | `testQuickCommandBeforeTimeout` |
| 17 | 流式 | 流式回调增量捕获输出 | 回调记录增量 | 执行多行输出命令 | 多次回调且内容递增拼接完整 | P0 | ✅ 已覆盖 | `testStreamingOutput` |
| 18 | 流式 | 流式回调暴露原始 Data | 回调记录 Data | 执行二进制/长输出命令 | 可拿到原始字节 | P1 | ✅ 已覆盖 | `testStreamingOutputData` |
| 19 | 流式 | 流式回调捕获 stderr | 回调分别记录两路 | 执行写 stderr 的命令 | stderr 增量被捕获 | P1 | ✅ 已覆盖 | `testStreamingStderr` |
| 20 | 输出上限 | 聚合输出超上限时截断并标记 | `maxOutputBytes` 很小 | 执行大输出命令 | `stdoutTruncated == true`，长度受限 | P0 | ✅ 已覆盖 | `testOutputIsBounded` |
| 21 | 输出上限 | 上限只限制聚合，不限制实时回调 | 同上但收集回调 | 执行大输出命令 | 回调仍收到**完整**内容 | P0 | ✅ 已覆盖 | `testStreamingCallbackReceivesFullOutputWhenAggregateIsBounded` |
| 22 | 输出上限 | 空追加是无操作 | 空 chunk | 反复 `append(data:)` 空数据 | 缓冲区不变 | P2 | ✅ 已覆盖 | `emptyAppendNoOp` |
| 23 | 输出上限 | 未超上限时逐字保留 | 多 chunk 累计未达上限 | 追加 | 内容与输入完全一致 | P1 | ✅ 已覆盖 | `retainsUpToCap` |
| 24 | 输出上限 | 单 chunk 超限时只保留其尾部并标记 | 单 chunk 远超上限 | 追加 | 保留尾部，`*Truncated == true` | P1 | ✅ 已覆盖 | `overflowTruncates` |
| 25 | 输出上限 | 恰好填满上限不算截断 | 累计长度精确等于上限 | 追加 | `*Truncated == false`（边界） | P0 | ✅ 已覆盖 | `exactFitIsNotTruncated` |
| 26 | 输出上限 | 溢出丢弃最旧字节以保留最新 | 持续追加超上限 | 追加多次 | 内容为最新的若干字节 | P0 | ✅ 已覆盖 | `overflowDropsOldestBytes` |
| 27 | 输出上限 | `maxBytes` 为 0 时立即截断 | 上限为 0 | 追加 | 结果为空且标记截断 | P2 | ✅ 已覆盖 | `zeroCapTruncates` |
| 28 | 排空 | 子进程继承管道时排空超时后返回 | 子进程 fork 出继承写端的孙进程 | 执行 | `outputDrainTimeout` 后返回而非永久阻塞 | P0 | ✅ 已覆盖 | `testPipeDrainHasTimeout` |
| 29 | 取消 | 取消终止子进程 | 执行长命令 | 触发取消 | 子进程被终止 | P0 | ✅ 已覆盖 | `testCancellationTerminatesChildProcess` |
| 30 | 取消 | 取消终止孙进程 | 命令派生两级子进程 | 触发取消 | **孙进程一并终止**，无孤儿占管道 | P0 | ✅ 已覆盖 | `testCancellationTerminatesGrandchildProcess` |
| 31 | 取消 | 进程启动前取消也能结束等待 | 取消先于 `Process.run()` | 取消后等待 | 不挂起，正常返回 | P1 | ✅ 已覆盖 | `testCancellationBeforeProcessStarts` |
| 32 | 查找 | `findCommand` 返回已存在命令的路径 | — | 查找 `git` | 返回非 nil 路径 | P1 | ✅ 已覆盖 | `testFindCommand` |
| 33 | 查找 | `findCommand` 对不存在命令返回 nil | — | 查找随机名 | 返回 nil | P1 | ✅ 已覆盖 | `testFindNonexistentCommand` |
| 34 | 查找 | `findCommandSync` 结果与 async 版一致 | — | 同步查找 | 路径正确 | P1 | ✅ 已覆盖 | `testFindCommandSync` |
| 35 | 结果 | `isSuccess` 随 `exitCode` 正确派生 | 构造两种 `exitCode` | 读属性 | 0 → true、非 0 → false | P1 | ✅ 已覆盖 | `testResultIsSuccess` |
| 36 | 结果 | `duration` 被记录 | 执行一次 | 读属性 | 非 nil 且为合理时长 | P2 | ✅ 已覆盖 | `testResultDuration` |
| 37 | 选项 | `defaultOptions` 默认值 | — | 读静态属性 | 各字段为文档默认值 | P1 | ✅ 已覆盖 | `testDefaultOptions` |
| 38 | 选项 | 自定义选项初始化生效 | 自定义各字段 | 构造 | 字段逐一保留 | P1 | ✅ 已覆盖 | `testCustomOptions` |
| 39 | 选项 | shell 别名生效 | `shellExecutable` 指向别处 | 执行 shell 语法 | 仍按命令串语义执行 | P2 | ✅ 已覆盖 | `testShellAlias` |
| 40 | 错误描述 | `commandFailed` 描述含退出码 | — | 读 `errorDescription` | 包含 exitCode | P2 | ✅ 已覆盖 | `testCommandFailedDescription` |
| 41 | 错误描述 | `timeout` 描述含命令与时长 | — | 读 `errorDescription` | 含 command 与 seconds | P2 | ✅ 已覆盖 | `testTimeoutDescription` |
| 42 | 错误描述 | `launchFailed` 描述含原因 | — | 读 `errorDescription` | 含 reason | P2 | ✅ 已覆盖 | `testLaunchFailedDescription` |
| 43 | 错误描述 | `cancelled` 描述含命令 | — | 读 `errorDescription` | 含 command | P2 | ✅ 已覆盖 | `testCancelledDescription` |
| 44 | 错误描述 | `decodingError` 描述含命令 | — | 读 `errorDescription` | 含 command | P2 | ✅ 已覆盖 | `testDecodingErrorDescription` |
| 45 | FD 泄漏 | 显式关闭管道后 pool 内反复创建不累积 fd | `closePipes = true` | 同一 `autoreleasepool` 内跑 N 次并测 fd | fd 数不随 N 增长 | P0 | ✅ 已覆盖 | `explicitCloseDoesNotAccumulateFileDescriptors` |
| 46 | FD 泄漏 | 不关闭管道时 fd 在 pool 内累积（根因对照组） | `closePipes = false` | 同上 | fd 随 N 线性增长，**复现泄漏** | P0 | ✅ 已覆盖 | `unclosedPipesAccumulateInsidePool` |
| 47 | FD 泄漏 | `ShellExecutor` 反复执行后 fd 不增长（端到端） | — | 连续执行 N 次并测 fd | fd 基本持平 | P0 | ✅ 已覆盖 | `shellExecutorRepeatedExecutionDoesNotLeak` |
| 48 | FD 影响 | fd 耗尽时工具调用以 EMFILE 失败 | 预先占满 fd | 发起子进程调用 | 报 `Too many open files` | P0 | ✅ 已覆盖 | `subprocessExhaustionBreaksToolCalls` |
| 49 | FD 影响 | fd 充足时同一调用正常（对照组） | 不占满 | 同上 | 正常返回 | P0 | ✅ 已覆盖 | `normalConditionsWork` |
| 50 | FD 影响 | 当前进程 fd 水位可观测 | — | 读 `openCount()` | 返回 ≥ 0 的整数 | P1 | ✅ 已覆盖 | `fileDescriptorWatermarkIsObservable` |

> 说明：全部 **50 条场景**（1 个 suite + 49 个自由函数用例）已在 macOS 上实跑通过。
>
> 本套件的价值集中在**故障复现而非功能断言**，三条易错约定已在用例里显式锁定：
> - **管道 fd 泄漏的真实形态是「同 pool 内同步反复创建」**（ID 46）：不显式关闭时，
>   `Pipe` 的 2 个 fd 依赖 autorelease pool 排空才释放，而 chat/agent 主线程在长回合内
>   不排空。用例刻意把「执行 N 次」与「测量」放进同一个显式 `autoreleasepool`，
>   否则 pool 一排空 fd 就被回收，测出来的永远是"不泄漏"。
> - **EMFILE 的表象是网络错误**（ID 48）：进程 fd 耗尽后 `URLSession` 无法新建
>   socket，于是用户看到的是"聊得越久越容易报网络错误"，与 Shell 毫无关系。
>   根因排查必须从 fd 水位入手，ID 50 就是为此提供观测手段。
> - **`maxOutputBytes` 与流式回调语义不同**（ID 20/21）：上限只约束聚合结果，
>   实时回调必须完整。若把截断逻辑下沉到回调，进度 UI 会显示残缺输出。
> - **超时必须抛错**（ID 14）：`throwsOnError = false` 只放宽非零退出码。
>   一并放宽超时会返回"卡住但成功"的假象，调用方无从判断命令是否真的跑完。
> - **进程树终止而非单进程终止**（ID 15/30）：只杀直接子进程会留下持有管道写端的
>   孤儿进程，`readDataToEndOfFile` 永远等不到 EOF——这正是 `outputDrainTimeout`
>   存在的理由（ID 28）。

## 覆盖率统计

- P0: 已覆盖 23 / 23
- P1: 已覆盖 18 / 18
- P2: 已覆盖 9 / 9
- **合计: 50 / 50**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 输出与退出码正确性、环境 PATH 保留、异常与非法可执行、超时语义（含
  `throwsOnError` 交互）、进程树终止、输出上限与截断边界、fd 泄漏根因与端到端验证
- **P1**: 管道/多级管道、shell 选择、工作目录与相对路径、自定义环境、流式回调、
  取消时序、`findCommand`
- **P2**: 空追加边界、`duration` 记录、shell 别名、五个错误描述的文案

## 跨平台说明

- Package 声明 macOS 14+（`Package.swift` 未声明 iOS），**全部用例为 macOS 专属**：
  `ProcessPipeCleanup` / `PipeFDProbe` 直接调用 Darwin 的 `proc_pidinfo(PROC_PIDLISTFDS)`，
  iOS 上不可用
- `ShellExecutor` / `ShellResult` / `ShellOptions` / `ShellError` 为纯 Foundation 逻辑，
  跨平台行为一致
- fd 泄漏相关用例标记 `.serialized`：它们测量的是**进程级** fd 水位，
  与同进程内其他测试并发会互相污染水位，因此必须串行执行

## 测试执行

```bash
cd Packages/KitShell
swift test
```

单独跑 fd 泄漏套件（验证耗时长，建议带超时）：

```bash
swift test --filter "Process Pipe FD Leak"
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件（ID 46 即「聊久了报网络错误」的回归）
3. **删除用例** → 在 commit message 说明理由；**故障复现类用例（ID 46/48）不得删除**，
   它们是防止修复被无意"简化"掉的唯一屏障
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **fd 类用例保持 `.serialized`** → 新增 fd 测量用例时必须进
   `ProcessPipeLeakTests` / `FDExhaustionImpactTests` 这两个串行 suite，
   否则水位互相干扰，测试结果不可信
6. **测量位置约定** → 任何 fd 相关断言都必须在**显式 `autoreleasepool` 内部**完成
   「执行 + 测量」两步，pool 外测量恒为"不泄漏"
