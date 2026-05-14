# EditorRemotePreviewPlugin 性能改进路线图

## 1. 概述 (Overview)

### 1.1 现状

Lumi 的 `EditorRemotePreviewPlugin` 已经实现了一个**完整可用的 SwiftUI 预览系统**：

- 扫描 `#Preview` 宏 → 规划编译策略 → 编译 → 启动宿主进程 → 加载 dylib → 渲染
- 支持 Image（静态截图）和 Live（交互式窗口）两种模式
- 支持热重载（文件变化后自动重新编译和渲染）

但与 Xcode Preview 相比，用户体验存在明显差距：

| 维度 | Xcode Preview | Lumi 现状 |
|------|--------------|----------|
| 首次预览 | 2-5 秒 | 5-20 秒（取决于项目大小） |
| 热重载 | < 1 秒 | 3-10 秒 |
| 交互方式 | 画布内直接交互，默认即 Live | 默认静态截图，需手动切 Live |
| 稳定性 | 高（私有框架深度集成） | 中（Live 模式偶发降级） |

### 1.2 问题根因

当前方案的**性能瓶颈链路**：

```
用户改代码
    │
    ▼ ① 扫描 #Preview                                ~ms 级  ✅ 快
    │
    ▼ ② 规划编译策略                                   ~ms 级  ✅ 快
    │
    ▼ ③ 完整编译 target                  ⚠️ 瓶颈 1     秒~十秒级
    │   swift build / xcodebuild（全量编译）
    │
    ▼ ④ 收集源文件 + 源码清理 + 编译 Entry dylib   ⚠️ 瓶颈 2     秒级
    │   剥离其他 #Preview / 删除 @main / 整体编译
    │
    ▼ ⑤ 启动宿主进程                     ⚠️ 瓶颈 3     亚秒级但每次 Start/Stop 都重建
    │
    ▼ ⑥ dlopen 加载 dylib                             ~ms 级  ✅ 快
    │
    ▼ ⑦ 截图 + PNG + Base64 编码         ⚠️ 瓶颈 4     百 ms 级
    │
    ▼ ⑧ JSON 传输 + 解码                 ⚠️ 瓶颈 5     百 ms 级
    │
    ▼ 显示
```

**核心矛盾**：每次刷新都走"重编译整个 target → 重新生成 dylib → 整体替换 → 截图 → Base64 传输"的完整链路。

### 1.3 改进目标

| 指标 | 当前 | Phase 1 目标 | Phase 2 目标 | Phase 3 目标 |
|------|------|-------------|-------------|-------------|
| 首次预览 | 5-20s | 3-8s | 2-5s | 1-3s |
| 热重载 | 3-10s | 1-3s | < 1s | < 0.5s |
| 默认交互模式 | Image（静态） | Image（静态） | Live（交互式） | Live（嵌入式） |
| Live 稳定性 | 偶发降级 | 稳定 | 稳定 | 稳定 |

---

## 2. 架构约束

### 2.1 代码组织原则

**`LumiPreviewKit` 不做任何改动。** 它作为稳定的基础设施继续服务当前预览系统。

所有改进代码放在一个新建的 Package 中：

```
Packages/
├── LumiPreviewKit/          ← 不改动，保持现有稳定版本
│
└── LumiHotPreviewKit/       ← 新建，所有改进代码在这里
    ├── Package.swift
    ├── Sources/
    │   ├── LumiHotPreviewKit/              ← 核心引擎库
    │   │   ├── LumiHotPreviewPackage.swift  ← 公开命名空间
    │   │   ├── HotPreviewEngine.swift       ← 新预览引擎（包装 LumiPreviewKit）
    │   │   ├── IncrementalBuildPipeline.swift  ← 增量编译管线
    │   │   ├── CompileCommandCache.swift    ← 编译命令缓存
    │   │   ├── SharedMemoryFrameChannel.swift  ← 共享内存帧传输
    │   │   ├── InterposingDylibLoader.swift ← interposing dylib 加载器
    │   │   └── HostProcessManager.swift     ← 宿主进程常驻管理
    │   │
    │   └── LumiHotPreviewHostApp/           ← 新宿主进程
    │       ├── main.swift
    │       ├── HotPreviewHost.swift          ← 支持帧流 + interposing
    │       ├── HotPreviewRenderer.swift
    │       ├── HotPreviewRenderer+Interposing.swift
    │       └── HotPreviewRenderer+FrameStream.swift
    │
    └── Tests/
        └── LumiHotPreviewKitTests/
```

