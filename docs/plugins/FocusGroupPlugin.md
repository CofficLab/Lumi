# FocusGroup Plugin Roadmap

## 1. 概述 (Overview)

### 1.1 背景

内容创作者在发布文章、产品文案、营销标题之前，往往需要一个核心答案：**「我的目标用户会怎么看？」**。传统做法是做 A/B 测试或小范围用户调研，但周期长、成本高、样本少。如果能模拟一批具有不同背景特征的虚拟用户，让 LLM 根据每个人的画像生成个性化反馈，创作者就能在发布前快速获得多维度的用户视角洞察。

### 1.2 目标

- **虚拟用户面板**: 提供一批带有明确人口统计学标签（职业、城市、年龄、兴趣等）的模拟用户。
- **多视角反馈**: 接收一个问题/内容（文章标题、产品描述、文案等），让每个虚拟用户独立回答，输出各自的反应。
- **统计聚合**: 自动汇总回答结果，生成百分比统计和可视化摘要（如 "72% 的用户决定点击"）。
- **可定制性**: 用户可自定义虚拟用户的数量、标签组合、场景模板。

### 1.3 设计原则

- **角色一致**: 每个虚拟用户有固定的画像档案，LLM 在生成回答时必须严格遵循该用户的人口统计学特征和性格倾向。
- **并行独立**: 每个虚拟用户的回答互不影响，确保结果多样性。
- **结果可量化**: 所有回答最终收敛为可量化的统计指标（点击率、认同率、购买意愿等）。
- **零内核修改**: 完全通过 SuperPlugin 扩展点实现（AgentTool + 面板视图 + 设置视图）。

---

## 2. 架构设计 (Architecture)

### 2.1 核心组件关系图

```
用户输入 (问题 / 文章标题 / 文案)
       │
       ▼
  ┌─────────────────────┐
  │  PersonaStore        │  管理虚拟用户画像库
  │  (用户画像存储)       │
  └─────────┬───────────┘
            │  提供画像列表
            ▼
  ┌─────────────────────┐       ┌──────────────────┐
  │  SimulationEngine   │──────►│  LLM (并行推理)   │
  │  (模拟引擎)          │◄──────┤                  │
  └─────────┬───────────┘       └──────────────────┘
            │
            ▼
  ┌─────────────────────┐
  │  SimulationResult   │  结构化回答 + 统计聚合
  │  (结果聚合器)        │
  └─────────┬───────────┘
            │
      ┌─────┴──────┐
      ▼            ▼
┌───────────┐  ┌────────────────┐
│ AgentTool │  │  Panel View    │
│ (对话触发) │  │ (可视化面板)   │
└───────────┘  └────────────────┘
```

### 2.2 插件目录结构

```
LumiApp/Plugins/FocusGroupPlugin/
├── FocusGroupPlugin.swift                 # 插件入口，注册面板 + 工具 + 设置
├── Models/
│   ├── Persona.swift                      # 虚拟用户画像
│   ├── PersonaTag.swift                   # 用户标签（职业、城市、年龄等）
│   ├── SimulationQuestion.swift           # 模拟问题
│   └── SimulationResult.swift             # 模拟结果 + 统计摘要
├── Services/
│   ├── PersonaStore.swift                 # 用户画像管理 (Actor)
│   ├── SimulationEngine.swift             # 模拟引擎（构建 Prompt + 调用 LLM）
│   └── ResultAggregator.swift             # 结果聚合与统计分析
├── Tools/
│   └── FocusGroupTool.swift               # Agent 工具：触发模拟
├── Views/
│   ├── FocusGroupPanelView.swift          # 主面板视图
│   ├── PersonaListView.swift              # 用户画像列表
│   ├── PersonaDetailView.swift            # 单个用户详情
│   ├── SimulationInputView.swift          # 模拟输入区
│   ├── SimulationResultView.swift         # 结果展示 + 统计图表
│   └── PersonaEditorView.swift            # 用户画像编辑器
└── Resources/
    └── DefaultPersonas.json               # 默认用户画像数据
```

