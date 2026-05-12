# LumiPreviewKit TODO

> 目标：让 Lumi 的实时预览体验尽量接近 Xcode Canvas。
>
> 当前 Live 模式已经能通过独立 host 进程加载真实 SwiftUI/AppKit view，但承载方式仍是独立 `NSWindow` 覆盖在编辑器预览区域上方。下一阶段重点不是继续堆功能，而是把窗口归属、焦点、可见性、刷新和失败恢复做稳，让用户感觉它属于 Lumi，而不是一个会乱飘的外部窗口。

---

## 设计原则

- Live 预览代码继续运行在独立 `LumiPreviewHostApp` 中，避免用户预览代码崩溃拖垮 Lumi 主进程。
- 图片模式长期保留，作为稳定 fallback、错误恢复、低资源模式和自动化测试基线。
- Live 预览必须像 Lumi 主窗口的一部分：主窗口失焦、隐藏、切换 Space、最小化、关闭 panel 时，Live 视图不能残留在其他 app 上方。
- 用户保存后允许有构建/刷新延迟，但 UI 必须明确显示“等待刷新 / 正在更新 / 更新失败 / 使用旧视图”。
- 优先修复窗口生命周期和体验一致性，再考虑更高级的 hot reload。

---

## 阶段一：窗口归属与层级

> 目标：解决 Live window 偶尔脱离 Lumi、盖住其他 app、切换 app 后仍然可见的问题。

- [x] 调研当前 `LumiPreviewHostApp` 的 `liveWindow` 配置：`styleMask`、`level`、`collectionBehavior`、`canBecomeKey`、`hidesOnDeactivate`。
- [x] 去掉不必要的 `orderFrontRegardless()`，改为受主 app 显示状态驱动的 show/hide。
- [x] Live window 默认使用普通层级或贴近主窗口层级，不能使用会覆盖其他 app 的高层级。
- [x] 主 app 失去 active 状态时立即 hide live window。
- [x] 主 app 恢复 active 且 preview panel 仍可见时再 show live window。
- [x] 主窗口 miniaturize、close、hide、进入后台时，强制 hide/stop live window。
- [x] 多窗口场景下，Live window 必须绑定到对应 editor window，不能跟错窗口。
- [x] 增加日志：每次 show/hide/updateFrame 都记录原因，便于排查窗口残留。
- [x] 测试：切到其他 app 后 Live window 不再覆盖其他 app。
- [x] 测试：Lumi 重新激活后会先请求 frame resync，再重新显示 Live window。
- [x] 测试：Lumi 重新激活后 Live window 回到正确位置。

---

## 阶段二：Canvas 定位与同步

> 目标：让 Live window 看起来稳定嵌在 preview canvas 内。

- [x] 统一主 app 到 host 的 frame 同步协议，明确使用屏幕坐标、scale、visible rect。
- [x] window move/resize、split view resize、panel resize、tab 切换时节流同步 frame。
- [x] 当 canvas 不可见、尺寸为 0、被切走或 panel 折叠时 hide live window。
- [x] 处理多显示器和 Retina scale，避免 1-2px 偏移或尺寸漂移。
- [x] 处理 fullscreen / Stage Manager / Mission Control 后的 frame 重算。
- [x] Live window 背景、裁剪、圆角与 canvas 视觉保持一致。
- [x] 测试：拖动 Lumi 主窗口，Live view 跟随且不残留旧位置。
- [x] 测试：调整左右/底部 split，Live view 尺寸同步。
- [x] 测试：切换 panel tab、关闭预览时 Live view 消失。
- [x] 测试：切换文件时旧 session stop 不影响新 session 运行。
- [x] 测试：切换文件时 Live view 消失且不残留旧窗口。

---

## 阶段三：焦点与交互

> 目标：交互像 Xcode Canvas，不像一个抢焦点的独立窗口。

