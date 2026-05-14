# 📸 截图功能 TODO

> 在 AgentChatPlugin 中实现截图功能，用户点击工具栏按钮后拖拽选区，截图自动进入待发送附件区，回车发送给 LLM。

---

## 整体架构

```
用户点击截图按钮 (ChatToolbarView)
    ↓
ScreenshotState.startCapture()
    ↓
1. 先截全屏快照（ScreenCaptureKit / SCScreenshotManager）
2. 弹出全屏透明遮罩窗口（ScreenshotOverlayWindow）
    ↓
用户拖拽选择区域（鼠标事件）
    ↓
从全屏快照中裁剪选区 → PNG Data
    ↓
AttachmentsVM.handleScreenshotData(pngData)
    ↓
AttachmentPreviewView 自动渲染缩略图
    ↓
用户回车 / 点击发送
    ↓
AttachmentsVM.drainPendingImageAttachments() → [ImageAttachment] → 发给 LLM
```

### 数据流图

```
┌──────────────────────────────────────────────────────┐
│                    ChatToolbarView                     │
│  [模式] [模型] [📷上传] [✂️截图]            [发送▶]   │
│                          │                            │
│                          ▼ 点击                       │
│                ScreenshotState.startCapture()          │
└──────────────────────────┼────────────────────────────┘
                           ▼
┌──────────────────────────────────────────────────────┐
│              ScreenshotOverlayWindow                   │
│  ┌─────────────────────────────────────────────────┐ │
│  │          半透明黑色遮罩覆盖全屏                    │ │
│  │                                                 │ │
│  │     ┌──────────────────┐                        │ │
│  │     │   用户拖拽选区    │ ← 高亮矩形边框          │ │
│  │     │   320 × 240     │   显示尺寸标签           │ │
│  │     └──────────────────┘                        │ │
│  │                                                 │ │
│  │  ESC 取消 | 松开鼠标确认                          │ │
│  └─────────────────────────────────────────────────┘ │
│            mouseUp → 从全屏快照裁剪选区                 │
└──────────────────────────┼────────────────────────────┘
                           ▼
┌──────────────────────────────────────────────────────┐
│                   AttachmentsVM                        │
│  handleScreenshotData(pngData)                         │
│       ↓                                               │
│  pendingAttachments.append(.image(...))                │
└──────────────────────────┼────────────────────────────┘
                           ▼
┌──────────────────────────────────────────────────────┐
│              AttachmentPreviewView                     │
│  ┌─────┐                                              │
│  │ 📷  │ ← 截图缩略图，点击 × 可移除                   │
│  └─────┘                                              │
│              用户回车 / 点击发送                        │
│  AttachmentsVM.drainPendingImageAttachments()          │
│       → [ImageAttachment] → 随消息发给 LLM             │
└──────────────────────────────────────────────────────┘
```

---

## 文件改动清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `LumiApp/Plugins/AgentChatPlugin/ScreenshotOverlay.swift` | **新建** | 截图覆盖层窗口 + 状态管理 |
| `LumiApp/Plugins/AgentChatPlugin/Views/ChatToolbarView.swift` | **修改** | 新增截图按钮 |
| `LumiApp/Core/ViewModels/AttachmentsVM.swift` | **修改** | 新增 `handleScreenshotData(_:)` |
| `LumiApp/App.entitlements` | **修改** | 添加 `screen-capture` 权限 |

---

## TODO 任务

### 1. 新建 `ScreenshotOverlay.swift`

- [x] 1.1 创建 `ScreenshotState`（@MainActor 单例）
  - `@Published var isCapturing: Bool`
  - `startCapture()` → 截全屏快照 → 弹出 overlay 窗口
  - `endCapture()` → 关闭状态
- [x] 1.2 创建 `ScreenshotOverlayWindow`（NSWindow 子类）
  - 设置 `.borderless` 样式，`.screenSaver` 层级
  - 覆盖所有屏幕（union of NSScreen.screens）
  - 截图时机：**先截全屏快照再弹出遮罩**，避免遮罩出现在截图里
- [x] 1.3 实现鼠标事件
  - `mouseDown` → 记录起始点
  - `mouseDragged` → 更新选区矩形，刷新 SwiftUI 视图
  - `mouseUp` → 从全屏快照裁剪选区，生成 PNG Data
  - `keyDown` → ESC 取消截图
- [x] 1.4 实现 `captureAllScreens()` 静态方法
  - 使用 `SCScreenshotManager.captureImage(in:)` 截取全屏（`CGWindowListCreateImage` / `CGDisplayCreateImage` 在当前 SDK 不可用）