---

## 3. 详细设计 (Detailed Design)

### 3.1 数据模型

#### A. 虚拟用户画像 (`Persona`)

```swift
struct Persona: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String                        // "张明远"
    var avatar: String                      // Emoji 头像 "👨‍💻"
    var bio: String                         // 简短自我介绍
    var tags: [PersonaTag]                  // 标签集合
    var personality: String                 // 性格特征描述
    var isActive: Bool                      // 是否参与本轮模拟

    /// 画像摘要（注入 Prompt 用）
    var profileSummary: String {
        let tagDesc = tags.map { "\($0.category.rawValue): \($0.value)" }.joined(separator: "、")
        return "\(name) — \(tagDesc)。性格: \(personality)。自我介绍: \(bio)"
    }
}
```

#### B. 用户标签 (`PersonaTag`)

```swift
struct PersonaTag: Codable, Hashable {
    let category: TagCategory
    let value: String

    enum TagCategory: String, Codable, CaseIterable {
        case profession   = "职业"
        case city         = "城市"
        case age          = "年龄段"
        case education    = "学历"
        case interest     = "兴趣"
        case income       = "收入水平"
        case techLevel    = "技术水平"
        case personality  = "性格类型"
        case custom       = "自定义"
    }
}
```

#### C. 模拟问题 (`SimulationQuestion`)

```swift
struct SimulationQuestion: Identifiable, Codable {
    let id: UUID
    var content: String                     // 用户输入的问题/内容
    var scenario: Scenario                  // 场景模板
    var customPrompt: String?               // 自定义追加 Prompt

    enum Scenario: String, Codable, CaseIterable {
        case clickDecision      = "点击决策"         // "你会点击这个标题吗？"
        case contentEvaluation  = "内容评价"         // "你觉得这篇文章怎么样？"
        case purchaseIntention  = "购买意愿"         // "你会买这个产品吗？"
        case readability        = "可读性评价"       // "你能理解这段文案吗？"
        case emotionReaction    = "情感反应"         // "看到这段内容你有什么感受？"
        case custom             = "自定义场景"       // 用户自行定义问题
    }
}
```

#### D. 模拟结果 (`SimulationResult`)

```swift
struct SimulationResult: Identifiable, Codable {
    let id: UUID
    let question: SimulationQuestion
    let responses: [PersonaResponse]
    let summary: SimulationSummary
    let createdAt: Date
}

struct PersonaResponse: Identifiable, Codable {
    let id: UUID
    let personaId: UUID
    let personaName: String
    let personaAvatar: String
    let personaTags: [PersonaTag]
    let answer: String                      // 该用户的回答文本
    let decision: Decision?                 // 结构化决策（如 是否点击）

    enum Decision: String, Codable {
        case positive  = "yes"              // 是 / 会 / 同意
        case negative  = "no"               // 否 / 不会 / 反对
        case neutral   = "neutral"          // 中立 / 不确定
    }
}

struct SimulationSummary: Codable {
    let totalRespondents: Int
    let positiveCount: Int
    let negativeCount: Int
    let neutralCount: Int
    let positiveRate: Double                // 0.72 表示 72%
    let keyInsights: [String]               // LLM 生成的洞察摘要
    let representativeQuotes: [String]      // 代表性回答摘录
}
```

### 3.2 默认用户画像库 (`DefaultPersonas.json`)

插件内置一批覆盖不同领域的典型用户，开箱即用：