### 2.2 依赖关系

```
EditorRemotePreviewPlugin（插件 UI 层）
    │
    ├── import LumiHotPreviewKit      ← 新引擎（改进后的编译管线 + 进程管理 + 帧传输）
    │       │
    │       └── import LumiPreviewKit ← 复用现有类型（PreviewDiscovery, BuildStrategy, etc.）
    │
    └── import LumiPreviewKit         ← 降级时直接使用旧引擎
```

- `LumiHotPreviewKit` **依赖** `LumiPreviewKit`，复用其公开类型（`PreviewDiscovery`、`BuildStrategy`、`PreviewScanner`、`IncrementalCompiler` 等）
- `LumiHotPreviewKit` **不修改** `LumiPreviewKit` 的任何代码
- `EditorRemotePreviewPlugin` 可以同时导入两个 Kit，通过开关选择使用新引擎或旧引擎
- 降级策略：新引擎出错时，自动切换到 `LumiPreviewKit` 的旧引擎

### 2.3 宿主进程

新 Kit 自带独立的宿主进程 `LumiHotPreviewHostApp`，与 `LumiPreviewHostApp` 并存：

```
Lumi.app/Contents/Frameworks/（或 Resources/）
├── LumiPreviewHostApp       ← 旧宿主（LumiPreviewKit 使用）
└── LumiHotPreviewHostApp    ← 新宿主（LumiHotPreviewKit 使用）
```

两个宿主进程完全独立，互不影响。插件层决定启动哪一个。

### 2.4 技术方案总览

Xcode Preview 使用大量 **Apple 私有组件**，我们无法直接使用：

| Xcode 内部组件 | 归属 | 我们能用吗 |
|---------------|------|-----------|
| XCPreviewAgent | 私有进程 | ❌ |
| XCBuild | 私有编译系统 | ❌ |
| XPC 通信层 | 私有 Mach service | ❌ |
| 内存注入（dylib swap） | 私有机制 | ❌ |
| Canvas 渲染管线 | Xcode 内部 | ❌ |
| 增量编译调度器 | 编译器内置快速路径 | ❌ |
| `swiftc` / `swift build` / `xcodebuild` | 公开工具链 | ✅ |
| `dlopen` / `dlsym` | 公开 POSIX API | ✅ |
| dyld interposing (`-Xlinker -interposable`) | Xcode 链接器内置 | ✅ |
| Mach 共享内存 | 公开 API | ✅ |

我们用公开 API 在 `LumiHotPreviewKit` 中复刻核心效果，分三个阶段逐步逼近。

---

## 3. Phase 1: 工程优化（低垂果实）

> **目标**：改动小、见效快，预计可将热重载速度提升 2-3x
>
> **改动范围**：`LumiHotPreviewKit` + `EditorRemotePreviewPlugin`
>
> **不改动**：`LumiPreviewKit`

### 3.1 宿主进程常驻

**现状问题**：`LumiPreviewKit` 的 `LivePreviewEngine` 每次 `startPreview` 都 launch 新进程，`stopPreview` 直接 terminate。

**改进方案**：`LumiHotPreviewKit` 新增 `HostProcessManager`，管理一个常驻的宿主进程池。

```
当前（LumiPreviewKit）：
  Start → launch → load → Stop → terminate → Start → launch → load ...

改进（LumiHotPreviewKit）：
  Start → launch → load → Refresh → reload → Refresh → reload → ... （进程常驻）
                                                        只有插件销毁时 terminate
```

- [x] 新建 `Packages/LumiHotPreviewKit/`
- [x] 实现 `HostProcessManager`（Actor）：管理宿主进程生命周期，支持获取/归还连接
- [x] `HostProcessManager.acquire()`：复用已有连接或启动新进程
- [x] `HostProcessManager.release()`：卸载内容但保留进程
- [x] `HostProcessManager.shutdown()`：插件销毁时才真正 terminate
- [x] `HotPreviewEngine`：包装 `LumiPreviewKit.PreviewHostProcess`，用 `HostProcessManager` 管理连接

**预期收益**：消除每次 start/stop 的进程启停延迟（~300-500ms）

### 3.2 Lumi 启动时预热宿主进程

**改进方案**：`HostProcessManager` 支持预热——提前 launch 进程进入空转等待状态。

