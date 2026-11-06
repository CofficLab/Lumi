# 场景化首次使用体验与渐进功能发现实施计划

- 日期：2026-11-05
- 状态：待实施
- 范围：macOS 主应用的消息空态、模型配置、消息发送、模型选择器，以及后续场景化功能发现
- 核心决策：不增加传统 Onboarding，不记录“首次引导已完成”，由当前任务的就绪状态驱动提示和恢复动作

## 1. 背景

Lumi 当前没有强制首启向导，正常启动后直接进入插件化主界面。消息列表空态已经支持示例问题、项目入口、项目上下文和活动信息；缺少 API Key 后，也已有消息内配置卡片。这些基础符合“在使用过程中自然发现和补全能力”的方向。

当前断点在于：全新用户看到的是一个看似可以立即对话的界面，但空态、示例建议和发送链路都不知道当前是否具备可用的 LLM。用户通常会先输入问题，应用清空草稿、创建会话、写入用户消息，随后才因缺 Key 或缺模型而失败。

本计划将第一次成功对话改成以下闭环：

```text
打开 Lumi
  -> 仍然看到消息列表空视图
  -> 空视图发现当前模型未就绪，给出唯一主要动作
  -> 用户可以直接配置，也可以先输入问题
  -> 未就绪时发送被软拦截，草稿和附件不丢失
  -> 用户在使用现场补齐供应商、Key 或本地模型
  -> 点击“继续发送”，回到原任务
  -> 第一次回答成为配置成功的反馈
```

后续功能不集中在首启介绍，而是在用户产生相应意图时出现。

## 2. 产品原则

### 2.1 状态驱动，而不是新用户标记驱动

不得引入 `isFirstLaunch`、`hasCompletedOnboarding` 或“首启引导已完成”作为本方案的核心判断。

以下情况应复用同一套恢复体验：

- 全新安装，从未配置 API Key；
- 老用户删除了当前供应商的 Key；
- 当前供应商插件被禁用或卸载；
- 当前模型被移除或选择失效；
- 本地模型被删除或尚未下载；
- 会话绑定的模型与全局模型不一致，当前发送路由未就绪。

### 2.2 只解决当前任务缺少的前提

配置提示是任务恢复，不是产品教学。一个场景只给一个主要动作，不同时展示供应商、项目、插件、主题、Skills 等多个“下一步”。

### 2.3 保留用户已经表达的意图

配置前已经输入的文字、图片、文件、折叠引用和选择的模型，不得因为补配置而丢失。配置完成后提供明确的“继续发送”，不要求是原来的逐字内容被自动保存到另一份草稿系统。

### 2.4 在使用现场恢复

优先级如下：

1. 在当前空态、输入框或模型选择器中直接恢复；
2. 通过设置深链打开准确的 Providers 页面；
3. 只有系统权限等无法控制的外部场景才跳到系统设置。

不得只显示一个会自动消失的 Toast，也不得仅抛出技术错误让用户自己寻找设置入口。

### 2.5 配置完成不触发下一段教学

第一次成功回答就是配置成功的反馈。不得紧接着弹出“现在添加项目”“现在浏览插件”等第二段引导。

### 2.6 不阻塞无关能力

未配置 LLM 只影响需要模型的任务。编辑器、终端、文件管理和其他不依赖 LLM 的功能仍可使用，不显示全局模态阻断层。

## 3. 目标与非目标

### 3.1 目标

- 新用户打开应用后，无需阅读 README 即可理解为什么暂时不能对话，以及下一步点哪里。
- 用户可以不先配置，先输入问题；发送受阻时不丢草稿、不创建空会话、不写入失败消息。
- 空态、回车发送、发送按钮和示例建议使用同一个就绪判断。
- 配置完成后可以回到并继续原任务。
- 模型选择器不再是只读列表，能够表达未配置状态并提供恢复入口。
- 项目、插件、Skills、Memory、Rules 和系统权限逐步采用“意图出现时才提示”的模式。

