# 主线程并发优化 Roadmap

## 执行摘要

本 Roadmap 围绕"让整个 App 更流畅、所有可后台的操作移出主线程"这一目标，对 Lumi（3267 个真实源文件）做了主线程性能扫描，识别出 **5 个层级、共 0 个具体优化点**。

核心原则：**凡是不需要立即更新 UI 的工作（磁盘 I/O、JSON 解析、内核采样、网络、PNG 编码、正则编译）一律放到后台 `Task.detached` / `Task`；主线程只负责应用结果。**

> 与现有文档的关系：
> - `docs/editor-performance-analysis.md` 关注**编辑器内部**（TreeSitter 解析、Highlighting、布局缓存等）。
> - `docs/memory-growth-audit.md` 关注**内存增长**。
> - 本文档聚焦**主线程并发模型**（轮询、同步 I/O、采样线程归属），三者互补、不重叠。

预期收益：消除全局常驻的菜单栏 1 秒轮询，编辑 Swift 代码时打字更顺滑，打开设备/监视页面不再卡顿。

---

## 改造总览

| 优先级 | 项目 | 影响范围 | 触发频率 | 收益 |
|---|---|---|---|---|

---

## Phase 0：通用约定与验收标准

### 后台化改造模板

凡是采样类、I/O 类工作，遵循同一模式（已在同插件的 `CPUService` 中验证可行）：

```swift
// ✅ 正确模式（CPUService.swift:79 已在用）
private func updateCPUUsage() {
    guard samplingTask == nil else { return }
    let previousTicks = previousTicks

    samplingTask = Task.detached(priority: .utility) { [previousTicks] in
        let snapshot = Self.calculateCPUSnapshot(previousTicks: previousTicks)  // 重活在后台
        await MainActor.run { [weak self] in                                    // 主线程只赋值 @Published
            guard let self else { return }
            self.samplingTask = nil
            self.cpuUsage = snapshot.totalUsage
            // ...
        }
    }
}
```

### 验收标准

- [ ] 所有 P0/P1 项改造后，用 Instruments Time Profiler 复测，主线程采样占比显著下降。
- [ ] 改造不改变任何对外行为（数据值、刷新频率、UI 表现一致）。
- [ ] 每项配最小化单元测试（采样值正确性、缓存命中/失效、后台 Task 可取消）。
- [ ] 新增的后台 Task 在视图/服务销毁时正确取消，避免泄漏（参考 `CPUService.stopMonitoring`）。

---

## Phase 4（P3）：低频主线程 I/O 清理

## Phase 4（P3）：低频主线程 I/O 清理

> 多为用户操作触发，频率低，但都是"可后台就后台"的明确候选，建议一并清理以保持并发模型一致性。

| 位置 | 问题 | 处理 |
|---|---|---|
| `Plugins/NetworkManagerPlugin/Sources/Services/NetworkHistoryService.swift:203-217` | 启动时同步读 + 解析最多 43200 个数据点 | 解码移后台，UI 先展示空态再回填 |

**预期效果**：整体观感更顺滑，并发模型统一。

---

## 验证清单（Instruments）

改造完成后建议按下列场景用 Time Profiler / Main Thread Checker 复测：

（所有优化点已完成）

---

## 实施建议

1. **P0 两项可并行、独立交付**：菜单栏轮询改造（LumiApp 层）与 LSP 诊断缓存（EditorService 层）互不影响，建议优先做，收益最大、风险可控。
2. **P1 一组对照样板改**：`SystemMonitorService` 直接照搬同插件 `CPUService` 的 `Task.detached` 模式，改动小、模式成熟。
3. **每项配回归测试**：尤其采样类，需断言"采样值正确"与"采样在后台线程执行"两点，避免后续回归。
4. **后台 Task 生命周期**：所有新增后台 Task 必须在对应服务/视图停止时取消，纳入 `stopMonitoring` / `deinit` 流程，避免泄漏。