- [x] `HostProcessManager.warmup()`：后台启动一个宿主进程，不发任何渲染命令
- [x] `EditorRemotePreviewPlugin`：插件加载时调用 `warmup()`
- [x] 新宿主 `LumiHotPreviewHostApp`：启动后立即进入 `NSApplication.run()` 等待命令

**预期收益**：首次预览体感提速 ~300-500ms

### 3.3 图片传输优化：临时文件替代 Base64

**现状问题**：`LumiPreviewKit` 的 `RenderResponse` 通过 `previewImagePNGBase64` 传输图片，Base64 膨胀 33%。

**改进方案**：新宿主进程写 PNG 到临时文件，`LumiHotPreviewKit` 从文件读取。通信协议扩展但兼容旧版。

```
当前（LumiPreviewKit）：
  宿主 → PNG → Base64 编码 → JSON 嵌入 → stdout → JSON 解析 → Base64 解码 → NSImage

改进（LumiHotPreviewKit）：
  新宿主 → PNG → 写入 /tmp/LumiHotPreviewKit/frame_xxx.png
  JSON 只传 {"imageFilePath": "/tmp/.../frame_xxx.png"}
  插件 → 读取文件 → NSImage(contentsOf:)
```

- [x] 新宿主 `HotPreviewRenderer`：截图后写文件到 `/tmp/LumiHotPreviewKit/`
- [x] `LumiHotPreviewKit` 新增 `HotRenderResponse`：包含 `imageFilePath` 字段
- [x] `LumiHotPreviewKit` 新增 `ImageFileLoader`：从文件路径加载 NSImage，带缓存和清理
- [x] `HotPreviewEngine`：优先用文件路径加载图片；如果新宿主不可用，降级到旧宿主的 Base64 路径

**预期收益**：帧传输提速 2-3x

### 3.4 智能防抖与刷新策略

**现状问题**：`EditorRemotePreviewDetailView` 每次 `refreshSignal` 变化都直接触发刷新。

**改进方案**：在插件层添加多层过滤。

- [x] `EditorRemotePreviewDetailView`：添加 300ms 防抖 Timer
- [x] `EditorRemotePreviewService`：`update()` 中对比 `bodySource` hash，未变则跳过
- [x] `LumiHotPreviewKit` 新增 `SyntaxChecker`：调用 `swiftc -parse` 做语法预检
- [x] `HotPreviewEngine.refresh()`：编译前先做语法预检，失败则直接返回错误

**预期收益**：减少 50%+ 的无效编译请求

### 3.5 PreviewEntry 编译缓存增强

**现状问题**：`LumiPreviewKit` 的 `PreviewEntryBuilder` 的 fingerprint 包含 target 所有 Swift 文件的 modification time，很容易 miss。

**改进方案**：`LumiHotPreviewKit` 新增独立缓存层，细化指纹粒度。

- [x] `LumiHotPreviewKit` 新增 `EntryCacheManager`（Actor）
- [x] 指纹计算仅基于：`bodySource` hash + `discovery` 信息 + 编译参数
- [x] 缓存命中时跳过编译，直接 `dlopen` 已有 dylib
- [x] LRU 淘汰策略，限制缓存总大小

**预期收益**：未改 Preview body 时的刷新从秒级降到百 ms 级

---

## 4. Phase 2: 编译管线重构（核心提速）

> **目标**：热重载速度接近 Xcode（< 1 秒），预计提速 5-10x
>
> **改动范围**：`LumiHotPreviewKit` + `LumiHotPreviewHostApp`
>
> **不改动**：`LumiPreviewKit`

### 4.1 核心思路转变

```
当前思路（LumiPreviewKit — 整体替换）：
  文件变化 → 收集 target 所有源文件 → 源码清理 → 编译整个 dylib → dlopen → 替换整个 NSView

新思路（LumiHotPreviewKit — 函数级注入）：
  文件变化 → 只编译变更的 .swift 文件 → 链接成小 dylib → dlopen → interposing 替换函数实现
                                                                    → SwiftUI 自动触发重绘
```

技术可行性参考：社区项目 InjectionIII 已验证"单文件增量编译 + dylib interposing"在 macOS 上可行。LumiHotPreviewKit 在自己的架构内重新实现这些技术，不集成任何第三方代码。

### 4.2 单文件增量编译

