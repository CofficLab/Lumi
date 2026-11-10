# PluginMessageListZCode

V4（ZCode 风格）消息列表插件。

## 定位

Lumi 的消息列表有四档呈现，各自是**独立 Package**、独立插件：

| 档位 | Package | 插件 ID |
|---|---|---|
| V1 简洁 | `PluginMessageListBrief` | `com.coffic.lumi.plugin.message-list.brief` |
| V2 标准 | `PluginMessageListStandard` | `com.coffic.lumi.plugin.message-list.standard` |
| V3 详细 | `PluginMessageListDetailed` | `com.coffic.lumi.plugin.message-list.detailed` |
| **V4 ZCode** | **`PluginMessageListZCode`** | `com.coffic.lumi.plugin.message-list.zcode` |

四者共享 `message-list` exclusiveGroup 槽位，**同一时刻只有一个激活**
（由 `ResponseVerbosity` 决定，见 `ProviderConversation`）。

## 与其它档位的关系

- **不依赖任何其它消息列表包**（插件不得依赖插件）。
- 通用设施（Provider 层协议、渲染分发、滚动跟踪、分页、首屏门禁）
  在本包内**各自实现一份**，不与 V1–V3 共享代码。
  代价是存在两份近似实现，收益是各档位可以独立演进、独立发布。
- 渲染层（`PluginMessageRenderer`）是**共用**的：`.zcode` 只是同一个
  renderer 内的分支，第三方 renderer 的注册顺序、`order` 值与分发逻辑
  完全不变。

## 主要能力

- **轮次组织**：消息按「轮」而非「行」投影，一轮内含用户气泡、
  助手正文、工作历史与轮尾操作栏。
- **用户气泡**：右对齐、有表面色、长文可折叠展开、附件独立成行。
- **助手正文**：无气泡、无头像、无名称，占满内容列。
- **轮尾操作栏**：整轮只出现一次，挂在轮尾助手正文上。
- **滚动所有权**：只有真实用户滚动能改变 `following`；
  程序化贴底、文档变高、resize 都不得把用户拽回底部。
- **回到底部按钮**：脱离跟随时出现，点击恢复跟随。

## 目录结构

```
Sources/PluginMessageListZCode/
├── PluginMessageListZCodePlugin.swift   插件入口
├── ZCodeVerbosityObservationBox.swift   槽位激活观察
├── Capabilities/                        窄能力协议（Provider 收窄）
├── Models/                              ZCodeTurn、MessageListServices 等
├── Observers/                           开发者模式观察
├── Services/                            轮次投影、滚动 reducer、来源分类等
├── ViewModels/                          ListV4ViewModel
└── Views/                               ListV4View、ZCodeTurnView 等
```

## 相关文档

- 评审与审计：`docs/plans/artifacts/zcode-message-list-v4/AUDIT.md`
- 截图矩阵清单：`docs/plans/artifacts/zcode-message-list-v4/README.md`
