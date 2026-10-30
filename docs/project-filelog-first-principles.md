# #129 第一性原理分析与修复

## 一句话结论

**`FileLogCoordinator` 用「2 秒一次轮询 logd」来采集「本进程自己的日志」——
这个设计的成本是 logd 持续 100% 占用，而收益（完整日志）根本没拿到。**

根因是三个独立的缺陷叠加，且**互相掩盖**：
拉长轮询间隔能降低 CPU，但会让日志更不完整——于是看起来"修好了"，实际更糟。

## 从第一性原理出发

### 需求

把 Lumi 的日志持久化到磁盘，供用户反馈问题时查阅。

### 约束

1. 日志由 281 个 `os.Logger` 实例、1147 个调用点产生，分布在各插件包；
2. 日志必须进统一日志系统（Console.app / `log stream` 可查）——Apple 平台规范；
3. 落盘不能拖慢日志调用方。

### 现状链路

```
281 个 os.Logger 调用点
   → 写入统一日志系统（logd）              ← 正确
   → ✗ 每 2 秒去 logd 全量翻找              ← 错误的第二跳
   → 磁盘文件
```

**第二跳是多余的**。logd 是为「跨进程、面向人、偶尔查看」设计的，
把它当进程内的高频数据通道，必然得到：固定高延迟、不可控的系统占用、不可靠的完整性。

---

## 三个缺陷（均已实测确认）

### 缺陷 1：每次轮询的 2 秒是 logd XPC 往返的固定延迟

| 读到的条数 | `getEntries` 耗时 |
|------|------|
| **0 条** | **2.960 s** |
| 10 条 | 2.681 s |
| 110 条 | 2.804 s |
| 1110 条 | 2.933 s |

读 0 条与读 1110 条成本相同 → **固定延迟，与数据量无关**。

其它 API 形态：

| 方式 | 耗时 |
|------|------|
| 构造 `OSLogStore` | 0.000 s |
| `position(date:)` | 0.000 s |
| `getEntries(matching:)` | ~2.0 s |
| `getEntries(at:position:)` | ~2.0 s |
| ObjC `entriesEnumeratorAndReturnError:` | 2.263 s |

→ 成本 100% 在 logd 侧，**API 层面无解**。

**由此推出 logd 占用率**（每次阻塞 2s）：

| 轮询间隔 | 每小时 XPC | logd 占用 |
|------|------|------|
| **2s（现状）** | 1800 | **100%** |
| 5s | 720 | 40% |
| 15s | 240 | 13% |

### 缺陷 2：`writeDelay` 导致日志积压与延迟

现状落盘 cutoff = `pollDate - writeDelay`（3s），
而 `OSLogEntry.date` 是**日志产生时刻**，必然早于 `pollDate`。
于是每条日志都要多等 3 秒才能写盘，实测平均延迟 **6.86 秒**。

更糟的是 `lastPolledDate` 也用 `pollDate - writeDelay` 推进，
形成「读窗口也滞后」的叠加效应。

### 缺陷 3：谓词在真实 App 中不可靠（已排除为非问题）

先前观察到「`subsystem` 谓词恒返回 0」，实测发现是**运行方式**导致：

| 运行方式 | `subsystem` 谓词匹配数 |
|------|------|
| `swift` 解释器 | **0** |
| 编译成二进制 + ad-hoc 签名 | **20** ✅ |
| 编译成 .app bundle + 签名 | **20** ✅ |

→ **真实 App（bundle）里谓词正常**，issue 的归因无需修正。

同样地，`position(date:)` 也不影响读取范围（实测三种方式读到的条数完全相同：
10→20→30→40），现状靠 `seenRecordKeys` 去重是**正确**的。

---

## issue 建议的评估