```json
[
  {
    "name": "张明远",
    "avatar": "👨‍💻",
    "bio": "全栈开发者，关注技术效率工具，每天刷技术社区 1 小时",
    "tags": [
      { "category": "profession", "value": "全栈工程师" },
      { "category": "city", "value": "北京" },
      { "category": "age", "value": "28" },
      { "category": "techLevel", "value": "高级" },
      { "category": "interest", "value": "AI、开源、效率工具" }
    ],
    "personality": "理性务实，偏好有深度的技术内容，对标题党免疫"
  },
  {
    "name": "李婉清",
    "avatar": "👩‍🎨",
    "bio": "UI 设计师，注重审美和用户体验，重度社交媒体用户",
    "tags": [
      { "category": "profession", "value": "UI 设计师" },
      { "category": "city", "value": "上海" },
      { "category": "age", "value": "25" },
      { "category": "techLevel", "value": "入门" },
      { "category": "interest", "value": "设计、摄影、时尚" }
    ],
    "personality": "感性细腻，容易被视觉吸引力打动，标题要有画面感"
  },
  {
    "name": "王大山",
    "avatar": "👨‍💼",
    "bio": "传统行业创业者，对数字化转型感兴趣但技术基础薄弱",
    "tags": [
      { "category": "profession", "value": "企业主" },
      { "category": "city", "value": "成都" },
      { "category": "age", "value": "42" },
      { "category": "techLevel", "value": "零基础" },
      { "category": "interest", "value": "商业、管理、投资" }
    ],
    "personality": "务实谨慎，只关心内容能不能帮他赚钱或省钱"
  },
  {
    "name": "陈思雨",
    "avatar": "👩‍🎓",
    "bio": "计算机专业大三学生，正在准备实习，经常在 B 站学习编程",
    "tags": [
      { "category": "profession", "value": "大学生" },
      { "category": "city", "value": "武汉" },
      { "category": "age", "value": "21" },
      { "category": "techLevel", "value": "中级" },
      { "category": "interest", "value": "编程、游戏、B站" }
    ],
    "personality": "好奇心强，喜欢有趣易懂的内容，注意力持续时间短"
  },
  {
    "name": "赵建国",
    "avatar": "👴",
    "bio": "退休教师，会用微信和浏览器，对健康养生内容关注",
    "tags": [
      { "category": "profession", "value": "退休教师" },
      { "category": "city", "value": "南京" },
      { "category": "age", "value": "65" },
      { "category": "techLevel", "value": "零基础" },
      { "category": "interest", "value": "养生、书法、历史" }
    ],
    "personality": "耐心仔细，偏好大字体和简洁表达，对网络用语不熟悉"
  },
  {
    "name": "林小美",
    "avatar": "👩‍🍼",
    "bio": "全职妈妈，关注育儿和家庭教育内容，碎片化时间多",
    "tags": [
      { "category": "profession", "value": "全职妈妈" },
      { "category": "city", "value": "杭州" },
      { "category": "age", "value": "32" },
      { "category": "techLevel", "value": "入门" },
      { "category": "interest", "value": "育儿、美食、家居" }
    ],
    "personality": "感性温和，看重内容的实用性和共鸣感，喜欢清单式内容"
  },
  {
    "name": "Alex Chen",
    "avatar": "🧑‍🚀",
    "bio": "硅谷产品经理，关注 AI 和 SaaS 产品，中英双语环境",
    "tags": [
      { "category": "profession", "value": "产品经理" },
      { "category": "city", "value": "旧金山" },
      { "category": "age", "value": "30" },
      { "category": "techLevel", "value": "高级" },
      { "category": "interest", "value": "AI、SaaS、创业" }
    ],
    "personality": "数据驱动，重视逻辑框架和 actionable insights，对空泛内容零容忍"
  },
  {
    "name": "周文婷",
    "avatar": "👩‍⚕️",
    "bio": "三甲医院住院医师，工作繁忙，只看和临床相关的高效内容",
    "tags": [
      { "category": "profession", "value": "医生" },
      { "category": "city", "value": "广州" },
      { "category": "age", "value": "29" },
      { "category": "techLevel", "value": "入门" },
      { "category": "interest", "value": "医学、健身、心理学" }
    ],
    "personality": "时间敏感，偏好权威来源和简洁结论，对长篇大论缺乏耐心"
  }
]
```