### 3.2 非目标

- 不制作轮播引导图、全屏蒙层、逐步高亮或功能清单。
- 不在启动时请求供应商接口验证 Key、刷新模型或检查网络。
- 不因为存在另一个可用供应商就擅自切换用户当前选择。
- 不自动下载本地模型；下载必须由用户明确点击。
- 不在配置完成后自动发起网络请求；继续发送需要用户明确点击。
- 不为所有功能一次性建立复杂的推荐引擎。
- 不改变现有消息首帧性能目标，不在 Return 关键路径增加数据库等待或网络请求。

## 4. 当前实现与差距

### 4.1 消息空态只关心会话和消息

`Packages/PluginMessageListEmpty/Sources/PluginMessageListEmpty/PluginMessageListEmptyPlugin.swift`

当前空态是否显示只取决于：

- 是否选中会话；
- 当前会话是否没有非工具消息。

`MessageListEmptyServices` 没有 `LLMManaging`，两个空态视图也没有模型未就绪分支。现有标题和示例问题会让用户误以为可以立即发送。

### 4.2 已注册供应商不等于可用供应商

`Packages/PluginLLMManager/Sources/PluginLLMManager/Managers/CustomLLMManager.swift`

内置供应商插件会注册 Provider；管理器还会回退到第一个注册 Provider。因此 `providerCount > 0` 和 `selectedModelID != nil` 都不能证明可以成功对话。

需要同时考虑：

- 实际发送路由使用哪个 Provider；
- `SuperLLMProvider.hasApiKey()`；
- 可选的 `LLMModelDownloadProviding` 及其 `downloadedModelIDs`；
- 当前模型路由是否能够解析。

### 4.3 输入先清空，消息先提交，错误后出现

`Packages/PluginConversationInput/Sources/PluginConversationInput/ViewModels/ConversationInputViewModel.swift`

当前 `send()` 在提交前清空文本和折叠块。

`Packages/PluginMessageSender/Sources/PluginMessageSender/Providers/MessageSender.swift`

当前提交链路会先解析或创建会话、写入用户消息，再由 `startTurn` 进入 AgentLoop 和 LLM 请求。未就绪检查必须发生在这些副作用之前。

### 4.4 示例建议存在独立发送入口

`Packages/ProviderPromptSuggestionExecutor/Sources/ProviderPromptSuggestionExecutor/DefaultPromptSuggestionExecutor.swift`

普通建议最终直接调用 `sendMessage`，且当前使用 `try?`。因此只改输入框 ViewModel 不能覆盖所有发送路径；消息发送器仍需要最终守门，建议执行器也需要呈现未就绪恢复动作。

### 4.5 已有可复用模式

- `ProviderAPIKeyMissingView`：缺 Key 后在消息内输入、保存并恢复；
- `SettingViewNavigation.openSettingsNotification`：从功能现场深链到指定设置项；
- `DefaultPromptSuggestionExecutor`：启用插件后继续原动作；
- `ComputerUseSystemPermissionCard`：在任务现场处理系统权限；
- Projects 空态：解释项目是可选能力，并提供 Add Project。

本方案优先复用这些模式，不建立另一套 Onboarding 框架。

## 5. 统一 LLM 就绪模型

### 5.1 在 Provider 层定义值类型

建议在 `Packages/ProviderLLMManager/Sources/ProviderLLMManager/` 增加 `LLMReadiness.swift`，由 Provider 层定义状态，Plugin 层负责计算和展示。

建议状态语义如下，具体 Associated Values 可在实现时按 Swift 6 并发要求调整：

```swift
public enum LLMReadiness: Equatable, Sendable {
    case ready(providerID: String, modelID: String?)
    case noProvider
    case missingAPIKey(providerID: String, providerName: String, modelID: String?)
    case modelNotDownloaded(providerID: String, providerName: String, modelID: String)
    case modelUnavailable(providerID: String, modelID: String?)
}
```