- [x] 1.5 实现选区裁剪
  - 坐标系转换：Cocoa 坐标（左下原点）→ CGImage 像素坐标（左上原点）
  - Y 轴翻转公式：`cropY = (imageHeight - cocoaY - selectionHeight) * scale`
  - 使用 `cgImage.cropping(to:)` 裁剪
- [x] 1.6 创建 `ScreenshotOverlayRepresentable`（SwiftUI View）
  - 半透明遮罩（选区外变暗，选区透明）
  - 选区高亮边框（accentColor，2px）
  - 尺寸标签（`320 × 240`，跟随选区底部）
- [x] 1.7 截图完成通知
  - 通过 `NotificationCenter.default.post(name: .screenshotCaptured, userInfo: ["data": pngData])`
  - 或直接注入 `AttachmentsVM` 引用

### 2. 修改 `ChatToolbarView.swift`

- [x] 2.1 新增 `screenshotButton` 计算属性
  - 图标：`scissors` 或 `viewfinder` 或 `crop`
  - 样式：与现有 `imageUploadButton` 一致（圆形 28×28，secondary 色前景）
  - 快捷键：`⌘⇧S`
- [x] 2.2 将 `screenshotButton` 加入工具栏 HStack
  - 放在 `imageUploadButton` 之后、`Spacer()` 之前
  - 当 `ScreenshotState.shared.isCapturing` 为 true 时禁用按钮
- [x] 2.3 添加本地化字符串
  - Help: `"Screenshot Region"`
  - Accessibility Label: `"Screenshot Region"`

### 3. 修改 `AttachmentsVM.swift`

- [x] 3.1 新增 `handleScreenshotData(_ data: Data)` 方法
  - 创建 `AgentPendingImageAttachment.image(id:data:mimeType:"image/png":url:)`
  - URL 使用虚拟路径：`/screenshot_{timestamp}.png`
  - 调用已有的 `add(_:)` 方法
- [x] 3.2 在 `InputView.swift` 中监听截图通知
  - `.onReceive(NotificationCenter.default.publisher(for: .screenshotCaptured))`
  - 收到 data 后调用 `agentAttachmentsVM.handleScreenshotData(data)`

### 4. 修改 `App.entitlements`

- [x] 4.1 添加屏幕录制权限
  ```xml
  <key>com.apple.security.screen-capture</key>
  <true/>
  ```

### 5. 边界情况处理

- [x] 5.1 权限检查
  - 截图前检查屏幕录制权限（尝试截 1×1 像素测试）
  - 权限被拒时提示用户去「系统设置 → 隐私与安全性 → 屏幕录制」授权
- [x] 5.2 选区过小处理
  - 选区宽或高 < 10px 时视为误操作，自动取消
- [x] 5.3 多屏幕支持
  - overlay 窗口覆盖所有屏幕（union rect）
  - 鼠标可以跨屏拖拽
- [x] 5.4 Retina 支持
  - 使用 `.bestResolution` 获取 2x 图片
  - 坐标转换时乘以 `scaleX/Y`
- [x] 5.5 截图后恢复焦点
  - overlay 关闭后将焦点还给输入框 `isInputFocused = true`

---

## 关键技术细节

### 截图时机：先截后遮

```
用户点击截图 → SCScreenshotManager.captureImage(in:)(全屏) → 弹出遮罩 → 用户拖拽 → 从快照裁剪
```

遮罩窗口不会出现在截图中。

### 坐标系转换

| 坐标系 | 原点 | Y 方向 | 用途 |
|--------|------|--------|------|
| Cocoa (NSEvent.mouseLocation) | 左下角 | 向上 | 鼠标位置 |
| CGImage 像素 | 左上角 | 向下 | 图片裁剪 |

裁剪时 Y 轴翻转：
```swift
let cropY = (imageHeight - cocoaY - selectionHeight) * scale
```

### 通知定义

```swift
extension Notification.Name {
    static let screenshotCaptured = Notification.Name("screenshotCaptured")
}
```

---

## 快捷键

| 快捷键 | 功能 |
|--------|------|
| `⌘⇧S` | 启动截图 |
| `ESC` | 取消截图 |

---

## 参考文件

- 现有附件机制：`AttachmentsVM.swift` / `AttachmentPreviewView.swift`
- 工具栏布局：`ChatToolbarView.swift`
- 插件入口：`AgentChatPlugin.swift`
- 图片附件实体：`AgentPendingImageAttachment.swift` / `ImageAttachment.swift`
- 类似的 overlay 模式：`ShowImagePlugin/ShowImageOverlay.swift`