**原理**：首次完整编译后，提取每个文件的 `swift-frontend` 编译命令。后续只重编译变更文件。

```
首次编译（调用 LumiPreviewKit 现有编译器）：
  swift build / xcodebuild → 产出 .o 文件 + 编译日志
  ↓
  LumiHotPreviewKit 从编译日志提取每个 .swift 文件的 swift-frontend 命令
  ↓
  存入 CompileCommandCache：[fileURL: compileCommand]

后续刷新（LumiHotPreviewKit 增量编译）：
  用户改了 View.swift
  ↓
  查表拿到 View.swift 的 swift-frontend 命令
  ↓
  只编译 View.swift → View.o
  ↓
  链接 View.o + PreviewEntry.o → PreviewEntry.dylib
  ↓
  codesign → dlopen → 替换
```

- [x] `LumiHotPreviewKit` 新增 `IncrementalBuildPipeline`
- [x] `IncrementalBuildPipeline.extractCommands(from buildLog:)`：解析 build log 提取 swift-frontend 命令
- [x] `CompileCommandCache`（Actor）：持久化存储 `[fileURL: compileCommand]`，存入 `~/Library/Caches/LumiHotPreviewKit/`
- [x] `IncrementalBuildPipeline.compileSingleFile(fileURL:compileCommand:)`：调用 `LumiPreviewKit.IncrementalCompiler.compile()` 编译单文件
- [x] `IncrementalBuildPipeline.linkPreviewEntry(objectURLs:)`：链接 .o 文件为 dylib
- [x] `HotPreviewEngine.refresh()`：优先走增量编译路径，编译命令缓存 miss 时降级到 `LumiPreviewKit` 的全量编译

**预期收益**：编译时间从"编译整个 target"降到"编译 1 个文件"，提速 5-20x

### 4.3 PreviewEntry import 已编译模块

**现状问题**：`LumiPreviewKit` 的 `PreviewEntryBuilder` 需要收集 target 所有源文件、做源码清理、一起编译成 dylib。

**改进方案**：target 编译完成后已有 `.swiftmodule`，入口文件直接 `import` 这个模块。

```swift
// LumiHotPreviewKit 生成的 PreviewEntry.swift — 只有一个文件，几十行代码
import AppKit
import SwiftUI
import MyTargetModule  // ← 已编译好的 target 模块（由 swift build / xcodebuild 产出）

@_cdecl("lumi_preview_make_nsview")
public func lumiPreviewMake_nsview() -> UnsafeMutableRawPointer? {
    let rootView = AnyView({
        // #Preview body 直接嵌入
        MyView()
    }())
    let view = NSHostingView(rootView: rootView)
    view.frame = NSRect(x: 0, y: 0, width: 320, height: 180)
    return Unmanaged.passRetained(view).toOpaque()
}
```

- [x] `IncrementalBuildPipeline.generateEntryImportingModule(discovery:buildStrategy:)`：生成只 import 模块的入口文件
- [x] `IncrementalBuildPipeline.resolveModuleSearchPaths(buildStrategy:)`：从 build 产物中定位 `.swiftmodule` 和 `-I` 路径
- [x] 不再需要 `sanitizedSourceFile`（源码清理逻辑），因为不再包含 target 源文件
- [x] 降级：如果 import 模块失败（如访问 `internal` 类型），回退到 `LumiPreviewKit` 的源码包含模式

**预期收益**：Entry 编译从"编译 N 个文件"降到"编译 1 个 30 行文件"，提速 10x+

### 4.4 dylib Interposing 函数替换

**原理**：利用 dyld 的 interposing 机制，在运行时替换函数实现。新 dylib 加载后，已有的函数调用自动跳转到新实现。

**技术实现**：编译时给 PreviewEntry dylib 添加 `-Xlinker -interposable` 链接标志，dyld 在 `dlopen` 时自动完成符号重绑定，不需要 fishhook 等第三方库。

```
编译时：
  swiftc -emit-library -Xlinker -interposable PreviewEntry.swift ...
  → 链接器为函数调用增加间接跳转表（lazy pointer section）

运行时：
  1. dlopen("NewPreviewEntry.dylib")
  2. dyld 自动将 DYLD_INSERT_LIBRARIES 风格的 interposing section 应用
     新符号覆盖旧的 lazy pointer
  3. 已有的 NSHostingView 的 body 计算自动跳转到新实现
  4. SwiftUI 感知变化 → 自动重绘
```