### 3.3 模拟引擎 (`SimulationEngine`)

**职责**: 接收问题，为每个激活的虚拟用户构建个性化 Prompt，调用 LLM 获取回答，解析结构化结果。

**Prompt 构建策略**:

```markdown
你正在模拟一位真实用户回答问题。你必须完全代入以下角色，根据这个人的背景、性格和偏好来作答。

## 你的角色

- 姓名: {{name}}
- 简介: {{bio}}
- 标签: {{tags}}
- 性格: {{personality}}

## 问题

{{question}}

## 场景

{{scenario_instruction}}

## 回答要求

1. 以第一人称回答，语气和用词要符合该角色的身份。
2. 先给出你的决策（YES / NO / NEUTRAL），然后用 2-4 句话解释原因。
3. 回答格式必须严格遵循以下 JSON 结构：

```json
{
  "decision": "yes|no|neutral",
  "reason": "你的解释"
}
```
```

**场景指令映射**:

| Scenario | scenario_instruction |
|----------|---------------------|
| `clickDecision` | "你正在浏览信息流，看到了这个标题。你会点击进去阅读吗？" |
| `contentEvaluation` | "你阅读了以下内容。请评价它的质量，你会推荐给朋友吗？" |
| `purchaseIntention` | "你看到了这个产品介绍。你会有购买意愿吗？" |
| `readability` | "你看到了这段文案。你能快速理解它在说什么吗？" |
| `emotionReaction` | "你看到了这段内容。你的第一反应是什么？有什么感受？" |
| `custom` | 使用用户自定义的场景描述 |

**并行调用策略**:

```
SimulationEngine.run()
    │
    ├── 构建 Persona[] × Question 的 Prompt 列表
    │
    ├── 并行发起 LLM 请求 (TaskGroup)
    │   ├── Task 1: 张明远 → LLM Response
    │   ├── Task 2: 李婉清 → LLM Response
    │   ├── Task 3: 王大山 → LLM Response
    │   └── ...
    │
    ├── 解析每个 Response 为 PersonaResponse
    │
    └── ResultAggregator 聚合统计
```

### 3.4 结果聚合器 (`ResultAggregator`)

**职责**: 将所有 `PersonaResponse` 汇总为 `SimulationSummary`。

**统计计算**:

```swift
struct ResultAggregator {
    func aggregate(responses: [PersonaResponse], question: SimulationQuestion) -> SimulationSummary {
        let total = responses.count
        let positive = responses.filter { $0.decision == .positive }.count
        let negative = responses.filter { $0.decision == .negative }.count
        let neutral = responses.filter { $0.decision == .neutral }.count

        return SimulationSummary(
            totalRespondents: total,
            positiveCount: positive,
            negativeCount: negative,
            neutralCount: neutral,
            positiveRate: total > 0 ? Double(positive) / Double(total) : 0,
            keyInsights: extractKeyInsights(from: responses),
            representativeQuotes: selectRepresentativeQuotes(from: responses)
        )
    }
}
```

**关键洞察提取**: 调用 LLM 对所有回答做二次摘要，提炼出 3-5 条关键洞察。

### 3.5 Agent 工具 (`FocusGroupTool`)

注册为 AgentTool，允许用户在对话中直接触发模拟。

- **工具名**: `focus_group_simulate`
- **描述**: "召集一组虚拟用户对指定内容进行评价，返回每个用户的反应和统计摘要。"
- **参数**:

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `content` | string | ✅ | 要测试的内容（标题、文案、产品描述等） |
| `scenario` | string | ❌ | 场景类型：`clickDecision`(默认) / `contentEvaluation` / `purchaseIntention` / `readability` / `emotionReaction` / `custom` |
| `persona_ids` | string[] | ❌ | 指定参与的用户 ID 列表，为空则使用全部活跃用户 |
| `custom_prompt` | string | ❌ | 场景为 `custom` 时的自定义指令 |

