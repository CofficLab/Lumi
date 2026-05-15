# Screenshot Hardening TODO

目标：在现有聊天截图附件功能基础上，提升多屏幕、错误反馈和截图准备阶段的健壮性。

## 任务

- [x] 1. 明确截图状态
  - [x] 增加 `isPreparing` 状态，区分“正在获取屏幕快照”和“正在拖拽选区”
  - [x] 工具栏按钮在准备阶段显示进度状态

- [x] 2. 增强错误反馈
  - [x] 截图快照失败时显示可理解的错误提示
  - [x] 无屏幕、无截图数据、权限异常分别给出明确处理
  - [x] 保留权限拒绝时跳转系统设置的入口

- [x] 3. 优化多屏幕覆盖层
  - [x] 从单个 union overlay window 改为每个 `NSScreen` 一个 overlay window
  - [x] 鼠标事件统一使用全局屏幕坐标
  - [x] 各屏幕只绘制本屏与全局选区的交集
  - [x] 保持跨屏拖拽截图可用

- [x] 4. 坐标与裁剪稳健性
  - [x] 保持 ScreenCaptureKit 返回图像与 display-space points 的比例映射
  - [x] 对裁剪 rect 做边界裁切，避免越界
  - [x] 记录混合 Retina / 非 Retina 多屏场景仍需实机 QA

- [x] 5. 验证
  - [x] `ScreenshotOverlay.swift` 独立 typecheck 通过
  - [x] 本地化字符串 JSON 校验通过
  - [x] 全量 build 尽量运行；若失败，记录是否被无关工作区修改阻塞

## 验证记录

- `xcrun swiftc -typecheck LumiApp/Plugins/AgentChatPlugin/ScreenshotOverlay.swift -target arm64-apple-macos15.5 -sdk $(xcrun --sdk macosx --show-sdk-path)` 通过。
- `jq empty LumiApp/Plugins/AgentChatPlugin/AgentChat.xcstrings` 通过。
- `xcodebuild -project Lumi.xcodeproj -scheme Lumi -configuration Debug -destination 'platform=macOS' build` 已运行；当前被无关工作区修改阻塞：`LumiApp/Plugins/EditorPreviewV2Plugin/Services/EditorRemoteHotPreviewService.swift:124` 的 main actor isolation 编译错误。

## QA 清单

- [ ] 单屏 Retina 截图
- [ ] 外接屏截图
- [ ] 左右排列多屏截图
- [ ] 上下排列多屏截图
- [ ] 跨屏拖拽截图
- [ ] 过小选区自动取消
- [ ] ESC 取消
- [ ] 未授权屏幕录制权限
- [ ] 截图后附件预览出现并可发送
