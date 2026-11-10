# PluginDiskSpeedTest

磁盘测速插件：LLM 调用 `disk_speed_test` 工具后，聊天区会出现一张**测速进度卡片**，
先显示「正在测试硬盘速度…」，测速结束后原地更新为读 / 写速度。

## 它解决什么问题

测速是一个**长耗时操作**（要写入数百 MB 数据、耗时数秒）。
如果等测速结束才把结果显示给用户，中间几秒界面毫无反馈，
用户会以为工具卡死或已经失败。

因此本插件采用「先占位、后回填」的反馈模式：

```
LLM 调用 disk_speed_test
  → 立即插入一条时间线消息，卡片显示「正在测试硬盘速度…」
  → 后台执行真实测速（写 256 MB → fsync → 读 256 MB）
  → 更新同一条消息，卡片显示「读 1.20 GB/s / 写 980 MB/s」
```

## 数据流

```
DiskSpeedTestTool (工具)
  │  1. insert(running payload)
  ▼
DiskSpeedMessageBridge ──insertMessage──▶ MessageManaging
  │  2. update(finished payload)
  │                                        │
  ▼                                        ▼
DiskSpeedTester (真实测速)          DiskSpeedTimeline (renderKind = "disk-speed")
                                             │
                                             ▼
                                  DiskSpeedCardRenderer (order = 200)
                                             │
                                             ▼
                                     DiskSpeedCardView
```

## 三个关键设计决定

### 1. 载荷存在 `content` 而不是 `metadata`

`MessageManaging.updateMessage(id:in:content:)` **只能改 content**，改不了已落库的
`metadata`（见 `DefaultMessageManager.updateMessage` 与持久化实现 `MessageStore.updateMessage`）。

测速卡片必须能从「进行中」推进到「已完成」，所以载荷若放在 metadata，
卡片会永远停在初始状态。因此本插件把载荷 JSON 化后放进 `content`，
`metadata` 只保留时间线标记。

代价是 `content` 不是人话；渲染器优先解析结构化载荷、失败时回退纯文本展示。

### 2. 必须注册为 timeline event

`MessageTimelineEvent.isTimelineEvent` 是一个**封闭集合**。
新类型若不登记，卡片 JSON 会被当作普通对话历史发给模型——既浪费 token，
又让模型看到一串看不懂的内容。

因此在 `ProviderMessage` 中新增了 `diskSpeed` / `diskSpeedRenderKind` / `isDiskSpeed`，
并纳入 `isTimelineEvent`。这条行为由
`DiskSpeedTimelineTests.cardIsExcludedFromLLMContext` 守护。

### 3. 测速文件写在插件自己的数据目录

临时文件写入 `pluginDataDirectory(for: id)/speedtest/`，测完立即删除。
不写用户的任何目录，也不依赖 `dd` / `fio` 等外部命令（避免 PATH 被替换、
避免提权与 shell 转义）。

## 测速方法与精度

- **顺序读写**：写入 256 MB → `fsync` 强制落盘 → 重新打开读取同样字节数。
- **为什么 fsync**：macOS 的写回缓存会让「写完立刻读回」测出的是内存速度。
  `fsync` 后读面对的是物理介质上的数据。
- **已知局限**：`fsync` 之后系统的统一缓存（UBC）仍可能保留部分数据，
  所以读速度依然是**偏乐观的上界**。持续吞吐通常低于此值。
- **不测随机小 IO**：受文件系统、缓存、APFS 压缩多重影响，单次测量噪声大。

## 使用

启用插件后，对 LLM 说「测一下硬盘速度」即可。
LLM 会调用 `disk_speed_test` 工具，聊天区随即出现测速卡片。

工具签名：

```swift
public struct DiskSpeedTestTool: SuperAgentTool {
    public static let toolName = "disk_speed_test"
    // 无参数
}
```

## 目录结构

```
Packages/PluginDiskSpeedTest/
├── Package.swift
├── Resources/
│   └── Localizable.xcstrings
├── Sources/PluginDiskSpeedTest/
│   ├── DiskSpeedTestPlugin.swift          # 插件入口：注册工具 / 渲染器 / 消息桥
│   ├── PluginLocalization.swift
│   ├── Models/
│   │   ├── DiskSpeedPayload.swift         # 载荷模型 + 单位格式化
│   │   └── DiskSpeedTimeline.swift        # 时间线消息构造与编解码
│   ├── Services/
│   │   ├── DiskSpeedMessageBridge.swift   # 插入 / 更新卡片消息
│   │   └── DiskSpeedTester.swift          # 真实顺序读写测速
│   ├── Tools/
│   │   └── DiskSpeedTestTool.swift        # LLM 可调用的工具
│   └── Views/
│       ├── DiskSpeedCardRenderer.swift    # 渲染器注册
│       └── DiskSpeedCardView.swift        # 卡片视图
└── Tests/PluginDiskSpeedTestTests/
    ├── DiskSpeedPayloadTests.swift
    └── DiskSpeedTimelineTests.swift
```

## 相关规范

- [插件包目录结构规范](../../../.lumi/rules/plugin-package-structure.md)
- [插件数据存储规范](../../../.lumi/rules/plugin-storage-rules.md)
- [内核与插件边界规范](../../../.lumi/rules/core-plugin-boundary-rules.md)
- [插件 UI 项 order 规范](../../../.lumi/rules/plugin-ui-item-order.md)