要求：

- `ready` 只表示本地前置条件已满足，不代表 Key 有效、网络可用或请求一定成功；
- 状态中携带供应商和模型标识，UI 可以直接生成准确的恢复动作；
- 不把技术错误文案直接写进状态，文案归各 UI 插件本地化；
- 不引入“首次启动”状态。

### 5.2 在 `LLMManaging` 提供统一查询

建议在 `Packages/ProviderLLMManager/Sources/ProviderLLMManager/LLMManaging.swift` 增加：

```swift
func readiness(modelID: LLMModelID? = nil) -> LLMReadiness
```

- 不传 `modelID` 时，使用本次发送会采用的选择和回退规则；
- 传入 `modelID` 时，用于模型选择器或指定会话路由检查；
- 生产实现放在 `CustomLLMManager`，复用现有 `resolveSelected`，不得复制一套不同的供应商回退逻辑；
- `DefaultLLMManager` 也补齐相同语义；
- 测试替身可通过协议默认实现保持编译，但生产路径不得使用永远返回 `.ready` 的兜底。

### 5.3 判定顺序

```text
1. 按现有路由规则解析 Provider 和模型
   -> 没有任何 Provider：noProvider
   -> 显式模型路由失效：modelUnavailable

2. 检查当前 Provider 的凭证
   -> hasApiKey() == false：missingAPIKey

3. 如果 Provider 实现 LLMModelDownloadProviding
   -> 当前模型不在 downloadedModelIDs：modelNotDownloaded

4. 其余情况：ready
```

实现约束：

- 保持现有 `model == nil` 的语义，不额外禁止依赖服务端默认模型的 Provider；
- 对未实现 `LLMModelDownloadProviding` 的本地 Provider，不凭空增加下载要求；
- 当前选择未就绪时，不自动切换到另一个可用 Provider；
- `hasApiKey() == true` 后仍允许真实请求暴露无效 Key、权限不足、网络和限流错误；
- 整个调用保持本地、同步、轻量，不发起异步网络预检。

### 5.4 状态变化通知

现有 `LLMManagerEvent` 已覆盖 Provider 注册、模型选择和模型池刷新，但 Key 保存、删除和本地下载状态不一定经过这些事件。

建议增加：

```swift
case readinessChanged(providerID: String)
```

并提供显式通知入口，由以下动作在完成本地写入后触发：

- 保存或删除 API Key；
- 删除已下载模型；
- 下载完成、取消或失败后需要重新评估就绪状态时。

下载中的进度仍使用现有 `downloadStatePublisher`，不要为了进度刷新重复发送高频 `readinessChanged`。只在下载结果改变“是否可用”时发送就绪事件。

空态、模型选择器和输入恢复 UI 在收到事件后重新调用 `readiness()`，不要各自缓存一份永久状态。

## 6. 交互规格

### 6.1 消息列表空视图

涉及：

- `MessageEmptyStateView.swift`
- `NoConversationSelectedView.swift`
- `MessageListGuideState` 或新增的轻量空态状态容器
- `MessageListEmptyServices.swift`

#### 就绪时

保持当前体验：

- 标题“我可以帮你做什么”；
- 示例建议；
- 有项目时展示项目上下文；
- 有真实活动时展示活动卡。

不得因为用户曾经配置过模型就永久展示“配置已完成”提示。

#### `noProvider`

主文案：

> 先连接一个模型，就可以开始对话

辅助文案：

> 启用或添加一个 LLM 供应商后，即可在这里提问。

主要按钮：`配置供应商`

动作：深链到 `com.coffic.lumi.plugin.llm-provider-settings.providers`。如果供应商插件只是被禁用，设置页应允许启用；本阶段不要求空态自己遍历插件管理器。

#### `missingAPIKey`

主文案：

> 配置 {Provider} 的 API Key 后即可开始

