# Auto 模型路由设计文档

> **状态**: 设计中  
> **作者**: Lumi Team  
> **日期**: 2025-07  
> **关联**: [LLMProviderKit 计划](llm-provider-kit-plan.md)

---

## 1. 背景与动机

当前 Lumi 用户在与 LLM 聊天时，需要手动选择供应商和模型。随着支持的模型越来越多（Anthropic、OpenAI、Google、DeepSeek、本地 MLX 等），用户面临「选择困难」的问题：

- **不知道哪个模型适合当前任务**
- **不了解各模型的性能差异**
- **切换成本高**：需要在模型选择器中浏览多个供应商

Cursor 的 **Auto 模式** 提供了一个很好的参考：用户选择 "Auto" 后，系统自动根据消息内容、任务类型和历史表现选择最合适的模型。

本文档设计 Lumi 的 Auto 模型路由方案。

---

## 2. 设计目标

| 目标 | 说明 |
|------|------|
| **零配置** | 用户只需选择 "Auto"，无需了解模型细节 |
| **透明可解释** | 向用户展示选择了哪个模型以及原因 |
| **渐进式** | 分阶段实现，Phase 1 最小可用 |
| **可回退** | 用户随时可关闭 Auto，手动选择模型 |
| **复用现有架构** | 基于 SendPipeline、ModelPerformanceStats 等已有组件 |
| **可学习** | 后续可基于用户偏好自动调整路由策略 |

---

## 3. 核心设计

### 3.1 路由流程

```
用户消息 → [信号采集] → [候选过滤] → [评分排序] → [选择最佳] → 发送请求
```

### 3.2 路由信号（Routing Signals）

| 信号 | 来源 | 类型 | 说明 |
|------|------|------|------|
| `hasImages` | `ChatMessage.images` | 布尔 | 是否有图片附件 → 需要 Vision 能力 |
| `chatMode` | `LLMVM.chatMode` | 枚举 | Chat vs Build → 是否需要 Tool Use |
| `messageLength` | `message.content.count` | 数值 | 消息长度 → 简单 vs 复杂 |
| `allowsTools` | `chatMode.allowsTools` | 布尔 | Build 模式需要 Tool 支持 |
| `historicalStats` | `ModelPerformanceStats` | 结构体 | 历史 TPS、延迟、成功率、使用次数 |
| `modelCapabilities` | `LLMProviderInfo.modelCapabilities` | 字典 | 模型能力声明（Vision/Tools） |
| `apiKeyConfigured` | `APIKeyStore` | 布尔 | 供应商 API Key 是否已配置 |

### 3.3 路由规则

#### 硬过滤（必须满足，否则直接排除）

| 规则 | 条件 | 说明 |
|------|------|------|
| **能力约束** | `hasImages → supportsVision` | 有图片时必须选支持视觉的模型 |
| **能力约束** | `allowsTools → supportsTools` | Build 模式必须选支持工具的模型 |
| **可用性** | API Key 已配置 | 过滤掉未配置的供应商 |
| **可用性** | 模型存在 | 模型名在 `availableModels` 列表中 |

#### 软评分（越高越优先）

| 因素 | 权重 | 说明 |
|------|------|------|
| 模型强度 | 0-30 分 | 基于模型名称的启发式评分 |
| 历史 TPS | 0-20 分 | 平均输出速度越快分越高 |
| 历史可靠性 | 0-10 分 | 使用次数越多越可靠 |
| 复杂度匹配 | 0-10 分 | 简单任务给轻量模型加分 |
| 新模型探索 | 15 分 | 无历史数据的模型给中等偏上分数 |

### 3.4 模型强度评分表

基于业界公认的能力排名，对主流模型给出基础强度评分：

| 分值 | 模型系列 | 代表模型 |
|------|---------|---------|
| 30 | 旗舰级 | Claude Opus、OpenAI o3/o4、Gemini 2.5 Pro |
| 25 | 高性能 | Claude Sonnet、GPT-4o、Gemini Pro |
| 20 | 中等 | DeepSeek V3、GPT-4 |
| 15 | 轻量快速 | Claude Haiku、GPT-4o-mini、Gemini Flash |
| 12-22 | 本地模型 | 按参数量分（7B→12, 13B→16, 70B→22） |