- [x] `IncrementalBuildPipeline.compilePreviewEntry()`：添加 `-Xlinker -interposable` 链接标志
- [x] 新宿主 `HotPreviewRenderer+Interposing`：实现 interposing 模式的渲染，不再每次创建新 NSHostingView
- [x] 新宿主新增 `PreviewHostCommand.interpose` 命令
- [x] `LumiHotPreviewKit` 新增 `InterposingDylibLoader`：封装 interposing 模式的 dlopen 流程
- [x] 验证：interposing 后 SwiftUI View 的 body 被替换，界面自动更新
- [x] 降级：interposing 失败时回退到整体 dlopen 替换（`LumiPreviewKit` 的方式）

**预期收益**：
- 不需要每次创建新 `NSHostingView`，SwiftUI 状态保持连续
- Live 模式下实现"改代码即看到变化"
- 消除截图 → 传输 → 显示的延迟

### 4.5 共享内存帧传输

Phase 1 用临时文件替代了 Base64，Phase 2 进一步用共享内存消除文件 I/O。

```
方案：
  1. 新宿主进程创建 Mach shared memory entry（mach_port_make_memory_entry_64）
  2. 将 raw pixel data（而非 PNG）写入共享内存
  3. 通过 JSON 消息传递 mach_port name
  4. LumiHotPreviewKit 通过 mach_vm_map 映射同一块内存
  5. 直接构建 NSBitmapImageRep → NSImage，零拷贝
```

- [x] `LumiHotPreviewKit` 新增 `SharedMemoryFrameChannel`：封装共享内存对象的创建、写入、映射
- [x] 新宿主 `HotPreviewRenderer+FrameStream`：新增 `snapshotToSharedMemory()` 方法，写 raw pixels
- [x] `LumiHotPreviewKit` 的 `HotRenderResponse`：新增 `sharedMemoryTag` / `frameSize` / `bytesPerRow` 字段
- [x] `SharedMemoryFrameChannel.mapFrame(tag:size:bytesPerRow:)`：映射共享内存并构建 NSImage
- [x] 降级：共享内存不可用时自动降级到文件传输（Phase 1 方案）→ Base64（LumiPreviewKit 方案）

**预期收益**：帧传输延迟从百 ms 降到 < 10ms

---

## 5. Phase 3: 渲染集成（体验对齐）

> **目标**：Live 模式成为默认体验，预览窗口嵌入编辑器
>
> **改动范围**：`LumiHotPreviewKit` + `LumiHotPreviewHostApp` + `EditorRemotePreviewPlugin`
>
> **不改动**：`LumiPreviewKit`

### 5.1 默认 Live 模式

- [x] `EditorRemotePreviewService`：使用新引擎时，`displayMode` 默认值改为 `.live`
- [x] `EditorRemotePreviewDetailView`：Live 模式下优先显示交互式预览
- [x] Live 失败时自动降级到 Image，状态栏提示降级原因
- [ ] 保留 Image/Live 切换控件供用户手动覆盖

### 5.2 Live 窗口作为 child window 嵌入

**现状问题**：Live 窗口是新宿主进程的独立 `NSPanel`，通过坐标同步"贴"在编辑器画布区域。跨进程窗口会有位置抖动、层级遮挡问题。

**改进方案**：让新宿主进程的 Live 窗口作为编辑器窗口的 child window。

```swift
// 编辑器进程中：
// 通过窗口编号找到新宿主进程的 Live 窗口
let liveWindow = NSApp.windows.first { $0.windowNumber == liveWindowNumber }

// 挂为 child window，层级和移动自动跟随
if let liveWindow {
    editorWindow.addChildWindow(liveWindow, ordered: .above)
}
```

- [ ] `LumiHotPreviewKit` 新增 `LiveWindowBridge`：通过 window number 查找并管理跨进程窗口关系
- [ ] `EditorRemotePreviewDetailView`：Live 模式启动后，调用 `addChildWindow` 嵌入
- [ ] `EditorPreviewLiveCanvasService`：child window 模式下不再需要手动坐标同步
- [ ] 测试：窗口移动、resize、全屏、最小化场景下的跟随行为

**预期收益**：消除跨进程窗口抖动和层级问题

### 5.3 dylib 加载到编辑器进程（最终方案）

> ⚠️ 高风险，需要充分评估稳定性