辅助文案：

> API Key 保存在本机钥匙串中。你也可以先输入问题，配置完成后继续发送。

主要按钮：`配置 API Key`

次要按钮：`选择其他模型`

第一阶段主要按钮可深链 Providers 设置页；内联编辑在后续阶段接入。

#### `modelNotDownloaded`

主文案：

> 下载 {Model} 后即可开始

辅助文案：

> 这是本地模型。下载完成后无需 API Key 即可使用。

主要按钮：`查看本地下载`

不得在空态出现时自动开始下载。若后续提供“下载并使用”，必须由用户明确点击，并展示已有下载视图的大小、进度、暂停和失败状态。

#### `modelUnavailable`

主文案：

> 当前模型已不可用

主要按钮：`重新选择模型`

动作：打开模型选择器，不自动清除会话历史，不自动选择另一个模型。

#### 空态内容优先级

未就绪时：

1. 用配置卡替换示例问题区域；
2. 暂不展示 Browse Plugins、活动卡等会分散首次任务注意力的内容；
3. 项目卡只在已有项目且与当前上下文直接相关时保留；
4. 不把配置卡追加成现有所有卡片之上的第四张卡。

恢复为 `.ready` 后，在同一个布局周期切回普通空态，不显示庆祝弹窗。

### 6.2 输入框与发送按钮

涉及：

- `ConversationInputCapability.swift`
- `ConversationInputViewModel.swift`
- `SendActionBarViewModel.swift`
- `ConversationInputPlugin.swift`

#### 可输入但不可直接发送

不要简单禁用输入框。发送按钮可以保持可点击，以便用户表达发送意图后得到明确恢复动作；按钮无障碍说明应能反映当前需要配置，而不是只在点击后显示技术错误。

#### 未就绪时发送的顺序

```text
Return / 点击发送 / 示例建议
  -> 捕获 readiness
  -> 如果不是 ready
       -> 保留 capability.text
       -> 保留 pendingImageAttachments / pendingFileAttachments
       -> 保留 collapsedBlocks 和光标位置
       -> 不创建会话
       -> 不写入用户消息
       -> 不调用 startTurn
       -> 展示对应的配置恢复 UI
       -> 记录“用户曾尝试发送”，用于显示“继续发送”
  -> 如果 ready
       -> 走现有快速提交链路
```

“记录用户曾尝试发送”只需是当前输入 Capability 的会话内 UI 状态，不需要持久化为新的 Onboarding 或草稿数据库字段。用户清空草稿、主动取消或切换上下文时清除该状态。

#### 配置完成后的继续发送

- 就绪状态恢复后，主要动作变为 `继续发送`；
- 点击后重新执行一次 `readiness()`，再调用现有 `send()`；
- 发送用户当前仍保留的草稿，不自动发送配置期间已经修改掉的内容；
- 不在 Key 保存成功的回调里自动发送；
- 配置失败或用户取消时，草稿仍留在输入框。

#### 两条输入路径必须一致

回车路径和发送按钮路径共用 Capability 中的预检与恢复状态，不能分别实现不同判断。

### 6.3 消息发送器最终守门

涉及：

- `Packages/PluginMessageSender/Package.swift`
- `MessageSender.swift`
- `Packages/ProviderMessageSender` 中必要的错误契约

即使输入框已经预检，`MessageSender` 也必须在 `resolveTargetConversationID` 和任何消息写入之前做最终本地检查，覆盖：

- 示例建议；
- ACP 或其他外部调用；
- 后续新增的发送入口；
- 配置状态在 UI 预检后发生变化的边界情况。

建议抛出可识别的 `LLMReadinessError`，保留具体 `LLMReadiness`。不要把所有未就绪情况转成普通 `localizedDescription` 字符串，因为 UI 需要据此打开正确恢复动作。

该检查不得改变以下现有行为：