- [x] 明确 Live window 是否允许成为 key window；默认避免抢走 Lumi 主窗口焦点。
- [x] 点击 Live view 内部时允许控件交互，例如 Button、List、ScrollView、TextField。
- [x] 点击 Lumi UI 时，焦点可靠回到主 app。
- [x] 处理键盘输入：TextField 可输入，但快捷键如 Command-S 不应被 preview window 吞掉。
- [x] 处理 preview 弹出的 sheet/popover/menu，至少不破坏主窗口层级。
- [x] 测试：Live view 内按钮点击后状态变化。
- [x] 测试：Live view 内滚动列表可滚动。
- [x] 测试：Command-S 仍保存编辑器文件并触发预览刷新。

---

## 阶段四：刷新状态与旧视图保留

> 目标：保存后刷新期间有明确过渡，不闪空白，不误导用户。

- [x] 保存后立刻进入 `waitingToRefresh`，debounce 期间显示轻量状态。
- [x] 开始构建/加载 dylib 后进入 `refreshing`，toolbar 和 canvas 显示进度。
- [x] reload 成功前继续显示旧 live view，不提前清空 canvas。
- [x] reload 成功后原子替换 root view，并保持窗口 frame、可见性和焦点策略。
- [x] 构建失败时保留旧 live view，同时在 Lumi 错误区域展示新错误。
- [x] 构建失败状态要明确标注“正在显示上一次成功预览”。
- [x] 手动刷新和自动刷新共用同一状态机，避免并发 reload。
- [x] 测试：修改 preview 代码保存后，旧 view 保持到新 view 就绪。
- [x] 测试：reload 失败时旧 view 仍可见。
- [x] 测试：reload 失败时错误信息可复制。

---

## 阶段五：Host 生命周期与资源回收

> 目标：长时间使用不残留进程、不残留窗口、不无限占用临时文件。

- [x] 为每个 preview session 明确 host 生命周期：start、reuse、hide、stop、terminate。
- [x] 切换文件时优先复用可复用 host；不可复用时先 hide 旧 window，再启动新 session。
- [x] 预览 panel 关闭或 app 退出时，确保 host 进程和 live window 全部关闭。
- [x] host 崩溃后主 app 能检测并把状态标为 failed，允许用户重试。
- [x] 清理过期 dylib、build 产物和临时目录，避免长期堆积。
- [x] 记录 host PID、当前 dylib、当前 preview id，便于调试。
- [x] 测试：反复打开/关闭预览不会残留 host 进程。
- [x] 测试：host crash 后主 app 不崩溃，UI 可恢复。

---

## 阶段六：接近 Xcode 的 Canvas 能力

> 目标：在基础稳定后补齐用户自然期待的预览能力。

- [x] 支持多 `#Preview` 快速切换，并保证旧 preview 立即隐藏。
- [x] 支持不同设备/尺寸 presets，例如 compact、regular、fixed size。
- [x] 支持缩放、居中、适配宽高。
- [x] 支持刷新性能指标：build、load、render/reload 耗时。
- [x] 支持 preview diagnostic overlay：当前模式、host 状态、dylib 路径、最后错误。
- [x] 评估更细粒度 hot reload：文件级重编译、函数级替换、Injection 类方案。
- [x] 评估是否可用更深的嵌入方式替代覆盖窗口，但不能牺牲崩溃隔离。

### Hot Reload 评估结论

- 当前已经做到“文件保存后重新构建 preview entry dylib，并在 host 内原子替换 root view”。这是稳定边界内最实用的 hot reload 形态。
- 文件级重编译可以继续优化：保留 `BuildFingerprint` 和 `PreviewEntryBuilder` 缓存，后续重点是缩小 fingerprint 范围、复用 target build 结果、减少无关文件改动触发的 full target build。
- 函数级替换或 Injection 类方案风险较高：SwiftUI view body、泛型、属性包装器、跨 module 符号和 ABI 都会让替换粒度很难可靠控制；一旦替换失败，错误也更难解释给用户。
- 结论：短期继续走“target build 缓存 + preview entry dylib 快速重建 + root view 原子替换”。函数级 Injection 只作为研究方向，不进入默认实现路径。