**原理**：不使用宿主进程，直接在编辑器进程中 `dlopen` 签名过的 PreviewEntry dylib。预览 NSView 直接嵌入 SwiftUI 视图层级。

```
改进后的架构：
  编辑器进程
  ├── Lumi App
  ├── LumiPreviewKit（编译管理）
  ├── LumiHotPreviewKit（新引擎）
  └── PreviewEntry.dylib（dlopen 到编辑器进程）
       └── lumi_preview_make_nsview() → NSView
            └── 直接嵌入 EditorRemotePreviewDetailView 的视图层级
```

- [ ] 评估可行性：dylib 加载到编辑器进程的风险（崩溃隔离、内存泄漏、符号冲突）
- [ ] `LumiHotPreviewKit` 新增 `InProcessPreviewRenderer`：在编辑器进程中直接渲染
- [ ] `EditorRemotePreviewDetailView`：Live 模式下直接嵌入 NSView
- [ ] 崩溃保护：`sigsetjmp` / `siglongjmp` 或 ObjC `@try` 包裹 dylib 调用
- [ ] 内存管理：dylib 卸载时确保所有 NSView/NSHostingView 正确释放
- [ ] 降级策略：检测到不稳定因素时自动降级到宿主进程模式（Phase 2 方案）

**预期收益**：消除所有跨进程通信延迟，预览真正嵌入编辑器

### 5.4 连续帧流

**改进方案**：从 request-response 模式改为新宿主进程持续推送帧流。

```
当前（LumiPreviewKit）：
  编辑器发 render 请求 → 宿主截图 → 返回 → 编辑器显示（一问一答）

改进（LumiHotPreviewKit）：
  新宿主每 100ms 截图 → 写入共享内存环形缓冲区 → 编辑器持续读取显示（流水线）
```

- [ ] 新宿主 `HotPreviewRenderer+FrameStream`：定时截图写入共享内存环形缓冲区
- [ ] `LumiHotPreviewKit` 新增 `FrameStreamReader`：从环形缓冲区持续读取帧数据
- [ ] `EditorRemotePreviewDetailView`：Image 模式下也能看到"动画"预览
- [ ] 性能预算：帧流不超过 10fps，每帧不超过 500KB raw pixels

**预期收益**：预览过渡更平滑，消除 loading → 显示的割裂感

---

## 6. 实施计划 (Implementation Plan)

### Phase 1: 工程优化 — 预计 2-3 周

- [x] 新建 `Packages/LumiHotPreviewKit/`，配置 `Package.swift`，依赖 `LumiPreviewKit`
- [x] 新建 `LumiHotPreviewHostApp` 宿主进程 target
- [x] **3.1** 实现 `HostProcessManager`：宿主进程常驻管理
- [x] **3.2** 实现 `HostProcessManager.warmup()`：启动时预热
- [x] **3.3** 新宿主截图写文件 + `ImageFileLoader` 从文件加载
- [x] **3.4** 插件层 300ms 防抖 + `SyntaxChecker` 语法预检
- [x] **3.5** 实现 `EntryCacheManager`：细化缓存指纹
- [x] 实现 `HotPreviewEngine`：包装新引擎，降级到 `LumiPreviewKit` 旧引擎
- [ ] 修改 `EditorRemotePreviewPlugin`：导入 `LumiHotPreviewKit`，通过开关选择引擎
- [ ] 性能基准测试

### Phase 2: 编译管线重构 — 预计 4-6 周

- [x] **4.2** 实现 `IncrementalBuildPipeline` + `CompileCommandCache`
- [x] **4.3** 实现 import 模块模式的入口生成
- [x] **4.4** 新宿主实现 interposing 渲染模式
- [x] **4.5** 实现 `SharedMemoryFrameChannel` 共享内存帧传输
- [ ] 多项目类型验证（SPM / Xcode / 单文件）
- [ ] 稳定性压测

### Phase 3: 渲染集成 — 预计 3-4 周

- [x] **5.1** 默认 Live 模式
- [ ] **5.2** 实现 `LiveWindowBridge`：child window 嵌入
- [ ] **5.3** 实现 `InProcessPreviewRenderer`（需充分评估风险）
- [ ] **5.4** 实现帧流：环形缓冲区 + `FrameStreamReader`
- [ ] 全场景回归测试

---

## 7. 技术决策 (Technical Decisions)