---

## 4. 架构设计

### 4.1 新增文件

```
LumiApp/Core/Services/LLM/
  ├── AutoModelRouter.swift           # 路由引擎（核心）
  └── AutoModelScoring.swift          # 评分策略（可替换）

LumiApp/Plugins/ChatInputPlugin/
  └── Middlewares/
      └── AutoModelMiddleware.swift    # SendPipeline 中间件
```

### 4.2 核心类型定义

#### AutoModelCandidate — 路由候选

```swift
/// 路由候选结果
struct AutoModelCandidate: Identifiable {
    let id: String                // "providerId|modelName"
    let providerId: String
    let model: String
    let score: Double             // 综合评分，越高越好
    let reason: String            // 路由原因（UI 展示用）
}
```

#### AutoModelRouter — 路由引擎

```swift
/// Auto 模型路由引擎
///
/// 根据消息内容、聊天模式、历史性能等信号，
/// 从所有已注册的供应商和模型中选择最佳模型。
@MainActor
final class AutoModelRouter {
    let llmVM: LLMVM
    let chatHistoryService: ChatHistoryService

    /// 为给定上下文选择最佳模型
    func selectModel(
        for message: ChatMessage,
        chatMode: ChatMode
    ) -> AutoModelCandidate?

    /// 对所有可用模型进行评分排序（用于调试和 UI 展示）
    func rankCandidates(
        message: ChatMessage,
        chatMode: ChatMode
    ) -> [AutoModelCandidate]
}
```

#### AutoModelMiddleware — 管线中间件

```swift
/// Auto 模型路由中间件
///
/// 在 SendPipeline 中拦截请求，
/// 当 Auto 模式开启时自动选择模型。
@MainActor
final class AutoModelMiddleware: SuperSendMiddleware {
    let id = "auto-model-router"
    let order = 10  // 早期执行

    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async
}
```

### 4.3 现有文件改动

| 文件 | 改动 | 说明 |
|------|------|------|
| `LLMVM.swift` | 新增 `isAutoMode`、`lastAutoSelected*` 属性 | Auto 模式状态管理 |
| `LLMRequester.swift` | `request()` 方法支持 Auto 配置获取 | 根据路由结果构建 LLMConfig |
| `ModelSelectorTab.swift` | 新增 `.auto` tab | 模型选择器中的 Auto 选项 |
| `ModelSelectorView.swift` | 新增 Auto Tab 视图 | 展示推荐模型和原因 |
| `ChatToolbarView.swift` | Auto 模式 UI 状态 | 显示 "Auto" 或 "Auto · Model" |
| `Conversation.swift` | 无需改动 | Auto 不持久化到对话偏好 |

### 4.4 数据流

```
┌──────────────────────────────────────────────────────────────┐
│  用户点击发送                                                  │
│       │                                                      │
│       ▼                                                      │
│  InputQueueVM.enqueueText()                                  │
│       │                                                      │
│       ▼                                                      │
│  SendPipeline.run()                                          │
│       │                                                      │
│       ▼                                                      │
│  ┌──────────────────────────────────┐                        │
│  │ AutoModelMiddleware (order: 10)   │ ← Auto 模式核心入口     │
│  │                                   │                        │
│  │  1. 检查 isAutoMode               │                        │
│  │  2. 调用 router.selectModel()     │                        │
│  │     ├─ 硬过滤（能力/可用性）       │                        │
│  │     ├─ 软评分（强度/历史/匹配）    │                        │
│  │     └─ 排序取最优                  │                        │
│  │  3. 写入路由结果到 LLMVM          │                        │
│  │     ├─ lastAutoSelectedProvider    │                        │
│  │     ├─ lastAutoSelectedModel       │                        │
│  │     └─ lastAutoSelectedReason      │                        │
│  └──────────────────────────────────┘                        │
│       │                                                      │
│       ▼                                                      │
│  ┌──────────────────────────────────┐                        │
│  │ 其他 Middleware...                │                        │
│  └──────────────────────────────────┘                        │
│       │                                                      │
│       ▼                                                      │
│  LLMRequester.request()                                      │
│       │                                                      │
│       ├─ isAutoMode?                                         │
│       │   ├─ YES → 从 LLMVM.lastAutoSelected* 获取 config    │
│       │   └─ NO  → 从 LLMVM 手动选择获取 config              │
│       │                                                      │
│       ▼                                                      │
│  LLMService.sendStreamingMessage()                           │
│       │                                                      │
│       ▼                                                      │
│  流式响应 → statusVM → UI 更新                                │
└──────────────────────────────────────────────────────────────┘
```