### 深度嵌入评估结论

- 公开 AppKit API 下，不能把另一个进程里的任意 `NSView` 直接放入 Lumi 主进程 view hierarchy，同时又保持崩溃隔离。
- 真正像 Xcode Canvas 那样稳定嵌入，通常需要更深的私有/系统级 preview infrastructure；在 Lumi 当前约束下不可直接复刻。
- 当前 overlay window 方案的工程边界清晰：预览崩溃隔离好、实现可控，但必须持续维护 window ownership、focus、Space、fullscreen、多显示器和隐藏/恢复行为。
- 结论：保留独立 host + overlay window 作为默认 Live 模式；继续把它做得像主窗口子区域，而不是牺牲崩溃隔离去追求伪嵌入。

---

## 验收标准

- [x] Live 预览不会在 Lumi 失焦后留在其他 app 上方。
- [x] Live 预览跟随 Lumi 主窗口移动、resize、隐藏、恢复。
- [x] 保存并刷新时不出现空白 canvas，除非首次预览还没有任何成功结果。
- [x] 构建失败时旧预览保留，新错误清晰展示。
- [x] Command-S、tab 切换、文件切换、panel 切换都不会破坏 Live window 状态。
- [ ] 连续编辑 30 分钟无 host 进程泄漏、无残留窗口、无明显临时文件堆积。

### 验收证据

- `Command-S`：`EditorServiceFacadeTests.testBuiltinSavePersistsDirtyBufferAndClearsDirtyState` + `EditorPreviewRefreshSignalTests.saveRevisionOnlyChangeTriggersRefresh`
- `tab / panel 切换`：`EditorPreviewLiveCanvasServiceTests.panelTabSwitchKeepsWindowHiddenUntilVisibleAgain`
- `文件切换`：`PreviewEngineTests.switchingFilesStopsOldLiveWindowWithoutBreakingNewOne`
- `Live window 不吞快捷键`：`PreviewDisplayModeTests.livePreviewWindowDoesNotConsumeCommandShortcut`
- `失焦后不覆盖其他 app`：阶段一已完成项 `主 app 失去 active 状态时立即 hide live window` + `EditorPreviewLiveCanvasServiceTests.resignAndBecomeKeyToggleVisibility` + `PreviewDisplayModeTests.livePreviewWindowHidesOnDeactivateAtNormalLevel`
- `刷新期间不闪空白`：阶段四已完成项 `reload 成功前继续显示旧 live view`，以及 `HostProcessTests.failedReloadKeepsPreviousPreview` + `PreviewEngineTests.liveRefreshCompileFailureKeepsPreviousSuccessfulResponse`
- `主窗口移动 / resize / 隐藏 / 恢复`：`EditorPreviewLiveCanvasServiceTests.rapidMoveCoalescesToLatestFrameWithoutHiding` + `EditorPreviewLiveCanvasServiceTests.rapidResizeCoalescesToLatestFrame` + `EditorPreviewLiveCanvasServiceTests.canvasDisappearAndMiniaturizeHideLiveWindow` + `EditorPreviewLiveCanvasServiceTests.appReactivationUsesLatestFrameBeforeShowing` + `PreviewDisplayModeTests.hideAndShowLivePreviewReusesWindow`

---

## 已知限制

- 公开 API 下不能简单地把另一个进程里的任意 `NSView` 直接塞进 Lumi 的 view hierarchy。
- 当前方案仍是“独立 host window 覆盖 canvas”，工程上不是主 app 的真实子视图。
- 因此窗口层级、焦点、Space、全屏、多显示器必须作为核心能力维护，而不是附加细节。
- 如果未来要进一步接近 Xcode，需要继续研究更深的 host/canvas 集成方式。