- 已就绪消息的首帧提交路径；
- 忙碌会话的排队规则；
- 附件编码；
- 折叠块重基；
- 会话选择规则。

### 6.4 示例建议

未就绪时普通聊天示例不显示，因此正常首启不会点击一个注定失败的建议。

作为竞态和其他上下文的兜底，`DefaultPromptSuggestionExecutor` 不得继续用 `try?` 静默吞掉未就绪错误：

- 捕获未就绪错误；
- 打开对应模型配置或选择入口；
- 不创建会话或错误消息；
- 普通建议不需要持久化待发送内容，用户配置后可再次点击；
- 其他真实发送错误保持现有处理策略，不在本任务中扩展成全局错误重构。

### 6.5 模型选择器

涉及：

- `ProviderListView.swift`
- `ProviderListItem` 及其状态模型
- `ModelSelectorViewModel.swift`
- `ActionBarButton.swift`

第一阶段要求：

- 当前按钮文案不能仅凭 `selectedModelID` 就显示为可用；未就绪时可显示 `配置模型`；
- Provider 行显示 `缺少 API Key`、`待下载` 或可用状态；
- 无 Provider 时，将 `No providers available` 文本改为带 `配置供应商` 动作的空态；
- 当前 Provider 未就绪时，提供准确设置深链；
- 用户仍可浏览和选择其他 Provider，不强制锁在当前项。

第二阶段要求：

- 从现有缺 Key 消息卡中提取可复用的 Key 编辑能力，在模型选择器内完成保存；
- 不在 SwiftUI View 中直接读取 Keychain，继续由 ViewModel 或 Capability 负责；
- 保存后维持用户刚才的 Provider 和模型选择；
- 本地模型复用现有下载视图和状态，不另写一套下载管理器。

### 6.6 真实请求错误仍然按错误类型恢复

本地预检不能替代运行时错误处理：

| 运行时情况 | 恢复方式 |
| --- | --- |
| Key 无效或过期 | 复用 Key 编辑卡，允许重新输入 |
| Keychain 读取失败 | 显示本机凭证读取问题和重试，不误报为“从未配置” |
| 模型被远端移除 | 打开模型选择器，保留当前会话 |
| 网络失败或限流 | 保留现有错误详情和重试，不引导重新配置 Key |
| 本地模型文件损坏 | 打开本地下载管理，提供重新下载 |
| 无 Provider | 打开 Providers 设置 |

技术详情保持次要展开，不作为新用户首先看到的主文案。

## 7. 后续场景化功能发现

以下内容是第二阶段以后逐项实施的产品规范，不与第一次对话改造混在同一个提交中。

### 7.1 Projects

触发时机：

- 用户询问代码、文件或目录，但当前没有项目；
- 用户拖入目录或粘贴可识别的本地目录路径；
- 用户已经打开 Projects 控件。

动作示例：

> 打开项目文件夹后，我才能读取这里的代码。  
> `[选择项目]`

保留现有“项目是可选项，无项目也能聊天”的语义。不得把 Add Project 变成配置模型之后的强制第二步。

### 7.2 Plugins

触发时机：用户请求的能力需要某个未启用插件。

动作示例：

> 这个任务需要浏览器能力。  
> `[启用浏览器插件并继续]`

复用现有 `requiresEnable` 和启用后继续动作的能力。不要再首启空态优先展示 Browse Plugins。

### 7.3 Skills

触发时机：用户成功完成一次可复用的多步骤任务，并主动表达“以后也这样做”“保存这个流程”等意图。

动作示例：`将这次流程保存为 Skill`

未满足意图时不主动反复推荐。Skills 空态可补充创建入口和一句来源说明，但不在聊天首屏介绍 Skills 概念。

### 7.4 Memory

触发时机：用户明确要求记住偏好，或 Memory 工具成功保存后。

反馈示例：`已记住 · 查看 / 撤销`

