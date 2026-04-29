# AgentEditorPlugin VS Code 体验验证手册

## 目的

这份手册定义了 `AgentEditorPlugin` 在结构性变更后的可重复验证场景。它不再只服务于“内核是否稳定”，而是同时服务于以下目标：

1. 编辑器内核是否稳定
2. 工作台 UI 与交互是否连续
3. 扩展贡献点接入后是否保持一致体验
4. 整体用户体验是否继续朝 VS Code 靠拢

它刻意采用“命令 + 场景”的形式，方便团队在重构前后执行同一套检查。

## 前置条件

- 使用 `Lumi` scheme。
- 回归或测试运行时，默认优先使用 `DISABLE_SWIFTLINT=1`，除非本次就是要检查 SwiftLint package plugin 的行为。
- 验证偏 UI 的场景时，请在 macOS 上以全新启动的 app 进行。

## 核心回归命令

### 全量回归

```bash
DISABLE_SWIFTLINT=1 xcodebuild test \
  -project Lumi.xcodeproj \
  -scheme Lumi \
  -destination 'platform=macOS' \
  -parallel-testing-enabled NO
```

### 内核聚焦测试组

```bash
DISABLE_SWIFTLINT=1 xcodebuild test \
  -project Lumi.xcodeproj \
  -scheme Lumi \
  -destination 'platform=macOS' \
  -parallel-testing-enabled NO \
  -only-testing:LumiTests/EditorSessionTests \
  -only-testing:LumiTests/EditorSessionStoreTests \
  -only-testing:LumiTests/EditorSelectionStabilityTests \
  -only-testing:LumiTests/EditorUndoManagerTests
```

### 运行时 / 大文件 / viewport 测试组

```bash
DISABLE_SWIFTLINT=1 xcodebuild test \
  -project Lumi.xcodeproj \
  -scheme Lumi \
  -destination 'platform=macOS' \
  -parallel-testing-enabled NO \
  -only-testing:LumiTests/LargeFileModeTests \
  -only-testing:LumiTests/LSPViewportSchedulerTests \
  -only-testing:LumiTests/EditorRuntimeModeControllerTests \
  -only-testing:LumiTests/EditorOverlayControllerTests
```

### 输入 / 事务 / 多光标测试组

```bash
DISABLE_SWIFTLINT=1 xcodebuild test \
  -project Lumi.xcodeproj \
  -scheme Lumi \
  -destination 'platform=macOS' \
  -parallel-testing-enabled NO \
  -only-testing:LumiTests/EditorInputCommandControllerTests \
  -only-testing:LumiTests/EditorTextInputControllerTests \
  -only-testing:LumiTests/EditorTransactionControllerTests \
  -only-testing:LumiTests/EditorMultiCursorWorkflowControllerTests
```

### Bridge 层测试组

```bash
DISABLE_SWIFTLINT=1 xcodebuild test \
  -project Lumi.xcodeproj \
  -scheme Lumi \
  -destination 'platform=macOS' \
  -parallel-testing-enabled NO \
  -only-testing:LumiTests/TextViewBridgeTests \
  -only-testing:LumiTests/SourceEditorAdapterTests \
  -only-testing:LumiTests/SourceEditorViewBridgeTests
```

## 人工压力场景

### 1. 大文件打开延迟

- 打开一个小型源码文件 `< 1k 行`。
- 打开一个中型源码文件 `10k-30k 行`。
- 打开一个大型源码文件 `100k+ 行`，或能触发截断 / 大文件模式的文件。
- 记录：
  - 首次渲染时间
  - 光标可编辑时间
  - minimap / folding / highlighting 是否按预期被 gating

### 2. 超长行保护

- 打开一个至少包含一行超长行的文件。
- 确认 syntax / highlight 的 gating 行为变化符合预期。
- 在超长行附近滚动，确认 hover / code action / signature overlay 不会频繁抖动或卡住。

### 3. 多 session / 恢复

- 至少打开 5 个 editor tab。
- 在其中 3 个 tab 里设置不同的 selection / scroll position / find query。
- 关闭并重新打开 session，或主动触发 restore 路径。
- 验证：
  - selection restore
  - scroll restore
  - 每个 session 独立的 find state
  - reference / problem panel 状态隔离

### 4. 多 split workbench

- 创建 2 路和 3 路 split。
- 在不同 split leaf 之间切换焦点。
- 分别从 leaf 和靠近 ancestor 的路径触发 unsplit。
- 验证：
  - active editor 是否正确
  - 保留下来的 leaf 中 session 是否仍然完整
  - dirty state 没有丢失

### 5. 输入压力

- 在普通文件里持续重复输入 `10+ 秒`。
- 在重复 token 上执行多光标 `add-next / add-all` 流程。
- 连续执行 line move / copy / comment 命令。
- 验证：
  - 不会丢光标
  - 不会产生重复编辑
  - undo / redo 能保持 canonical selections

### 6. LSP 稳定性

- 快速连续触发 hover、definition、references、rename、code action、signature help。
- 在慢请求返回前移动光标或切换文件。
- 验证过期响应会被忽略，overlay / panel 只反映当前 session 的上下文。

### 7. 工作台 UI 连续性

- 打开 breadcrumb、outline、open editors、problems、references 等 UI 入口。
- 在 tab、split、底部 panel、侧边 panel 之间切换焦点。
- 触发 definition、references、problem 跳转后再返回。
- 验证：
  - 焦点转移自然
  - active editor / active group 不错乱
  - 面板内容与当前 session 保持一致

### 8. 扩展贡献点一致性

- 安装或启用至少一组 editor 扩展贡献（如 highlight / code action / command / panel）。
- 验证其入口是否同时出现在正确的 UI 中，例如 command palette、context menu、overlay、panel 或状态栏。
- 切换文件、切换语言、切换 split，确认贡献项 enablement 正确变化。
- 验证：
  - 不需要写特判 UI 逻辑也能稳定呈现
  - 扩展贡献在不同 session / group 中不会串态
  - 扩展禁用或不可用时 UI 能自然退场

## 记录模板

每次执行请记录：

- commit 或 branch
- macOS 版本 / 硬件
- 场景名称
- 观察到的延迟或定性结果
- 是否存在回归：yes / no
- 如果是 UI 特定问题，补充备注 / 截图

## 升级规则

如果结构性重构修改了 bridge、runtime gating、session restore、transaction flow，或明显影响 UI / 扩展贡献链，请执行：

1. bridge-layer suites
2. kernel-focused suites
3. 至少手动执行场景 3、4、5
4. 如果改动涉及工作台 UI 或扩展入口，再手动执行场景 7、8
