# #129 研究记录：FileLogCoordinator 的 OSLogStore 轮询

## 结论摘要

issue #129 描述的「2 秒轮询把 OSLogService 拖到 60-80% CPU」**属实**，但归因和修复方向**都不准确**：

1. 成本不在「每次重建 `OSLogStore` 实例」——实测重建与复用**无差异**（issue 的方向 2 无效）；
2. 成本不在「日志量大导致 logd 谓词匹配慢」——实测耗时**与日志量完全无关**，恒定 ~2.0s；
3. 成本是 **logd 每次 XPC 往返的固有延迟**——只��"把轮询间隔拉长"能线性降低占用；
4. **更严重的隐藏问题**：`subsystem` / `category` 谓词在本机**永远返回 0 条**，
   导致 `FileLogCoordinator` 实际读不到自己的日志（磁盘日志每个文件只有 23 行）。

## 实测数据

### 1. 固定 ~2s 成本，与日志量无关

| 轮次 | 新增日志数 | `getEntries` 耗时 | 读到条数 |
|------|------|------|------|
| 1 | 100 | 2.250 s | 101 |
| 2 | 200 | 2.267 s | 303 |
| 3 | 300 | 2.423 s | 605 |

连续读 5 次（间隔 0.2s）同样稳定在 1.97~2.11s —— 是**每次 XPC 往返的固有成本**，
不是「等待新日志」。

### 2. 重建 vs 复用 `OSLogStore` 无差异

| 方式 | 耗时 |
|------|------|
| 每次重建 store + 读 | 2.364 s |
| 复用 store + 读（第一次） | 2.427 s |
| 复用 store + 读（第二次） | 2.126 s |
| 重建 store + 读 | 2.321 s |

差异在噪声内 → **issue 的「方向 2：复用 OSLogStore 实例」无效**。

`OSLogStore` 构造本身耗时 0.000s，**成本 100% 在 `getEntries` 的 XPC 调用里**。

### 3. `position(date:)` 几乎免费

耗时 0.000s —— 定位日志起点不是瓶颈。

### 4. 谓词失效：本机读不到自己的日志

| 谓词 | 读到条数 |
|------|------|
| `NSPredicate(value: true)` | **107** |
| `subsystem == "com.coffic.lumi"` | **0** |
| `category == "bench"` | **0** |
| `subsystem BEGINSWITH "com.coffic"` | **0** |
| `eventMessage CONTAINS "..."` | **0** |
| `eventType == "logEvent"` | 43 |

用 `TRUE` 读到的条目里，本进程日志的 `subsystem` / `category` **都是空字符串**，
`composedMessage` 是 `<compose failure [missing precomposed log]>`。

而 `log stream --predicate 'subsystem == "com.coffic.lumi"'` 能**完整抓到**本进程日志
（50/50 条）→ 日志确实进了统一日志系统，**是 `OSLogStore` 读不出来**。

**后果**：磁盘日志每个文件只有 23 行（本该有数百行），
`FileLogCoordinator` 的核心功能实质上是失效的。

> 注：这可能是 macOS 27.2 + 未签名 Debug 构建的组合问题，需要在其它环境复核。
> 但无论 predicate 是否可用，**~2s 的 XPC 成本都真实存在**，都必须解决。

### 5. 轮询间隔对 logd 占用的影响

每次 XPC 阻塞 ~2.0s，占用率 = `3600 / 间隔 × 2.0 / 3600`：

| 轮询间隔 | 每小时 XPC 次数 | logd 理论占用 |
|------|------|------|
| 2s（现状） | 1800 | **100%** |
| 5s | 720 | 40% |
| 15s | 240 | 13% |
| 30s | 120 | 7% |

现状的 2s 间隔意味着 **logd 被要求持续 100% 忙**——与 issue 观察到的 60-80% CPU 吻合。

### 6. issue 的方向 3 在 Swift 中不可行

issue 建议「改用 `OSLogStore.entriesEnumerator` 增量读」，但：

```swift
// OSLog.framework/Headers/Store.h:159
- (nullable OSLogEnumerator *)entriesEnumeratorAndReturnError:(NSError **)error
    NS_SWIFT_UNAVAILABLE("Use `entries` method");
```

`entriesEnumerator` 在 Swift 中被标记为 **unavailable**，
且 `OSLogStore` 在 Swift 侧**没有** `entries` 方法（只有 `getEntries`）。
即 Swift 侧**没有增量读 API**，只能用 `getEntries(at:position:)`。

## 修复方案

### A. 拉长轮询间隔（缓解 logd 压力）

`pollInterval` 从 2s 改为 15s（`FileLogCoordinator` 已有该参数）。
logd 占用从 100% 降到 ~13%。

同时 `writeDelay`（3s）与 `pollInterval`（2s）存在语义重叠，
应合并为单一「日志落盘延迟」参数。

### B. 只在有新日志时才真正读

先读 `position(date: lastPolledDate)`，若位置未变则跳过 `getEntries`。
但实测 `position()` 免费而 `getEntries` 贵——问题是 `getEntries` 本身才昂贵，
所以这条**不能省**（不调用就没有「有无新日志」信息）。

→ 唯一有效的优化就是**降低调用频率**。

### C. 修正 predicate（若在其它环境生效）

`subsystem` 谓词若可用，应作为主过滤；
本机不可用时降级为「读全量 + 内存过滤」。

### D. Release 构建下默认关闭

`PluginFileLog` 的 `policy` 目前是 `.required`（不可禁用）。
磁盘日志在 Release 下价值有限（用户可看 Console.app），
建议改为 `.enabledByDefault` 让用户可关。

## 未决问题

- `subsystem` 谓词失效是否为 macOS 27.2 特有？需在其它 macOS 版本复核。
- ~~`getEntries` 的 2s 是否可通过 ObjC 的 `entriesEnumeratorAndReturnError:` 绕过？~~
  → **已验证：不能**。用 ObjC runtime 直接调用该方法（Swift 侧虽标记
  `NS_SWIFT_UNAVAILABLE`，但 runtime 可调）：

  | 方式 | 耗时 | 条数 |
  |------|------|------|
  | Swift `getEntries(matching: TRUE)` | 2.234 s | 101 |
  | ObjC `entriesEnumeratorAndReturnError:` | 2.263 s | 103 |

  两者成本相同 → **2s 是 logd 侧 XPC 往返的固有延迟，Swift API 层面无解**。