- **返回格式** (Agent 可解读的结构化结果):

```json
{
  "summary": {
    "positive_rate": 0.625,
    "positive_count": 5,
    "negative_count": 2,
    "neutral_count": 1,
    "total": 8
  },
  "responses": [
    {
      "persona": "张明远",
      "decision": "yes",
      "reason": "标题提到了 AI 效率提升，这正是我最近在关注的..."
    },
    {
      "persona": "王大山",
      "decision": "no",
      "reason": "技术名词太多，看不出跟我有什么关系..."
    }
  ],
  "insights": [
    "技术背景用户普遍感兴趣，但非技术用户觉得门槛高",
    "有具体数据或案例支撑的表述更容易获得认可"
  ]
}
```

### 3.6 面板视图设计

#### A. 主面板 (`FocusGroupPanelView`)

用户通过活动栏图标进入 FocusGroup 面板。面板分为上下两部分：

```
┌─────────────────────────────────────────────┐
│ 🎯 Focus Group                      [⚙️]    │
├─────────────────────────────────────────────┤
│                                              │
│  ┌─ 输入区 ──────────────────────────────┐  │
│  │                                       │  │
│  │  [ 场景选择 ▾ ]   [ 自定义 Prompt ▾ ] │  │
│  │                                       │  │
│  │  ┌─────────────────────────────────┐  │  │
│  │  │ 输入你的标题/文案/问题...        │  │  │
│  │  │                                 │  │  │
│  │  └─────────────────────────────────┘  │  │
│  │                                       │  │
│  │          [ 🚀 开始模拟 ]              │  │
│  └───────────────────────────────────────┘  │
│                                              │
│  ┌─ 参与用户 ───────────────────────────┐  │
│  │                                       │  │
│  │  👨‍💻 张明远  👩‍🎨 李婉清  👨‍💼 王大山  👩‍🎓 陈思雨 │  │
│  │  👴 赵建国  👩‍🍼 林小美  🧑‍🚀 Alex  👩‍⚕️ 周文婷  │  │
│  │                                       │  │
│  │  共 8 位活跃用户            [管理 ▾]  │  │
│  └───────────────────────────────────────┘  │
│                                              │
│  ┌─ 最近结果 ───────────────────────────┐  │
│  │                                       │  │
│  │  📊 "如何用 AI 提升 10 倍工作效率"    │  │
│  │  场景: 点击决策                       │  │
│  │  ████████████░░░░  62.5% 会点击       │  │
│  │                             [详情 ▸]  │  │
│  │───────────────────────────────────────│  │
│  │  📊 "Swift 6 并发模型完全指南"        │  │
│  │  场景: 点击决策                       │  │
│  │  ████████░░░░░░░░  37.5% 会点击       │  │
│  │                             [详情 ▸]  │  │
│  └───────────────────────────────────────┘  │
│                                              │
└─────────────────────────────────────────────┘
```

#### B. 结果详情视图 (`SimulationResultView`)

