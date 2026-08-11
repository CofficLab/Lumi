# 预览区域增加滑动缩放

## 目标
在促销预览（`PromoDesignerView` 的 preview 模式）底部加一个滑块缩放条，用户可在 25%–300% 之间缩放预览图。放大超过容器后可拖动查看溢出部分（不裁切）。

## 设计要点

### 缩放控件归属
- 滑块加在**插件侧** `PromoDesignerView`（用户明确说的是促销预览），不污染 `HTMLPreviewView` 的通用语义。
- 但 `HTMLPreviewView` 内部自己算 `fitScale` 并 `.scaleEffect`，插件无法从外部叠加缩放 → 需给 `HTMLPreviewView` 加一个**可选 zoomFactor 参数**（默认 1.0，向后兼容，另外两处使用 EditorPreviewPlugin / AppStoreConnectPlugin 不受影响）。

### 放大可拖动（核心难点）
当前 `previewContent`（`HTMLPreviewView.swift:52-68`）结构：
```
GeometryReader {
  WebView.frame(webViewSize).scaleEffect(fitScale).frame(geometry.size)  // ← 这个夹回容器尺寸导致裁切
}
```
放大后内容实际尺寸 = `webViewSize * fitScale * zoomFactor`。要可滚动，放大时必须：
- 最终 frame 用**缩放后的实际尺寸**（而非 `geometry.size`），ScrollView 才能算出 contentSize。
- 当 `fitScale * zoomFactor <= 1`（缩小/适应）时不需要滚动，保持填满容器；`> 1`（放大）时包 `ScrollView` 让超出部分可拖动。

## 改动文件（2 处）

### 1. `Packages/HTMLPreviewKit/Sources/HTMLPreviewView.swift`
- 新增 public init 参数：`zoomFactor: CGFloat = 1.0`（存为属性）。
- `previewContent` 改造：
  - 计算 `effectiveScale = fitScale * zoomFactor`。
  - 计算 `scaledSize = webViewSize * effectiveScale`（缩放后实际占用的点尺寸）。
  - 当 `effectiveScale <= 1`（或 zoomFactor==1）：维持现状（`scaleEffect` + `.frame(geometry.size)` 填满）。
  - 当 `effectiveScale > 1`（放大超出容器）：把 WebView 用 `scaleEffect(effectiveScale)` 后 `.frame(scaledSize)`，再包进 `ScrollView`（`[.horizontal, .vertical]`，`ShowsIndicators` 可关），让超出容器部分可拖动查看。ScrollView 自身 `.frame(geometry.size)` 填满容器。
- `body` 里 `contentSize != nil` 的 ZStack 分支（网格背景 + 预览）保持不变；ScrollView 只包 `previewContent` 内部，背景仍在 ZStack 层。
- 注意：scaleEffect 是视觉变换，hit-testing 会随缩放正确映射（WebView 内部的右键区块选中交互在放大后仍正常工作）。

### 2. `Plugins/AppStorePromoDesignerPlugin/.../Views/PromoDesignerView.swift`
- `@State private var zoomFactor: CGFloat = 1.0`
- preview 分支结构改为 `VStack(spacing: 0) { 预览区; zoomBar }`：
  - 预览区 = 现有 `HTMLPreviewView(..., zoomFactor: zoomFactor)`，用 `.frame(maxWidth/maxHeight: .infinity)` 占据剩余空间。
  - zoomBar = 一个 `HStack`：重置按钮（`1×` / 放大镜图标，点击回到 1.0）+ `Slider(value: $zoomFactor, in: 0.25...3.0)` + 百分比 `Text("\(Int(zoomFactor * 100))%").monospacedDigit()`。加 Divider 分隔，`.padding`，背景 controlBackground。
- 切换图片/任务时是否重置缩放：保持当前值（用户连续看多张图时缩放级别通常一致，不强制重置；可选后续加）。
- 仅 preview 模式显示 zoomBar；source 模式不显示。
- 用 `PromoLocalization.string` 包两个新文案："Zoom"（滑块标签/help）。

## 关键校验
- ✅ zoomFactor 默认 1.0 → 另外两处使用（EditorPreviewPlugin、AppStoreConnectPlugin）零改动、零行为变化。
- ✅ SwiftUI `ScrollView` + `scaleEffect` + 正确的 frame 尺寸是标准可滚动缩放模式。
- ✅ scaleEffect 不影响 WebView 内部 hit-testing（右键区块选中交互放大后仍可用）。
- ✅ 缩小（zoomFactor<1）时填满容器不滚动，符合"适应"预期。

## 不做的事
- 不改 EditorPreviewPlugin / AppStoreConnectPlugin（它们没要缩放；默认参数 1.0 保持原样）。
- 不持久化缩放值（刷新/切换重置为 1.0 或保持，本期默认保持 @State 生命周期）。
- 不加捏合手势（macOS 触控板 pinch），只做滑块（WKWebView 本身的 `allowsMagnification` 仍独立工作，不冲突）。

## 验证
- 编译 HTMLPreviewKit + AppStorePromoDesignerPlugin 通过。
- 现有测试通过（无 UI 自动化，靠手动）。
- 手动：预览一张图 → 拖滑块放大到 200% → 能看到放大且可拖动查看边缘 → 右键区块选中仍正常 → 拖回 100%。