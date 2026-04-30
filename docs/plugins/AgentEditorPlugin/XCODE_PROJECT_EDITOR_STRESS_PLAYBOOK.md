# Xcode Project Editor Stress Playbook

## 目标

为 `AgentEditorPlugin` 的 Xcode 工程编辑链路提供一套固定的压力回归流程，覆盖：

1. 大型工程打开与上下文解析
2. 连续 scheme 切换
3. 并发 build context 请求
4. 索引状态可见性与恢复

## 样本要求

- 大型 workspace：100+ targets，1000+ source files
- 中型 app workspace：包含 app target、test target、extension target
- 混合工程：`Package.swift` + `.xcodeproj` + `xcconfig` + `plist`

## 执行前准备

- 清理上一次 `buildServer.json`
- 记录机器型号、macOS 版本、Xcode 版本
- 记录 `xcode-build-server` 版本
- 确认目标工程能被 Xcode 正常打开

## 场景 1：冷启动打开大型工程

1. 从未打开状态启动 Lumi。
2. 打开目标 `.xcworkspace` 或 `.xcodeproj`。
3. 记录以下时间点：
   - 项目解析开始
   - build context 进入 `available`
   - LSP 索引开始
   - LSP 索引结束
4. 验证：
   - 状态栏连续显示 `resolving -> indexing -> ready`
   - 未出现空白 scheme / destination
   - 未出现重复 toast 或错误卡死

## 场景 2：快速 scheme 切换

1. 在同一 workspace 内准备至少 3 个有效 scheme。
2. 连续切换 10 次，顺序固定为 `A -> B -> C -> A ...`。
3. 每次切换后验证：
   - `activeScheme`、`activeConfiguration`、`activeDestination` 同步刷新
   - build context 状态进入重新解析
   - 旧 diagnostics 不长期残留
   - 后续 definition / references 请求不再使用旧 scheme 上下文

## 场景 3：并发文件上下文请求

1. 同时打开 5-10 个属于不同 target 的 Swift 文件。
2. 在每个文件上触发至少一种语义请求：
   - definition
   - references
   - document symbols
3. 验证：
   - 不出现崩溃、死锁、持续空结果
   - build settings cache 不发生错误复用
   - 文件 target 归属与 active scheme 一致

## 场景 4：工程辅助文件工作流

1. 在同一项目中打开：
   - `Package.swift`
   - `.xcconfig`
   - `Info.plist`
   - `.entitlements`
   - `project.pbxproj`
2. 验证：
   - `Package.swift` URL 可 Cmd+Click，版本 requirement 可 hover
   - `xcconfig` include 可跳转
   - `plist` / `entitlements` key 有 hover / completion
   - `pbxproj` 保存前确认、冲突提示可见

## 场景 5：外部修改恢复

1. 同时用 Xcode 打开同一工程。
2. 在 Xcode 中修改 `project.pbxproj` 或 `Info.plist`。
3. 回到 Lumi 后验证：
   - 外部修改被检测
   - `pbxproj` 冲突提示文案区分 Xcode / Lumi 版本
   - 保存链路不会静默覆盖磁盘版本

## 结果记录模板

- 工程名称：
- 机器 / 系统：
- Xcode / sourcekit-lsp / xcode-build-server 版本：
- 冷启动 ready 时间：
- 10 次 scheme 切换成功率：
- 并发语义请求异常数：
- 辅助文件交互异常数：
- 备注：

## 失败分级

- P0：崩溃、卡死、数据丢失、错误覆盖工程文件
- P1：跨文件语义不可用、scheme 切换后长期错误上下文
- P2：状态提示缺失、短暂闪烁、个别辅助文件交互失效