Memory 空态从单纯“暂无记忆条目”改为说明：“当你让我记住偏好或项目事实时，会出现在这里。”不要诱导用户为填满列表而创建无意义记忆。

### 7.5 Agent Rules

触发时机：用户在项目内重复表达相同约定，或明确要求以后遵循某项规则。

动作示例：`保存为项目规则`

不得仅根据普通聊天内容静默写入规则；保存前必须让用户确认范围和内容。

### 7.6 系统权限和工具授权

延续现有现场授权卡，但补齐任务续接：

```text
请求权限 -> 用户去系统设置 -> 回到 Lumi -> 检测已授权 -> 继续刚才的任务
```

- 权限未确认前不自动执行；
- 回到应用后刷新权限状态；
- 提供明确的 `继续刚才的任务`；
- 授权后需要重新观察系统状态的工具，仍按各工具安全约束重新观察，不盲目复放旧操作。

### 7.7 其他静态空态

- 会话列表：`暂无对话` 增加 `开始新对话`，点击后聚焦输入框；
- Skills：区分真正为空和搜索无结果，真正为空时提供创建入口；
- Memory：说明记忆如何产生；
- RootWelcomeView：将“从 ActivityBar 选择一项”改为 `开始对话`、`打开项目` 等真实动作；
- 所有空态区分：确实为空、搜索无结果、加载失败，不能把读取失败显示成新用户空状态。

## 8. 分阶段实施任务

每个阶段独立修改、独立测试、独立提交。不要把 P0 与后续 Skills、Memory 等推荐功能捆成一个大提交。

### 阶段 1：统一就绪判断

**文件：**

- `Packages/ProviderLLMManager/Sources/ProviderLLMManager/LLMReadiness.swift`
- `Packages/ProviderLLMManager/Sources/ProviderLLMManager/LLMManaging.swift`
- `Packages/ProviderLLMManager/Sources/ProviderLLMManager/LLMManagerObservation.swift`
- `Packages/ProviderLLMManager/Sources/ProviderLLMManager/DefaultLLMManager.swift`
- `Packages/PluginLLMManager/Sources/PluginLLMManager/Managers/CustomLLMManager.swift`
- 供应商设置和 Key 保存相关 ViewModel

**工作项：**

1. 增加 `LLMReadiness` 和统一查询接口。
2. 复用现有路由解析，不复制回退规则。
3. 接入 `hasApiKey()` 和可选下载能力。
4. 增加低频 `readinessChanged` 通知。
5. Key 保存、删除和模型下载结果触发重估。
6. 确认查询不执行网络、不刷新模型、不写 UserDefaults。

**测试：**

- 无 Provider；
- 云端 Provider 无 Key；
- 云端 Provider 有 Key；
- 当前模型失效；
- 下载型 Provider 未下载、已下载；
- 非下载型本地 Provider 不被误判；
- 多 Provider 时不自动切换；
- `model == nil` 的现有合法语义不变；
- Key 保存、删除后收到一次有效就绪通知。

**命令：**

```bash
swift test --package-path Packages/ProviderLLMManager
swift test --package-path Packages/PluginLLMManager
swift test --package-path Packages/KitLLM
```

### 阶段 2：空视图按就绪状态展示恢复动作

**文件：**

- `Packages/PluginMessageListEmpty/Package.swift`
- `PluginMessageListEmptyPlugin.swift`
- `Models/MessageListEmptyServices.swift`
- `Views/Guide/MessageEmptyStateView.swift`
- `Views/Guide/NoConversationSelectedView.swift`
- 新增配置卡 View 和对应本地化字符串

**工作项：**

1. 注入 `LLMManaging`，由 Plugin 组装层解析，View 不直接从 Kernel 取服务。
2. 观察 Provider、选择、Key 和下载结果导致的就绪变化。
3. 未就绪时用配置卡替换普通示例区域。
4. 接入 Providers 设置深链和模型选择器动作。
5. 保持异步消息空态评估逻辑，不能重新引入“有消息却闪现空态”。
6. 保持现有项目和活动卡在就绪状态下的行为。

