# ModelRouterKit

零依赖的自动模型路由决策包。

## 概述

外部（App 层）负责收集候选模型列表并构建路由信号，Package 负责评分和决策，输出最优模型。

## 数据流

```
外部提供：
├── RouteSignal（上下文：是否含图片、消息长度、是否需要工具、当前选中...）
└── [RouteCandidate]（候选模型：供应商名、模型名、可用性、上下文窗口...）

Package 输出：
└── RouteDecision?（最优候选 + 决策理由 + 评分）
```

## 使用

```swift
import ModelRouterKit

let signal = RouteSignal(
    hasImages: true,
    messageLength: 1500,
    allowsTools: true,
    currentProviderId: "openai",
    currentModel: "gpt-4o"
)

let candidates: [RouteCandidate] = [
    RouteCandidate(
        providerId: "openai",
        providerDisplayName: "OpenAI",
        model: "gpt-4o",
        availability: .available,
        contextWindowSizes: ["gpt-4o": 128000]
    ),
    RouteCandidate(
        providerId: "anthropic",
        providerDisplayName: "Anthropic",
        model: "claude-sonnet-4-20250514",
        availability: .available,
        contextWindowSizes: ["claude-sonnet-4-20250514": 200000]
    ),
]

let router = ModelRouter()
if let decision = router.route(candidates: candidates, signal: signal) {
    print("选中：\(decision.providerDisplayName) · \(decision.model)")
    print("理由：\(decision.reason)")
}
```

## 自定义评分

```swift
struct MyScoring: ModelScoring {
    func score(candidate: RouteCandidate, signal: RouteSignal) -> Double {
        // 自定义评分逻辑
    }
}

let router = ModelRouter(scoring: MyScoring())
```

## 默认评分规则

| 因素 | 分值 | 说明 |
|---|---|---|
| 可用性 `.available` | +100 | 检测通过的模型大幅加分 |
| 可用性 `.checking` | +30 | 正在检测 |
| 可用性 `.unknown` | +20 | 未检测过 |
| 当前供应商相同 | +8 | 倾向保持当前供应商 |
| 供应商 + 模型都相同 | +16 | 强倾向保持当前选择 |
| 短消息 + mini 模型 | +8 | 短对话用小模型更高效 |
| 长消息（>2000字） | +上下文窗口/10万 | 长对话倾向大窗口模型 |
| 需要工具 + codex/coder | +10 | 编码任务用代码模型 |
| haiku/mini/flash | +2 | 快速模型轻微加分 |
