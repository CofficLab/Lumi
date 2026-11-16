# TestPlan — PluginEditorPreview

## 包概述

PluginEditorPreview 的实现包，包含 6 个主要类型；当前测试覆盖 19 条用例。

平台: macOS 14+, iOS 17+
测试文件: 4 个，用例总数: 19

核心组件（源码目录）:
- `Capabilities/`
- `Observers/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `EditorPreviewLocalization`
- `EditorPreviewPlugin`
- `EditorPreviewProjectCapability`
- `EditorPreviewProjectObserver`
- `EditorPreviewState`
- `EditorPreviewView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **EditorPreview**（8 条）：由 `markdownExtensions`、`imageExtensions`、`svgExtensions` 等用例锁定；改动该模块时优先跑对应测试文件。
- **EditorPreviewPolling**（3 条）：由 `reloadsAfterFileChange`、`stateStableWhenFileUnchanged`、`deletedFileDoesNotCrash` 锁定文件元数据轮询（#1245）；元数据探测须在后台线程，内容变化即重读、删除不崩溃。
- **EditorPreviewImageLoad**（5 条）：由 `loadRunsOffMain`、`publishesLoadedImage`、`staleSelectionDoesNotOverwrite` 等锁定图片后台加载与代次校验（#1194）；不得在 `View.body` 同步打开图片，晚到的旧选中不得覆盖最新选中。
- **EditorPreviewPluginLifecycle**（3 条，**回归 #364**）：由 `disabledPluginDoesNotReRegisterOnFileSwitch`、`enableRestoresPreviewTab`、`disabledPluginDoesNotReRegisterOnProjectChange` 锁定禁用态守卫；插件禁用后切换文件/项目都不得重新注册 Preview 入口，只有重新启用才恢复。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | EditorPreview | recognizes Markdown extensions | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `markdownExtensions` |
| 2 | EditorPreview | recognizes common image extensions | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `imageExtensions` |
| 3 | EditorPreview | recognizes SVG as an image preview | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `svgExtensions` |
| 4 | EditorPreview | SVG files render through NSImage | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `svgRendersThroughNSImage` |
| 5 | EditorPreview | falls back for unsupported files | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unsupportedExtensions` |
| 6 | EditorPreview | unsupported preview states do not keep the Content Footer | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unsupportedStatesHidePreviewFooter` |
| 7 | EditorPreview | observes the current file from ProjectProviding | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `projectObserverUpdatesViewModel` |
| 8 | EditorPreview | 保存当前 Markdown 后 Preview 自动重读新内容（**回归 #1016**） | 当前 Markdown 已渲染完成 | 原地改写文件内容（模拟编辑器保存），不触发任何项目事件 | 轮询检测到修改时间/大小变化后，状态更新为保存后的 Markdown 内容 | P0 | ✅ 已覆盖 | `savingCurrentMarkdownRefreshesPreview` |
| 9 | EditorPreviewPolling | 内容变化后预览重读到新内容 | 选中临时 Markdown 并完成首次加载 | 外部写入新内容（修改时间+大小变化） | 轮询检测到变化后状态更新为新内容 | P1 | ✅ 已覆盖 | `reloadsAfterFileChange` |
| 10 | EditorPreviewPolling | 内容未变化时状态保持不变 | 选中临时 Markdown 并完成首次加载 | 等待数个轮询周期，不改写文件 | 状态保持原 Markdown 内容 | P1 | ✅ 已覆盖 | `stateStableWhenFileUnchanged` |
| 11 | EditorPreviewPolling | 文件被删除后预览不崩溃 | 选中临时 Markdown 并完成首次加载 | 删除磁盘文件后继续轮询 | 不崩溃，状态非 empty | P0 | ✅ 已覆盖 | `deletedFileDoesNotCrash` |
| 12 | EditorPreviewImageLoad | 图片打开在后台线程执行 | 生成临时 PNG | 后台调用图片加载并记录线程标志 | 打开/解码不在主线程，尺寸正确 | P1 | ✅ 已覆盖 | `loadRunsOffMain` |
| 13 | EditorPreviewImageLoad | 打不开的文件返回 nil | 指向不存在的 PNG | 同步与异步各加载一次 | 均返回 nil | P1 | ✅ 已覆盖 | `unreadableFileReturnsNil` |
| 14 | EditorPreviewImageLoad | 选中图片后异步发布已加载的图片 | 生成临时 PNG 并选中 | 等待异步加载完成 | 状态为 image，发布已加载图片且尺寸正确 | P1 | ✅ 已覆盖 | `publishesLoadedImage` |
| 15 | EditorPreviewImageLoad | 晚到的旧选中图片不覆盖最新选中 | 旧加载挂起在门闩上 | 切换选中新图片先完成，再放行旧加载 | 旧结果被丢弃，仍显示最新选中图片 | P0 | ✅ 已覆盖 | `staleSelectionDoesNotOverwrite` |
| 16 | EditorPreviewImageLoad | 图片打不开时进入失败态而不是渲染空图 | 指向不存在的 PNG 并选中 | 等待异步加载完成 | 进入 failed 态，previewImage 为 nil | P1 | ✅ 已覆盖 | `unreadableImageFails` |
| 17 | EditorPreviewPluginLifecycle | 禁用后切换文件不得重新注册 Preview 入口（**回归 #364**） | 插件已 Boot，选中可预览文件并注册入口 | onDisable 撤回入口后切换到另一个可预览文件 | 禁用期间入口数保持 0，不得重新注册 | P0 | ✅ 已覆盖 | `disabledPluginDoesNotReRegisterOnFileSwitch` |
| 18 | EditorPreviewPluginLifecycle | 重新启用后恢复 Preview 入口（**回归 #364**） | 插件已 Boot，选中可预览文件并注册入口 | onDisable 撤回入口后再 onEnable | 按当前文件恢复入口，入口数为 1 | P1 | ✅ 已覆盖 | `enableRestoresPreviewTab` |
| 19 | EditorPreviewPluginLifecycle | 禁用后切换项目不得重新注册 Preview 入口（**回归 #364**） | 插件已 Boot，选中可预览文件并注册入口 | onDisable 撤回入口后 openProject 触发项目变更 | 禁用期间入口数保持 0，不得重新注册 | P0 | ✅ 已覆盖 | `disabledPluginDoesNotReRegisterOnProjectChange` |

> 说明：全部 **19 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 5 / 5
- P1: 已覆盖 14 / 14
- P2: 已覆盖 0 / 0
- **合计: 19 / 19**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（5 条）
- **P1**: 其余功能性用例（14 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 19 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginEditorPreview
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」