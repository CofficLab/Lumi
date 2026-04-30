# CPU Top Processes Roadmap

## 1. 概述 (Overview)

### 1.1 背景

当前 `CPUStatusBarPopupView` 展示了 CPU 总使用率和最近 60 秒的趋势图，但用户无法直观看到"是哪些进程占用了 CPU"。当 CPU 飙高时，用户需要手动打开活动监视器才能排查，体验中断。

### 1.2 目标

在 `CPUStatusBarPopupView` 下方新增"Top 5 CPU 占用进程"列表，让用户在弹窗内即可定位 CPU 热点进程，无需切换到其他工具。

### 1.3 设计原则

- **原生 API 优先**: 使用 `libproc` 采集进程数据，与现有 `CPUService` 的 Mach API 风格一致，避免子进程开销
- **最小侵入**: 复用已有的 `ProcessMetric` 数据模型，不修改 `CPUService` / `CPUHistoryService` 等核心文件
- **风格统一**: 遵循 `AppUI` 组件库的 GlassCard、Typography、Color 体系
- **性能可控**: 3 秒采样间隔，仅采集 top N 进程详情，避免全量遍历的性能开销

---

## 2. 架构设计 (Architecture)

### 2.1 组件关系图

```
┌─────────────────────────────────────────────────────┐
│  CPUStatusBarPopupView                               │
│  ┌─────────────────────────────────────────────┐    │
│  │  liveLoadView          (已有 — CPU 总使用率)   │    │
│  ├─────────────────────────────────────────────┤    │
│  │  miniTrendView         (已有 — 60s 趋势图)    │    │
│  ├─────────────────────────────────────────────┤    │
│  │  TopProcessesView      (新增 — Top 5 进程)    │    │
│  │  ┌─────┬──────────┬───────┬────────────┐     │    │
│  │  │ Icon│ 进程名    │ CPU%  │ 进度条      │     │    │
│  │  ├─────┼──────────┼───────┼────────────┤     │    │
│  │  │ 🔵  │ Chrome   │ 32%   │ ████       │     │    │
│  │  │ 🟢  │ Xcode    │ 18%   │ ██         │     │    │
│  │  │ ... │ ...      │ ...   │ ...        │     │    │
│  │  └─────┴──────────┴───────┴────────────┘     │    │
│  └─────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────┐
│  CPUManagerViewModel                         │
│  @Published topProcesses: [ProcessMetric]     │  ← 扩展现有 ViewModel
├─────────────────────────────────────────────┤
│  ProcessService                              │  ← 新建服务
│  func startMonitoring(interval: 3.0)        │
│  func stopMonitoring()                       │
│  @Published topProcesses: [ProcessMetric]    │
│  内部: libproc API → delta 计算 → 排序        │
└─────────────────────────────────────────────┘
```

### 2.2 插件目录结构变更

```
LumiApp/Plugins/DeviceInfoPlugin/
├── Services/
│   ├── CPUService.swift              (不修改)
│   ├── CPUHistoryService.swift       (不修改)
│   ├── SystemMonitorService.swift    (不修改)
│   ├── MemoryService.swift           (不修改)
│   ├── MemoryHistoryService.swift    (不修改)
│   └── ProcessService.swift          ← 新建
├── ViewModels/
│   ├── CPUManagerViewModel.swift     ← 小改 (增加进程数据订阅)
│   └── ...
├── Views/
│   ├── CPUStatusBarPopupView.swift   ← 小改 (追加 TopProcessesView)
│   ├── TopProcessesView.swift        ← 新建
│   └── ...
└── Models/
    └── MonitorModels.swift           (不修改 — ProcessMetric 已定义)
```

---

## 3. 详细设计 (Detailed Design)

### 3.1 数据模型

复用已有的 `ProcessMetric`（`MonitorModels.swift`）:

```swift
struct ProcessMetric: Identifiable, Hashable {
    let id: Int32       // PID
    let name: String
    let icon: String?   // Bundle path
    let cpuUsage: Double
    let memoryUsage: Int64
}
```

### 3.2 `ProcessService`（新建）

**文件**: `Services/ProcessService.swift`

**职责**: 通过 `libproc` 采集进程 CPU 占用，计算 delta，返回 top N。

**核心流程**:

```
Timer (3s interval)
    │
    ▼
proc_listpids(PROC_ALL_PIDS) → 获取全部 PID 列表
    │
    ▼
遍历 PID:
  proc_pidinfo(pid, PROC_PIDTASKINFO) → proc_taskinfo
    ├── pti_total_user  (用户态时间, nanoseconds)
    └── pti_total_system (内核态时间, nanoseconds)
    │
    ▼
与上次采样快照对比，计算 CPU% delta:
  cpuPercent = (deltaUser + deltaSystem) / (deltaWallClock * numCPU) * 100
    │
    ▼
按 cpuPercent 降序排序，取前 5
    │
    ▼
通过 proc_name() 获取进程名
通过 NSWorkspace.shared.runningApplications 关联 App 图标（可选）
    │
    ▼
@Published topProcesses: [ProcessMetric]
```

**关键实现细节**:

```swift
@MainActor
class ProcessService: ObservableObject {
    static let shared = ProcessService()
    
    @Published var topProcesses: [ProcessMetric] = []
    
    // 采样快照: [pid: (userTime, systemTime)]
    private var previousSnapshot: [Int32: (user: UInt64, system: UInt64)] = [:]
    private var previousTimestamp: TimeInterval = 0
    
    private var timer: Timer?
    private var subscribersCount = 0
    private let processLimit = 5
    
    func startMonitoring(interval: TimeInterval = 3.0) { ... }
    func stopMonitoring() { ... }
    
    private func sampleProcesses() { ... }
    private func calculateCPU(previous:current:deltaTime: numCPUs:) -> Double { ... }
    private func getProcessName(pid: Int32) -> String { ... }
}
```

**CPU% 计算公式**:

```
deltaUser   = currentUser   - previousUser
deltaSystem = currentSystem - previousSystem
deltaTime   = currentTime   - previousTime

cpuPercent  = (deltaUser + deltaSystem) / (deltaTime × numCPU × 1_000_000_000) × 100
```

> 注: `pti_total_user` / `pti_total_system` 单位为 nanoseconds，`deltaTime` 为秒，需乘以 `1_000_000_000` 对齐量纲。

### 3.3 `CPUManagerViewModel`（扩展）

**修改点**:

```swift
@MainActor
class CPUManagerViewModel: ObservableObject {
    // ... 现有属性 ...
    
    // 新增
    @Published var topProcesses: [ProcessMetric] = []
    
    func startMonitoring() {
        // ... 现有逻辑 ...
        
        // 新增: 启动进程监控
        ProcessService.shared.startMonitoring()
        ProcessService.shared.$topProcesses
            .receive(on: DispatchQueue.main)
            .assign(to: &$topProcesses)
    }
}
```

### 3.4 `TopProcessesView`（新建）

**文件**: `Views/TopProcessesView.swift`

**UI 布局**:

```
┌──────────────────────────────────────────┐
│  📊 Top Processes                    (标题) │
├──────────────────────────────────────────┤
│  ┌──┐ Chrome Helper (GPU)     32%  ████ │
│  ├──┘                                   │
│  ┌──┐ Xcode                    18%  ██  │
│  ├──┘                                   │
│  ┌──┐ WindowServer              8%  █   │
│  ├──┘                                   │
│  ┌──┐ mds_stores                5%  ▌   │
│  ├──┘                                   │
│  ┌──┐ Safari                    3%  ▌   │
│  └──┘                                   │
└──────────────────────────────────────────┘
```

**设计规格**:
- 每行高度: 28pt，紧凑排列
- 进程图标: 16×16，通过 `NSWorkspace.shared.icon(forFile:)` 获取 App 图标，非 App 进程使用 `system("terminal")` 占位
- 进程名: `.caption1` 字体，单行截断
- CPU%: `.caption1` monospaced 字体，右对齐
- 进度条: 4pt 高度 Capsule，宽度 40pt，颜色跟随 `AppUI.Color.semantic.info`
- 列表无数据时: 显示"Collecting..."提示文字
- 背景: `AppUI.Material.glass.opacity(0.3)`，与 `miniTrendView` 风格一致

### 3.5 `CPUStatusBarPopupView`（修改）

**修改点**: 在 `body` 的 `VStack` 中追加 `topProcessesView`。

```swift
var body: some View {
    HoverableContainerView(detailView: CPUHistoryDetailView()) {
        VStack(spacing: 0) {
            liveLoadView      // 已有
            miniTrendView     // 已有
            topProcessesView  // 新增
        }
    }
}

// 新增
private var topProcessesView: some View {
    TopProcessesView(processes: viewModel.topProcesses)
}
```

---

