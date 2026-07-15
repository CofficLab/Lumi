# 插件 UI 项 order 规范

> 本规范定义 Lumi 项目中所有插件内部创建的 UI 项（`LumiChatSectionItem`、`LumiMenuBarContentItem`、`LumiRootOverlayItem`、`LumiMessageRendererItem`、`LumiChatSectionHeaderItem`、`LogoItem` 等）的 `order` 参数必须派生自 `Self.info.order`，确保插件内多个 UI 项之间、以及与其他插件的 UI 项之间的相对顺序由插件的 `info.order` 统一决定，避免顺序管理碎片化。

---

## 核心原则

**插件的 `info.order` 是其所有 UI 项排序的「单一数据源」（Single Source of Truth）。**

插件内部的每个 UI 项在注册时，其 `order` 参数必须直接或间接（`info.order + N`）派生于 `info.order`，不得硬编码独立数字字面量。

---

## 规则一：单 UI 项插件 —— 直接使用 `info.order`

如果插件只创建 **一个** UI 项，则 `order` 参数直接使用 `info.order`。

### ✅ 正确

```swift
LumiChatSectionItem(id: info.id, order: info.order) {
    MyView()
}
```

```swift
LumiRootOverlayItem(id: info.id, order: info.order) { content in
    MyOverlay(content: content)
}
```

### ❌ 错误

```swift
// ❌ 硬编码独立数字，与 info.order 脱节
LumiChatSectionItem(id: info.id, order: 77) {
    MyView()
}
```

```swift
// ❌ 即使值恰好等于 info.order，也是风格违规
LumiChatSectionItem(id: info.id, order: 96) {  // info.order == 96
    MyView()
}
```

---

## 规则二：多 UI 项插件 —— 使用 `info.order + 基数`

如果插件需要创建 **多个** UI 项（例如同一插件贡献多个 section / toolbar / overlay），各 UI 项之间使用 `info.order + 固定基数` 的形式区分，基数通常为 10 的倍数（便于将来在两项之间插入新项）。

### ✅ 正确

```swift
// 插件 info.order = 82，第一个 toolbar item
LumiChatSectionToolbarBarItem(id: info.id, order: info.order) {
    ...
}

// 插件 info.order = 82，第二个 toolbar item（在同一 plugin 内留位）
LumiChatSectionToolbarBarItem(id: "\(info.id).tps", order: info.order + 1) {
    ...
}
```

```swift
// 消息渲染器优先级示例（order 高 = 优先匹配）
// 插件 info.order = 10

LumiMessageRendererItem(id: "turn-completed", order: info.order + 320)  // 330
LumiMessageRendererItem(id: "status-message", order: info.order + 310)    // 320
LumiMessageRendererItem(id: "error-message",  order: info.order + 290)   // 300
LumiMessageRendererItem(id: "tool-message",   order: info.order + 240)   // 250
LumiMessageRendererItem(id: "user-message",   order: info.order + 190)   // 200
LumiMessageRendererItem(id: "assistant-msg", order: info.order + 180)   // 190
LumiMessageRendererItem(id: "system-message", order: info.order + 150)  // 160
LumiMessageRendererItem(id: "default-markdown", order: info.order - 10) // 0
```

### ❌ 错误

```swift
// ❌ 硬编码独立数字，与 info.order 无派生关系
LumiMessageRendererItem(id: "error-message", order: 300) {
    ...
}
```

---

## 规则三：强制置顶 / 置底 —— 使用语义化固定值

如果某个 UI 项需要**强制**排到所有其他项之前或之后，不受 `info.order` 影响，使用语义化常量并加注释说明。

### ✅ 正确

```swift
// 强制置底：固定为 Int.max，与 info.order 解耦，注释说明语义
// 排到菜单栏 popup 列表最末
LumiMenuBarPopupItem(id: "\(info.id).popup", order: .max) {
    MyPopupView()
}
```

### ❌ 错误

```swift
// ❌ -1 是魔法数字，语义不明确
LumiMenuBarPopupItem(id: "\(info.id).popup", order: -1) {
    MyPopupView()
}
```

---

## 规则四：`LumiPluginInfo` 构造时的 `order` 参数除外

每个插件的 `info` 定义中，`order:` 参数写具体数字字面量是**合理的**，因为 `LumiPluginInfo` 本身就是插件的排序基准值。

```swift
// ✅ 正确：info 构造时写具体数字，这是插件级别的排序基准
public static let info = LumiPluginInfo(
    id: "com.coffic.lumi.plugin.example",
    displayName: "Example",
    description: "...",
    order: 82  // 插件级别基准值
)
```

---

## 常见受影响的 UI Item 类型

| UI Item 类型 | 说明 |
|---|---|
| `LumiChatSectionItem` | Chat 区域的 section 块 |
| `LumiChatSectionHeaderItem` | Chat section 的 header |
| `LumiChatSectionToolbarBarItem` | Chat section 的 toolbar 条目 |
| `LumiMenuBarContentItem` | 菜单栏内容项 |
| `LumiMenuBarPopupItem` | 菜单栏弹出项 |
| `LumiRootOverlayItem` | 全屏浮层项 |
| `LumiMessageRendererItem` | 消息渲染器条目 |
| `LumiEditorPanelItem` | Editor panel 项 |
| `LumiStatusBarItem` | 状态栏项 |
| `LogoItem` | Logo 项 |

---

## 违反规范的历史案例（已修复）

以下案例在本次整改中已修复，作为反例参考：

| 案例文件 | 违规描述 | 修复方式 |
|---|---|---|
| `IdleTimePlugin.swift:51` | `LumiRootOverlayItem(order: 96)` 硬编码，巧合等于 `info.order` | 改为 `order: info.order` |
| `ConversationTitlePlugin.swift:41,48` | `LumiChatSectionHeaderItem(order: 81)` 硬编码，不等于 `info.order(77)` | 改为 `order: info.order + 4` |
| `LogoCofficPlugin.swift:18` | `LogoItem(order: 100)` 硬编码，`info.order` 也是 100（巧合相同） | 改为 `order: info.order` |
| `LogoSmartLightPlugin.swift:18` | `LogoItem(order: 200)` 硬编码，`info.order` 也是 200（巧合相同） | 改为 `order: info.order` |
| `CaffeinatePlugin.swift:37` | `LumiMenuBarPopupItem(order: -1)` 魔法数字 | 改为 `order: .max` 并加注释 |
| `MessageRendererPlugin.swift` | 8 个 renderer 全部硬编码 `330/320/300/250/200/190/160/0` | 改为 `info.order + delta` |
| LLM Provider Renderers（30+ 处） | 各 Provider 错误渲染器硬编码 `210/220/230/240/250` 等 | 改为 `info.order + 200/210/220/230/240` |