**测试：**

- 各 `LLMReadiness` 对应的标题和动作；
- 未就绪时普通 PromptSuggestion 不显示；
- 就绪后普通空态恢复；
- 未选中会话和已选空会话表现一致；
- 配置卡不会与消息列表同时占位；
- 设置 entry ID 与现有注册 ID 完全一致；
- 本地化完整性和 Accessibility Identifier。

**命令：**

```bash
swift test --package-path Packages/PluginMessageListEmpty
```

### 阶段 3：发送软拦截和草稿保留

**文件：**

- `Packages/PluginConversationInput/Package.swift`
- `ConversationInputPlugin.swift`
- `ConversationInputCapability.swift`
- `ConversationInputViewModel.swift`
- `SendActionBarViewModel.swift`
- `Packages/PluginMessageSender/Package.swift`
- `MessageSender.swift`
- `DefaultPromptSuggestionExecutor.swift`

**工作项：**

1. Capability 注入统一就绪查询和恢复 UI 状态。
2. 回车与发送按钮在清空前预检。
3. 未就绪时保留文本、附件、折叠块和光标。
4. 配置完成后显示 `继续发送`，点击后重新预检并走现有发送路径。
5. MessageSender 在创建会话和写消息之前做最终守门。
6. PromptSuggestionExecutor 不再静默吞掉未就绪错误。
7. 已就绪路径保持现有快速提交顺序，不增加 await 或数据库读取。

**测试：**

- 无 Key 时按 Return，文本不清空；
- 无 Key 时点击发送按钮，行为一致；
- 图片、文件和折叠块全部保留；
- 未创建会话、未插入用户消息、未启动 AgentLoop；
- 配置后点击继续发送，只提交一次；
- 配置期间编辑草稿，继续发送使用当前内容；
- 已就绪发送首帧路径不增加异步等待；
- 忙碌会话排队规则不变；
- 示例建议未就绪时不会出现无反馈点击；
- 外部直接调用 MessageSender 也无法绕过守门。

**命令：**

```bash
swift test --package-path Packages/PluginConversationInput
swift test --package-path Packages/PluginMessageSender
swift test --package-path Packages/ProviderMessageSender
swift test --package-path Packages/ProviderPromptSuggestionExecutor
```

### 阶段 4：模型选择器和原任务续接

**文件：**

- `Packages/PluginModelSelector` 下的 Provider 列表、ViewModel、Capability 和本地化资源
- `Packages/PluginLLMManager` 下的 Key 编辑 View 与 ViewModel
- `Packages/PluginLLMProviderSettings` 下的详情和本地下载视图
- Computer Use 权限卡及对应任务恢复逻辑

**工作项：**

1. Provider 行展示缺 Key、待下载和可用状态。
2. 无 Provider 空态提供配置动作。
3. 当前按钮在未就绪时显示配置语义。
4. 提取可复用 Key 编辑器，支持在模型选择器中保存。
5. 本地模型复用下载管理，不自动下载。
6. 权限恢复后提供继续原任务；需要新观察的工具必须重新观察。

**测试：**

- 各 Provider 状态与统一 readiness 一致；
- 保存 Key 后选择和草稿不丢失；
- 无效 Key 仍走运行时错误卡，不误显示为保存即验证成功；
- 下载完成才进入 ready；
- 取消下载不自动发送；
- 权限授予前后不会重复执行工具。

**命令：**

```bash
swift test --package-path Packages/PluginModelSelector
swift test --package-path Packages/PluginLLMManager
swift test --package-path Packages/PluginLLMProviderSettings
swift test --package-path Packages/PluginComputerUse
```

### 阶段 5：逐场景推广渐进功能发现

按以下顺序拆成独立任务，不一次性全做：