---

## 5. 评分算法详解

### 5.1 综合评分公式

```
totalScore = capabilityBonus + strengthScore + tpsScore + reliabilityScore + complexityMatch + explorationBonus
```

各分项计算方式：

#### capabilityBonus（能力加分）

| 条件 | 加分 |
|------|------|
| `supportsVision == true` | +5 |
| `supportsTools == true` | +5 |

#### strengthScore（模型强度，0-30）

基于模型名称的启发式评分，参考 [3.4 模型强度评分表](#34-模型强度评分表)。

#### tpsScore（历史速度，0-20）

```
tpsScore = min(avgTPS / 50.0, 1.0) × 20
```

归一化到 0-20 分。50 TPS 作为满分基准（可根据实际数据调整）。

#### reliabilityScore（可靠性，0-10）

```
reliabilityScore = min(sampleCount / 50.0, 1.0) × 10
```

使用次数越多，可靠性越高。50 次作为满分基准。

#### complexityMatch（复杂度匹配，0-10）

```
if chatMode == .build:
    complexityMatch = strengthScore × 0.3  // 强模型加分
elif messageLength < 200:
    if isLightweightModel: complexityMatch = 10
    else: complexityMatch = 0
else:
    complexityMatch = strengthScore × 0.1
```

#### explorationBonus（探索奖励）

```
if 无历史数据:
    explorationBonus = 15  // 新模型给中等偏上分数，鼓励尝试
else:
    explorationBonus = 0
```

### 5.2 轻量模型判定

以下模型被视为轻量模型，适合简单对话：

- Claude Haiku 系列
- GPT-4o-mini / GPT-3.5 系列
- Gemini Flash 系列
- 本地 7B/8B 参数模型

---

## 6. UI 设计

### 6.1 工具栏展示

```
手动模式：  [🔨 Build] [🌐 Anthropic · Claude Sonnet 4] [📷] [✂️]  [📤]
Auto 模式： [🔨 Build] [✨ Auto · Claude Sonnet 4    ] [📷] [✂️]  [📤]
```

- Auto 模式使用 `wand.and.stars` 图标（✨），区别于手动的 `globe`（🌐）
- 显示实际选择的模型名称，让用户知道 Auto 选了什么

### 6.2 模型选择器新增 Auto Tab

```
┌──────────────┬─────────────────────────────────────┐
│              │ 🔍 搜索模型...                  [✕] │
│  ✨ Auto     │─────────────────────────────────────│
│  📍 Current  │                                     │
│  🕐 Frequent │  🏆 推荐模型                         │
│  ⚡ Fast     │                                     │
│  📦 All      │  ┌─────────────────────────────────┐│
│              │  │ ✨ Claude Sonnet 4              ││
│  Anthropic   │  │ Anthropic · Score: 92           ││
│  OpenAI      │  │ 原因: 支持工具、TPS 高、历史可靠  ││
│  Google      │  ├─────────────────────────────────┤│
│  DeepSeek    │  │ 🥈 GPT-4o                       ││
│  MLX         │  │ OpenAI · Score: 88              ││
│              │  │ 原因: 支持工具、模型强度高         ││
│              │  ├─────────────────────────────────┤│
│              │  │ 🥉 Gemini 2.5 Flash             ││
│              │  │ Google · Score: 75              ││
│              │  │ 原因: 轻量快速、适合简单任务       ││
│              │  └─────────────────────────────────┘│
└──────────────┴─────────────────────────────────────┘
```

### 6.3 Auto 开关

在模型选择器的 Auto Tab 中，提供 Auto 模式开关：

- **开启 Auto**：选择 "Auto" 后自动路由
- **关闭 Auto**：回到手动选择模式

---

## 7. 渐进式实现路线

### Phase 1：基础路由（最小可用）⭐⭐

**目标**：Auto 能用，基于简单规则选择模型

- [ ] 新增 `AutoModelRouter`（能力过滤 + 模型强度评分）
- [ ] 新增 `AutoModelMiddleware`
- [ ] `LLMVM` 新增 `isAutoMode` 状态
- [ ] `LLMRequester` 支持 Auto 配置获取
- [ ] `ModelSelectorTab` 新增 `.auto`
- [ ] `ChatToolbarView` 支持 Auto UI 状态

**预计代码量**：~300 行核心逻辑 + ~100 行 UI 改动

### Phase 2：历史数据驱动 ⭐⭐⭐

**目标**：利用已有的 `ModelPerformanceStats` 数据优化路由

- [ ] 路由引擎接入 `ChatHistoryService.getModelDetailedStats()`
- [ ] TPS 和可靠性评分生效
- [ ] 模型选择器 Auto Tab 展示评分详情

**预计代码量**：~100 行改动

### Phase 3：复杂度感知 ⭐⭐⭐

**目标**：根据消息复杂度动态调整策略

- [ ] 消息长度分析
- [ ] 对话轮数感知（长对话可能需要更大 context）
- [ ] 代码检测（消息包含代码块时偏向编程能力强的模型）

### Phase 4：学习型路由 ⭐⭐⭐⭐

**目标**：基于用户行为学习偏好

- [ ] 用户手动切换模型后，调整对应模型权重
- [ ] 路由失败（模型不可用）时自动 fallback
- [ ] 基于对话类别（编程/写作/问答）的偏好学习

### Phase 5：成本优化 ⭐⭐⭐⭐

**目标**：在满足需求的前提下优化成本

- [ ] 模型定价数据接入
- [ ] 简单任务自动选便宜模型
- [ ] Token 用量预算控制

---

## 8. 关键设计决策

| 决策 | 选择 | 原因 |
|------|------|------|
| 路由在哪里执行 | `SendPipeline` Middleware | 复用现有管线架构，不侵入核心发送逻辑 |
| Auto 是否持久化 | 否 | 每次发送独立决策，更灵活 |
| Phase 1 评分方式 | 启发式规则 | 无需训练数据，立即可用 |
| Phase 1 路由时机 | 发送时实时 | 模型可用性可能随时变化 |
| UI 展示 | 显示实际选择的模型 | 透明可解释，用户信任 |

---

## 9. 风险与缓解

| 风险 | 影响 | 缓解方案 |
|------|------|---------|
| 路由选择了不可用的模型 | 请求失败 | `LLMRequester` 已有重试机制，可 fallback 到其他模型 |
| 评分不准 | 选了不合适的模型 | Phase 2 接入历史数据后自动改善 |
| 用户不信任 Auto | 不使用该功能 | 展示选择原因，让用户理解 |
| 本地模型加载慢 | 等待时间长 | Auto 优先选远程模型（除非用户有明确偏好） |

---

## 10. 参考资料

- [Cursor Auto 模式](https://cursor.com) — 行业参考
- [LLMProviderKit 计划](llm-provider-kit-plan.md) — LLM 供应商架构
- `LLMVM.swift` — 模型选择 ViewModel
- `LLMRequester.swift` — 请求发送器
- `SendPipeline.swift` — 中间件管线
- `ChatHistoryPerformance.swift` — 历史性能数据
- `ModelPerformanceStats` — 性能统计模型