```
┌─────────────────────────────────────────────┐
│ ← 返回          模拟结果详情                  │
├─────────────────────────────────────────────┤
│                                              │
│  📋 问题: "如何用 AI 提升 10 倍工作效率"      │
│  🎭 场景: 点击决策                            │
│  👥 参与用户: 8 人                            │
│                                              │
│  ┌─ 统计概览 ──────────────────────────┐    │
│  │                                      │    │
│  │   ██████████████░░░░  62.5%         │    │
│  │                                      │    │
│  │   ✅ 会点击: 5 人 (62.5%)            │    │
│  │   ❌ 不会点击: 2 人 (25.0%)          │    │
│  │   🤷 不确定: 1 人 (12.5%)           │    │
│  │                                      │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  ┌─ 关键洞察 ──────────────────────────┐    │
│  │  💡 技术背景用户普遍感兴趣            │    │
│  │  💡 非技术用户觉得标题太夸张          │    │
│  │  💡 加入具体数据会提升可信度          │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  ┌─ 逐用户回答 ────────────────────────┐    │
│  │                                      │    │
│  │  👨‍💻 张明远                    ✅ YES  │    │
│  │  全栈工程师 · 北京 · 28岁            │    │
│  │  "标题提到了 AI 和效率，正是我最近    │    │
│  │   在关注的。'10 倍'有点夸张但我会    │    │
│  │   好奇具体怎么做。"                   │    │
│  │──────────────────────────────────────│    │
│  │  👩‍🎨 李婉清                    ❌ NO   │    │
│  │  UI 设计师 · 上海 · 25岁             │    │
│  │  "跟我关系不大，而且'10 倍'听起来     │    │
│  │   像是营销号..."                     │    │
│  │──────────────────────────────────────│    │
│  │  👨‍💼 王大山                    ❌ NO   │    │
│  │  企业主 · 成都 · 42岁                │    │
│  │  "AI 能帮我省钱吗？标题没说清楚，     │    │
│  │   不想浪费时间。"                    │    │
│  │──────────────────────────────────────│    │
│  │  👩‍🎓 陈思雨                    ✅ YES  │    │
│  │  大学生 · 武汉 · 21岁                │    │
│  │  "看起来很有意思！我想知道有没有       │    │
│  │   适合学生用的工具。"                │    │
│  │──────────────────────────────────────│    │
│  │  ...                                 │    │
│  │                                      │    │
│  └──────────────────────────────────────┘    │
│                                              │
│         [ 🔄 重新模拟 ]  [ 📋 复制结果 ]     │
│                                              │
└─────────────────────────────────────────────┘
```

#### C. 用户管理视图 (`PersonaListView` + `PersonaEditorView`)

用户可增删改虚拟用户画像：

- 列表展示所有用户，支持启用/禁用切换
- 点击用户进入编辑页，可修改名字、头像、标签、性格描述
- 支持从模板快速创建新用户
- 支持导入/导出画像配置 (JSON)

---

## 4. 交互流程 (Interaction Flow)

### 4.1 面板触发模拟

```
用户进入 FocusGroup 面板
    │
    ▼
选择场景 (如 "点击决策")
    │
    ▼
输入内容 (如文章标题)
    │
    ▼
点击 "🚀 开始模拟"
    │
    ▼
SimulationEngine 并行调用 LLM (每个活跃用户一次)
    │
    ├── Task 1: 张明远 → { "decision": "yes", "reason": "..." }
    ├── Task 2: 李婉清 → { "decision": "no", "reason": "..." }
    ├── Task 3: 王大山 → { "decision": "no", "reason": "..." }
    └── ...
    │
    ▼
ResultAggregator 统计聚合
    │
    ▼
面板实时更新:
  - 进度条 (4/8 完成...)
  - 完成后展示统计概览 + 逐用户回答
```

### 4.2 对话中触发模拟

```
用户: "帮我看看这个标题 '五分钟学会 SwiftUI' 会不会有人点"
    │
    ▼
Agent 识别意图 → 调用 focus_group_simulate 工具
    │
    ▼
SimulationEngine 执行模拟
    │
    ▼
Agent 收到结构化结果，组织自然语言回复:
    "我帮你召集了 8 位虚拟用户测试了这个标题：

     📊 **62.5% 的用户决定点击**（5 人点击，2 人跳过，1 人犹豫）

     主要发现：
     - ✅ 初学者和学生对这个标题非常感兴趣
     - ❌ 技术老手觉得'五分钟学会'是噱头
     - 💡 建议把 '学会' 改成 '上手'，降低心理预期"

     你想看看每个用户的具体回答吗？
```

### 4.3 A/B 标题对比