1. Projects 的无项目任务恢复；
2. Plugins 的“启用并继续”；
3. Computer Use 之外需要权限或前置配置的同类卡片；
4. Skills 的保存入口；
5. Memory 的保存反馈和空态说明；
6. Agent Rules 的确认保存入口；
7. 会话列表和 RootWelcomeView 等静态空态。

每个场景必须同时提交：触发条件、界面动作、取消行为、原任务恢复方式和测试。没有明确用户意图的推荐不进入该阶段。

## 9. 验收矩阵

### 9.1 全新用户，未配置任何 Key

- 打开应用看到消息空视图，而不是 Onboarding。
- 能看到配置模型的主要原因和主要按钮。
- 不看到点击后必然失败的普通聊天示例。
- 可以直接输入问题。
- 点击发送后文字和附件不丢失。
- 不生成会话、用户消息或错误消息。
- 配置后点击继续发送，可以进入正常请求。

### 9.2 已配置用户

- 普通空态与改造前一致。
- 发送链路不增加网络预检和数据库等待。
- 不显示任何配置卡或首次使用提示。
- 不记录或迁移 Onboarding 完成标记。

### 9.3 多供应商

- 当前供应商缺 Key 时提示当前供应商，不错误宣称“一个供应商都没有”。
- 用户可以选择其他模型。
- 应用不擅自切换当前选择。
- 切换到已配置模型后，配置卡消失。

### 9.4 本地模型

- 未下载时给出本地下载动作，不提示 API Key。
- 不自动下载。
- 下载中显示已有进度和暂停能力。
- 下载完成后才允许继续发送。
- 下载失败保留草稿并显示重试入口。

### 9.5 请求阶段异常

- 无效 Key、网络失败、限流和模型移除不会被本地 ready 状态掩盖。
- 错误卡提供与错误类型匹配的恢复动作。
- 用户原始消息和会话历史仍然保留，因为这是已实际提交后的运行时失败，不与发送前软拦截混淆。

### 9.6 非聊天能力

- 无 LLM 配置时仍能打开编辑器、终端和 Projects。
- 不出现全局模态配置阻断。
- 只有实际发起需要 LLM 的任务时才显示模型恢复动作。

## 10. UI 与集成验证要求

单元测试只能证明状态和调用关系，最终还需要在 Xcode 运行的真实 App 中走通：

1. 使用隔离的测试数据目录和测试 Keychain，构造无配置状态；
2. 验证首屏空态、配置深联、草稿保留和继续发送；
3. 验证云端 Key 和本地模型两条路径；
4. 验证设置窗口与主窗口同时打开、切换焦点后的状态刷新；
5. 验证 VoiceOver/全键盘可以到达主要动作；
6. 验证窗口缩小时配置卡不挤压输入框，不出现不可滚动内容；
7. 验证已有会话、已有项目和已有活动信息没有回归；
8. 验证 Return 首帧性能没有明显回退。

不得为了 UI 测试删除开发者真实 Keychain 项、模型缓存或生产会话数据。测试夹具必须使用隔离环境。

最终执行：

```bash
git diff --check
xcodebuild \
  -project Lumi.xcodeproj \
  -scheme Lumi \
  -configuration Debug \
  -sdk macosx \
  -disableAutomaticPackageResolution \
  -onlyUsePackageVersionsFromResolvedFile \
  build
```

## 11. 完成定义

本计划的核心部分只有在以下条件全部满足后才算完成：

- 统一就绪判断覆盖空态、输入框、发送按钮、示例建议和 MessageSender；
- 未就绪发送没有副作用，草稿完整保留；
- 配置完成后能够明确继续原任务；
- 云端和本地模型都有准确恢复路径；
- 已配置用户的现有聊天体验没有回归；
- 没有新增传统 Onboarding、首启完成标记或全局模态引导；
- 相关 Package 测试、真实 App 走查和完整 Debug 构建通过。

后续渐进功能发现按场景分别验收，不影响核心第一次对话链路先行交付。