## 4. 技术决策

| 决策点 | 方案 | 理由 |
|--------|------|------|
| **采集 API** | `libproc` (`proc_listpids` + `proc_pidinfo`) | 纯原生，无子进程开销，与现有 Mach API 风格一致 |
| **采样间隔** | 3 秒 | 平衡实时性与 CPU 开销，比 `CPUService` 的 1 秒间隔更宽松 |
| **进程数量** | Top 5 | 足以覆盖主要 CPU 热点，避免列表过长 |
| **服务单例** | `ProcessService.shared` | 与 `CPUService.shared` 模式一致，便于 ViewModel 订阅 |
| **图标获取** | `NSWorkspace.shared.icon(forFile:)` | 原生 API，对 App 类进程效果好 |
| **排序依据** | CPU% 降序 | 最直观反映 CPU 热点 |

---

## 5. 影响范围

| 文件 | 操作 | 改动量 | 风险 |
|------|------|--------|------|
| `Services/ProcessService.swift` | 新建 | ~120 行 | 低 — 独立服务 |
| `Views/TopProcessesView.swift` | 新建 | ~80 行 | 低 — 纯展示组件 |
| `ViewModels/CPUManagerViewModel.swift` | 小改 | +8 行 | 低 — 仅增加订阅 |
| `Views/CPUStatusBarPopupView.swift` | 小改 | +6 行 | 低 — 仅追加子视图 |

**不涉及修改**: `CPUService`、`CPUHistoryService`、`CPUModels`、`MonitorModels`、`DeviceInfoPlugin`。

---

## 6. 实施计划 (Implementation Plan)

### Phase 1: 数据采集服务
- [ ] 新建 `ProcessService.swift`
  - [ ] 实现 `proc_listpids` 获取 PID 列表
  - [ ] 实现 `proc_pidinfo(PROC_PIDTASKINFO)` 获取进程 CPU 时间
  - [ ] 实现 delta 快照计算 CPU%
  - [ ] 实现 `proc_name()` 获取进程名
  - [ ] 实现 3 秒定时器与生命周期管理（引用计数）
  - [ ] 实现按 CPU% 降序排序、取 top 5

### Phase 2: ViewModel 接入
- [ ] 扩展 `CPUManagerViewModel`
  - [ ] 新增 `@Published var topProcesses: [ProcessMetric]`
  - [ ] 在 `startMonitoring()` 中订阅 `ProcessService`

### Phase 3: UI 开发
- [ ] 新建 `TopProcessesView.swift`
  - [ ] 进程图标 + 名称 + CPU% + 进度条布局
  - [ ] 空状态 ("Collecting...")
  - [ ] 风格与 `miniTrendView` 一致
- [ ] 修改 `CPUStatusBarPopupView`
  - [ ] 在 `VStack` 末尾追加 `TopProcessesView`

### Phase 4: 验证与打磨
- [ ] 验证: CPU 飙高场景下进程列表实时更新
- [ ] 验证: 进程退出/新增时的容错（PID 消失不崩溃）
- [ ] 验证: 多次打开/关闭弹窗不会泄漏 timer
- [ ] 打磨: 非 App 进程的图标占位
- [ ] 打磨: 进程名过长时的截断处理

---

## 7. 与现有系统的联动

| 系统 | 联动方式 |
|------|----------|
| `CPUService` | 同为 CPU 监控服务，`ProcessService` 独立运行，不互相干扰 |
| `CPUHistoryService` | `ProcessService` 仅提供实时 top N，不参与历史记录 |
| `SystemMonitorService` | `ProcessMetric` 模型与其 `SystemMetrics` 体系独立 |
| `DeviceInfoPlugin` | 无需修改入口，`CPUStatusBarPopupView` 自动携带新功能 |

---

## 8. 风险与应对

| 风险 | 应对策略 |
|------|----------|
| **权限限制**: 部分进程可能无法读取 `proc_pidinfo` | 跳过无权限的 PID，不报错 |
| **性能**: 全量遍历 PID 列表有开销 | 3 秒间隔 + 仅采集 top N 的详细数据 |
| **进程退出**: 采样期间 PID 可能消失 | 用 `try/catch` 容错，跳过已退出的 PID |
| **App 图标**: 非 App 进程无 bundle 路径 | 使用 `system("terminal")` 占位图标 |
| **Timer 泄漏**: 用户频繁打开/关闭弹窗 | 引用计数管理，`deinit` 时强制释放 |