```
用户: "这两个标题哪个更好？
       A: '五分钟学会 SwiftUI'
       B: 'SwiftUI 零基础入门：从 Hello World 到上架'"
    │
    ▼
Agent 连续调用两次 focus_group_simulate
    │
    ├── Simulate A → 62.5% 点击率
    └── Simulate B → 87.5% 点击率
    │
    ▼
Agent 回复:
    "B 标题明显更优：

     | 标题 | 点击率 | 点评 |
     |------|--------|------|
     | A: 五分钟学会 SwiftUI | 62.5% | 偏营销，老手反感 |
     | B: SwiftUI 零基础入门 | 87.5% | 目标清晰，受众广 |

     B 胜出的原因：技术用户觉得更真诚，非技术用户也能看懂。"
```

---

## 5. 实施计划 (Implementation Plan)

### Phase 1: 数据模型与画像存储
- [ ] 定义 `Persona`, `PersonaTag`, `SimulationQuestion`, `SimulationResult` 数据模型
- [ ] 实现 `PersonaStore` (Actor): 画像的 CRUD、持久化、默认数据加载
- [ ] 创建 `DefaultPersonas.json` (8-12 个典型用户)

### Phase 2: 模拟引擎
- [ ] 实现 `SimulationEngine`: Prompt 构建、LLM 并行调用
- [ ] 实现 LLM Response 解析（JSON 格式 → `PersonaResponse`）
- [ ] 支持 6 种预设场景 + 自定义场景
- [ ] 实现 `ResultAggregator`: 统计计算 + 关键洞察提取

### Phase 3: Agent 工具
- [ ] 实现 `FocusGroupTool`: `focus_group_simulate` 工具注册
- [ ] 参数解析与结果格式化
- [ ] 错误处理（LLM 超时、解析失败等）

### Phase 4: 面板 UI
- [ ] 实现 `FocusGroupPanelView` 主面板
- [ ] 实现 `SimulationInputView` 输入区
- [ ] 实现 `SimulationResultView` 结果展示（含统计条形图）
- [ ] 实现 `PersonaListView` 用户列表 + 启用/禁用
- [ ] 实现 `PersonaEditorView` 画像编辑器

### Phase 5: 设置与优化
- [ ] 实现设置视图（默认用户数、LLM 参数调优、结果历史管理）
- [ ] 结果持久化与历史记录
- [ ] 导入/导出画像配置
- [ ] 性能优化：结果缓存、并发控制

---

## 6. 技术决策 (Technical Decisions)

| 决策点 | 方案 | 理由 |
|--------|------|------|
| **LLM 调用** | 复用 Lumi 已有的 LLM Provider 体系 | 零额外配置，自动适配用户选择的模型 |
| **并行策略** | Swift TaskGroup + 限制最大并发数 (如 5) | 避免过多并发请求打满 Token 限制 |
| **画像存储** | JSON 文件 (`~/Library/Application Support/Lumi/focus-group/`) | 轻量、易调试、支持导入导出 |
| **结果缓存** | 内存缓存最近 10 次模拟结果 | 快速回看，避免重复调用 LLM |
| **Prompt 格式** | 角色代入 + JSON 结构化输出 | 确保结果可解析、可统计 |
| **面板位置** | 独立 Activity Bar 图标 + 面板 | 专注场景，不与其他面板耦合 |
| **默认画像数** | 8 个 | 平衡覆盖面与 LLM 调用成本 |

---

## 7. 插件注册设计