| issue 建议 | 采纳 | 实测结论 |
|-----------|------|---------|
| 复用 OSLogStore 实例 | ❌ | 重建 2.364s vs 复用 2.126s，差异在噪声内 |
| 拉长轮询间隔 | ⚠️ 部分 | 能降 CPU，但会加剧缺陷 2 的积压 |
| 改用 `entriesEnumerator` | ❌ | Swift 侧 `NS_SWIFT_UNAVAILABLE`，且成本相同 |
| 先查最新时间戳再决定是否读 | ❌ | `position()` 免费，但 `getEntries` 才贵，不调用无从判断 |
| Release 下默认关闭 | ✅ | 合理补充 |

**没有任何一条能同时解决 CPU 与完整性问题。**

---

## 已实施的修复（本次提交）

### B. 修正 `writeDelay` 语义 ✅ 已实施

- 读窗口：`lastPolledDate` 推进到**本次实际读到的最后一条日志时间**，
  而非 `pollDate - writeDelay`；
- 写盘 cutoff：改为 `pollDate`（读到的记录其产生时刻必然早于 `pollDate`，无需再等）。

实测：pending 从「持续积压 20 条」变为**恒为 0**。

### C. 拉长轮询间隔 ✅ 已实施

`pollInterval` 2s → **15s**，`writeDelay` 3s → **1s**。

logd 理论占用：`3600/间隔 × 2s/3600` → 从 **100% 降到 13%**。

### E. 限制去重集合容量 ✅ 已实施

`seenRecordKeys` 此前只增不减（每条日志一个字符串），长时间运行会无界增长。
现按 FIFO 淘汰，容量 20000（远大于单次轮询可能读到的条数）。

### 未实施：方案 A（消除 logd 轮询）

根本解是让日志在产生时就落盘，不再轮询 logd。
Lumi 已有 `MagicLogger`（`LumiLoggingKit`）可作为 sink，但：

- `MagicLogger` 目前**零使用**（0 处调用）；
- 实际有 281 个 `os.Logger` 实例、1147 个调用点不走 `MagicLogger`；
- `OSLogHandler` 在当前 SDK（macOS 27.2）**不存在**，无法在 `os.Logger` 层拦截。

改造需要跨全部插件包统一日志入口，属独立的大范围重构，
本次先落地 B/C/E（立即缓解 logd 占用与落盘延迟），A 作为后续项。

## 修复方案（完整版）

### A. 消除 logd 轮询（根本解，后续项）

让日志在**产生的那一刻**就交给落盘器，完全不碰 logd。

Lumi 已有 `MagicLogger`（`LumiLoggingKit`），它在写 `os.Logger` 的同时已持有
完整的 `MagicLogEntry`（level / timestamp / caller / line / message）。

但现状有两个障碍：
- `MagicLogger` **零使用**（0 处调用）；
- 281 个 `os.Logger` 实例不走 `MagicLogger`。

改造路径：给 `os.Logger` 的调用点套一层能同时喂 sink 的封装。
由于 `SuperLog` 已有统一的 `logger` 收敛点，收敛是机械改动。

### B. 修正 `writeDelay` 语义（立即可做）

`writeDelay` 的本意是「避免刚写入的日志还没落稳就去读」，
但实现上把它同时用于「读窗口起点」和「写盘 cutoff」，导致双重滞后。

- 读窗口：`lastPolledDate` 应推进到**本次实际读到的最后一条日志时间**，
  而非 `pollDate - writeDelay`；
- 写盘 cutoff：应为 `pollDate`（本次读到的都已是历史日志，无需再等）。

### C. 拉长轮询间隔（配合 A/B）

在 A 落地前，B + 拉长间隔是过渡方案。
但必须注意：**间隔拉长 + writeDelay 修正** 才能同时保住 CPU 和完整性。

### D. Release 下默认可关

`policy: .required` → `.enabledByDefault`。

---

## 实测验证方法

复刻 `FileLogCoordinator` 的完整落盘逻辑，观察「新增 / 写盘 / pending」：

```
现状 (writeDelay=3s):  轮1 写盘=0  轮2 写盘=30  轮3 写盘=20  轮4 写盘=20
writeDelay=0:          轮1 写盘=90 轮2 写盘=20  轮3 写盘=20  轮4 写盘=20
```

`writeDelay=0` 时无积压、立即落盘。