| 决策点 | 方案 | 理由 |
|--------|------|------|
| **代码组织** | 新建 `LumiHotPreviewKit`，不动 `LumiPreviewKit` | 隔离风险，旧引擎随时可降级 |
| **依赖关系** | `LumiHotPreviewKit` → 依赖 `LumiPreviewKit` | 复用公开类型，不重复造轮子 |
| **宿主进程** | 新建 `LumiHotPreviewHostApp` | 新功能需要新协议，不修改旧宿主 |
| **进程模型** | 保持独立进程（Phase 1-2） | 崩溃隔离，Phase 3 再评估进程内加载 |
| **编译策略** | 新引擎增量编译 → 降级旧引擎全量编译 | 逐步过渡，降低风险 |
| **第三方依赖** | 不引入任何第三方 package | fishhook 不需要，dyld 原生 interposing 足够 |
| **图片传输** | 共享内存 → 临时文件 → Base64（逐级降级） | 每一层都有降级方案 |
| **降级策略** | 新引擎任何环节出错 → 切换到 `LumiPreviewKit` 旧引擎 | 确保 AB 两端版本不匹配时也能工作 |

---

## 8. 风险与应对 (Risks & Mitigations)

| 风险 | 影响 | 应对策略 |
|------|------|----------|
| **interposing 导致符号冲突** | 新宿主进程崩溃 | 严格限制 interposing 范围，只替换 Preview body 相关函数；出错时降级到整体 dlopen |
| **单文件编译命令提取失败** | 无法增量编译 | 降级到 `LumiPreviewKit` 的全量编译（保留旧路径） |
| **共享内存 mach_port 传递失败** | 图片传输中断 | 自动降级到文件传输 → Base64 |
| **import 模块后访问 internal 类型失败** | Preview body 无法引用 target 类型 | 回退到 `LumiPreviewKit` 的源码包含模式 |
| **新 Kit 与旧 Kit 类型冲突** | 编译错误 | 两个 Kit 使用不同命名空间（`LumiPreviewPackage` vs `LumiHotPreviewPackage`） |
| **新宿主进程不稳定** | 预览功能异常 | 插件层提供开关，一键切换到旧引擎 + 旧宿主 |
| **dylib 加载到编辑器进程导致崩溃** | 编辑器不稳定 | Phase 3 充分评估，提供开关让用户选择进程内/外模式 |

---

## 9. 性能度量标准 (Performance Metrics)

每个 Phase 完成后，需要用以下指标验证改进效果：

| 指标 | 测量方法 | Phase 1 目标 | Phase 2 目标 | Phase 3 目标 |
|------|---------|-------------|-------------|-------------|
| **首次预览延迟** | 从切换到 Preview 面板到看到渲染结果的 wall time | < 8s | < 5s | < 3s |
| **热重载延迟** | 从代码变更到看到新渲染结果的 wall time | < 3s | < 1s | < 0.5s |
| **帧传输延迟** | 从宿主截图到编辑器显示的延迟 | < 200ms | < 50ms | < 10ms |
| **编译命中率** | 缓存命中 / 总编译请求 | > 30% | > 70% | > 70% |
| **Live 模式成功率** | Live 成功启动 / Live 尝试次数 | > 85% | > 95% | > 98% |
| **内存占用** | 宿主进程 + 编辑器进程增量 | < 200MB | < 200MB | < 150MB |

---

## 10. 与现有系统的兼容性

| 关注点 | 方案 |
|--------|------|
| **LumiPreviewKit 不受影响** | 所有改动在新 Kit 中，旧 Kit 代码和宿主进程完全不动 |
| **新旧引擎共存** | 插件通过配置或运行时检测选择引擎，新引擎失败自动降级到旧引擎 |
| **新旧宿主进程共存** | 两个可执行文件独立部署，互不干扰 |
| **用户设置保留** | 用户偏好（如 Image/Live 选择）在新旧引擎间通用 |
| **类型系统兼容** | 新 Kit 复用 `LumiPreviewKit` 的公开类型（`PreviewDiscovery`、`BuildStrategy` 等），不重新定义 |

---

此 Roadmap 定义了 **EditorRemotePreviewPlugin** 性能改进的完整技术路径。核心原则：**不动 `LumiPreviewKit`，所有改进在新建的 `LumiHotPreviewKit` 中实现**，通过依赖关系复用现有类型，通过降级策略确保稳定性。