```swift
actor FocusGroupPlugin: SuperPlugin, SuperLog {
    nonisolated static let emoji = "🎯"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false
    static let id: String = "FocusGroup"
    static let displayName: String = String(localized: "Focus Group", table: "FocusGroup")
    static let description: String = String(
        localized: "Simulate diverse user feedback for your content", table: "FocusGroup")
    static let iconName = "person.3.fill"
    static var isConfigurable: Bool { true }
    static var order: Int { 85 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = FocusGroupPlugin()

    // MARK: - Panel

    @MainActor
    func addPanelIcon() -> String? { Self.iconName }

    @MainActor
    func addPanelView(activeIcon: String?) -> AnyView? {
        guard activeIcon == Self.iconName else { return nil }
        return AnyView(FocusGroupPanelView())
    }

    // MARK: - Agent Tool

    @MainActor
    func agentTools() -> [SuperAgentTool] {
        [FocusGroupTool()]
    }

    // MARK: - Settings

    @MainActor
    func addSettingsView() -> AnyView? {
        AnyView(FocusGroupSettingsView())
    }
}
```

---

## 8. Prompt 工程细节

### 8.1 System Prompt

```markdown
你是一个用户模拟系统。你的任务是扮演指定角色，以该角色视角回答问题。
你必须严格按照角色的背景、性格和偏好来反应，不要给出"标准答案"。
回答要自然、口语化，像真实用户一样。
```

### 8.2 User Prompt 模板

```
## 你的角色档案

- 姓名: {{name}}
- 简介: {{bio}}
- 标签: {{tags_summary}}
- 性格: {{personality}}

## 场景

{{scenario_instruction}}

## 需要你判断的内容

{{content}}

## 回答格式

请严格按以下 JSON 格式回答（不要添加任何其他文字）：

{"decision": "yes 或 no 或 neutral", "reason": "2-4句话解释你的想法"}
```

### 8.3 关键洞察提取 Prompt

在所有用户回答收集完毕后，用一次额外的 LLM 调用提炼洞察：

```markdown
以下是 {{count}} 位不同背景用户对同一内容的反应。请分析这些反馈，提炼 3-5 条关键洞察。

## 用户回答

{{all_responses}}

## 要求

1. 找出用户反应的共性和分歧
2. 指出哪些用户群体反应正面，哪些负面，为什么
3. 给出 1-2 条可操作的改进建议
4. 每条洞察不超过 2 句话
```

---

## 9. 扩展能力 (Future Extensions)

| 方向 | 说明 |
|------|------|
| **画像分组** | 支持 "开发者组"、"大众组" 等预设分组，一键切换测试受众 |
| **历史趋势** | 对同一内容迭代优化后，对比不同版本的得分趋势 |
| **多语言用户** | 支持虚拟用户使用不同语言回答（如 Alex 用英文回答） |
| **与编辑器联动** | 在编辑器中选中一段文案，右键触发 Focus Group 评价 |
| **批量测试** | 一次性提交多个标题/版本，输出对比表格 |
| **用户画像模板市场** | 社区共享画像模板，快速导入特定行业/场景的用户组 |

---

## 10. 风险与应对 (Risks & Mitigations)

| 风险 | 影响 | 应对策略 |
|------|------|----------|
| **LLM 幻觉** | 虚拟用户回答不符合角色设定 | Prompt 强调严格代入角色 + few-shot 示例 |
| **Token 消耗大** | 8 个用户 × 每次 = 8 次 LLM 调用 | 限制默认用户数 + 结果缓存 + 可选精简模式(仅返回 decision) |
| **回答格式解析失败** | 无法统计 | JSON 格式强制 + 容错解析（正则兜底提取 decision） |
| **画像刻板印象** | 虚拟用户过于脸谱化 | 定期审查默认画像 + 用户可自由编辑 + 社区模板多样性 |
| **并发限制** | 同时发起过多 LLM 请求被限流 | TaskGroup + 信号量控制并发上限 (5) + 指数退避重试 |

---

此 Roadmap 定义了 **FocusGroup Plugin** 的完整实现路径。方案完全基于 Lumi 现有的插件扩展点（AgentTool + Panel View + Settings），不侵入内核，可独立开发、测试和集成。核心价值在于：**让创作者在发布内容之前，就能预判不同用户的真实反应**。
