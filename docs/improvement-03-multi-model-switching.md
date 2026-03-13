# 改进建议：多模型智能切换

**参考产品**: Cursor, Continue, GitHub Copilot  
**优先级**: 🟠 中高  
**影响范围**: LLMService, ProviderRegistry, Conversation

---

## 背景

Cursor 和其他 AI 编程工具支持多个 LLM 模型，并能根据任务类型智能选择最适合的模型：

- 简单补全 → 小型快速模型（如 GPT-3.5）
- 复杂推理 → 大型模型（如 GPT-4, Claude）
- 代码生成 → 代码专项模型（如 DeepSeek-Coder）
- 长上下文 → 支持长窗口的模型

当前 Lumi 虽然支持多供应商，但缺少智能模型选择和切换机制。

---

## 改进方案

### 1. 模型能力描述系统

为每个模型定义能力标签：

```swift
/// 模型能力描述
struct ModelCapabilities: Codable {
    /// 模型标识
    let modelId: String
    
    /// 基础能力
    let abilities: Set<ModelAbility>
    
    /// 上下文窗口大小
    let contextWindow: Int
    
    /// 最大输出 token
    let maxOutputTokens: Int
    
    /// 相对成本 (1-100)
    let costFactor: Int
    
    /// 平均响应时间 (毫秒)
    let avgResponseTime: Int
    
    /// 专项能力评分 (0-100)
    let scores: ModelScores
    
    /// 支持的功能
    let features: Set<ModelFeature>
}

/// 模型能力标签
enum ModelAbility: String, Codable {
    case codeGeneration     // 代码生成
    case codeReview         // 代码审查
    case debugging          // 调试分析
    case explanation        // 代码解释
    case refactoring        // 重构
    case documentation      // 文档生成
    case testGeneration     // 测试生成
    case architecture       // 架构设计
    case quickCompletion    // 快速补全
    case longContext        // 长上下文
}

/// 模型功能
enum ModelFeature: String, Codable {
    case functionCalling    // 函数调用
    case vision             // 图像理解
    case streaming          // 流式输出
    case json               // JSON 模式
    case logprobs           // 输出概率
}

/// 模型评分
struct ModelScores: Codable {
    let codeQuality: Int      // 代码质量
    let speed: Int            // 速度
    let reasoning: Int        // 推理能力
    let instruction: Int      // 指令遵循
    let creativity: Int       // 创造性
}

// 示例模型配置
extension ModelCapabilities {
    static let gpt4 = ModelCapabilities(
        modelId: "gpt-4",
        abilities: [.codeGeneration, .debugging, .architecture, .refactoring],
        contextWindow: 128000,
        maxOutputTokens: 4096,
        costFactor: 80,
        avgResponseTime: 3000,
        scores: ModelScores(
            codeQuality: 95,
            speed: 60,
            reasoning: 95,
            instruction: 95,
            creativity: 90
        ),
        features: [.functionCalling, .vision, .streaming, .json]
    )
    
    static let deepseekCoder = ModelCapabilities(
        modelId: "deepseek-coder",
        abilities: [.codeGeneration, .codeReview, .testGeneration, .documentation],
        contextWindow: 16000,
        maxOutputTokens: 4096,
        costFactor: 20,
        avgResponseTime: 1500,
        scores: ModelScores(
            codeQuality: 90,
            speed: 80,
            reasoning: 80,
            instruction: 85,
            creativity: 70
        ),
        features: [.functionCalling, .streaming]
    )
}
```

---

### 2. 智能模型选择器

根据任务自动选择最佳模型：

```swift
/// 模型选择器
class ModelSelector {
    private let registry: ProviderRegistry
    private let capabilities: [String: ModelCapabilities]
    
    /// 选择最适合的模型
    func selectModel(
        for task: TaskType,
        constraints: TaskConstraints = .init()
    ) -> ModelRecommendation {
        var candidates = filterModels(by: constraints)
        
        // 根据任务类型评分
        candidates = candidates.map { model in
            let score = calculateScore(model: model, for: task)
            return (model, score)
        }
        .sorted { $0.1 > $1.1 }
        
        guard let best = candidates.first else {
            return .fallback
        }
        
        return ModelRecommendation(
            model: best.0,
            score: best.1,
            reason: explainSelection(model: best.0, task: task)
        )
    }
    
    /// 根据约束过滤模型
    private func filterModels(by constraints: TaskConstraints) -> [ModelCapabilities] {
        capabilities.values.filter { model in
            // 检查上下文窗口
            if model.contextWindow < constraints.minContextWindow {
                return false
            }
            
            // 检查功能支持
            if let required = constraints.requiredFeatures {
                if !required.isSubset(of: model.features) {
                    return false
                }
            }
            
            // 检查成本限制
            if model.costFactor > constraints.maxCostFactor {
                return false
            }
            
            // 检查响应时间要求
            if model.avgResponseTime > constraints.maxResponseTime {
                return false
            }
            
            return true
        }
    }
    
    /// 计算模型评分
    private func calculateScore(
        model: ModelCapabilities,
        for task: TaskType
    ) -> Double {
        var score = 0.0
        
        // 根据任务类型加权评分
        switch task {
        case .codeCompletion:
            score += Double(model.scores.speed) * 0.5
            score += Double(model.scores.codeQuality) * 0.3
            if model.abilities.contains(.quickCompletion) {
                score += 20
            }
            
        case .codeGeneration:
            score += Double(model.scores.codeQuality) * 0.5
            score += Double(model.scores.instruction) * 0.3
            if model.abilities.contains(.codeGeneration) {
                score += 20
            }
            
        case .debugging:
            score += Double(model.scores.reasoning) * 0.5
            score += Double(model.scores.codeQuality) * 0.2
            if model.abilities.contains(.debugging) {
                score += 30
            }
            
        case .architecture:
            score += Double(model.scores.reasoning) * 0.5
            score += Double(model.scores.creativity) * 0.2
            if model.abilities.contains(.architecture) {
                score += 30
            }
            
        case .refactoring:
            score += Double(model.scores.codeQuality) * 0.4
            score += Double(model.scores.instruction) * 0.3
            if model.abilities.contains(.refactoring) {
                score += 20
            }
        }
        
        return score
    }
}

/// 任务类型
enum TaskType {
    case codeCompletion    // 代码补全
    case codeGeneration    // 代码生成
    case codeReview        // 代码审查
    case debugging         // 调试
    case refactoring       // 重构
    case architecture      // 架构设计
    case documentation     // 文档生成
    case testGeneration    // 测试生成
    case explanation       // 解释说明
}

/// 任务约束
struct TaskConstraints {
    var minContextWindow: Int = 0
    var maxCostFactor: Int = 100
    var maxResponseTime: Int = Int.max
    var requiredFeatures: Set<ModelFeature>? = nil
}

/// 模型推荐结果
struct ModelRecommendation {
    let model: ModelCapabilities
    let score: Double
    let reason: String
    
    static let fallback = ModelRecommendation(
        model: ModelCapabilities.gpt4,
        score: 0,
        reason: "使用默认模型"
    )
}
```

---

### 3. 任务类型检测器

自动识别用户意图：

```swift
/// 任务类型检测器
class TaskDetector {
    /// 关键词模式
    private let patterns: [TaskType: [String]] = [
        .codeCompletion: ["补全", "complete", "finish"],
        .codeGeneration: ["写一个", "创建", "生成", "实现", "implement", "create"],
        .codeReview: ["审查", "检查", "review", "问题", "bug"],
        .debugging: ["错误", "异常", "崩溃", "debug", "fix", "修复"],
        .refactoring: ["重构", "优化", "refactor", "优化", "改进"],
        .architecture: ["架构", "设计", "structure", "design"],
        .documentation: ["文档", "注释", "document", "comment"],
        .testGeneration: ["测试", "test", "单元测试"],
        .explanation: ["解释", "说明", "什么意思", "explain"]
    ]
    
    /// 检测任务类型
    func detect(from query: String) -> TaskType {
        let queryLower = query.lowercased()
        var scores: [TaskType: Int] = [:]
        
        for (taskType, keywords) in patterns {
            for keyword in keywords {
                if queryLower.contains(keyword.lowercased()) {
                    scores[taskType, default: 0] += 1
                }
            }
        }
        
        // 返回得分最高的任务类型
        return scores.max(by: { $0.value < $1.value })?.key ?? .codeGeneration
    }
    
    /// 从代码上下文检测
    func detectFromContext(
        code: String,
        cursorPosition: Int
    ) -> TaskType {
        // 检测是否在注释中
        if isInComment(code: code, at: cursorPosition) {
            return .documentation
        }
        
        // 检测是否在函数签名后
        if isAfterFunctionSignature(code: code, at: cursorPosition) {
            return .codeGeneration
        }
        
        // 检测是否在行末（可能是补全）
        if isEndOfLine(code: code, at: cursorPosition) {
            return .codeCompletion
        }
        
        return .codeGeneration
    }
}
```

---

### 4. 模型切换策略

```swift
/// 模型切换策略
enum ModelSwitchStrategy {
    /// 固定模型
    case fixed(model: String)
    
    /// 自动选择
    case auto
    
    /// 成本优先
    case costFirst
    
    /// 速度优先
    case speedFirst
    
    /// 质量优先
    case qualityFirst
}

/// 模型切换管理器
class ModelSwitchManager {
    private let selector: ModelSelector
    private let detector: TaskDetector
    private var currentStrategy: ModelSwitchStrategy = .auto
    
    /// 根据策略获取模型
    func getModel(
        for query: String,
        context: ConversationContext? = nil
    ) async -> String {
        switch currentStrategy {
        case .fixed(let model):
            return model
            
        case .auto:
            let task = detector.detect(from: query)
            let recommendation = selector.selectModel(for: task)
            return recommendation.model.modelId
            
        case .costFirst:
            let constraints = TaskConstraints(maxCostFactor: 30)
            let recommendation = selector.selectModel(
                for: .codeGeneration,
                constraints: constraints
            )
            return recommendation.model.modelId
            
        case .speedFirst:
            let constraints = TaskConstraints(maxResponseTime: 1500)
            let recommendation = selector.selectModel(
                for: .codeGeneration,
                constraints: constraints
            )
            return recommendation.model.modelId
            
        case .qualityFirst:
            // 直接使用最高质量模型
            return "gpt-4"
        }
    }
    
    /// 切换策略
    func setStrategy(_ strategy: ModelSwitchStrategy) {
        currentStrategy = strategy
    }
}
```

---

### 5. 上下文长度适配

```swift
/// 上下文长度适配器
class ContextLengthAdapter {
    /// 根据模型调整上下文
    func adaptContext(
        _ context: [ChatMessage],
        for model: ModelCapabilities
    ) -> [ChatMessage] {
        // 计算当前 token 数
        let currentTokens = estimateTokens(context)
        
        // 如果在限制内，直接返回
        let maxContextTokens = Int(Double(model.contextWindow) * 0.7) // 留出 30% 给响应
        if currentTokens <= maxContextTokens {
            return context
        }
        
        // 需要压缩上下文
        return compressContext(context, targetTokens: maxContextTokens)
    }
    
    /// 压缩上下文
    private func compressContext(
        _ context: [ChatMessage],
        targetTokens: Int
    ) -> [ChatMessage] {
        var result: [ChatMessage] = []
        var currentTokens = 0
        
        // 保留最近的消息
        for message in context.reversed() {
            let messageTokens = estimateTokens([message])
            if currentTokens + messageTokens <= targetTokens {
                result.insert(message, at: 0)
                currentTokens += messageTokens
            } else {
                break
            }
        }
        
        return result
    }
    
    /// 估算 token 数
    private func estimateTokens(_ messages: [ChatMessage]) -> Int {
        // 简化估算：每 4 个字符约 1 token
        messages.reduce(0) { sum, message in
            sum + message.content.count / 4
        }
    }
}
```

---

## 实施计划

### 阶段 1: 基础设施 (1 周)
1. 定义模型能力数据结构
2. 创建模型能力配置文件
3. 实现基础 `ModelSelector`

### 阶段 2: 智能选择 (2 周)
1. 实现 `TaskDetector`
2. 实现评分算法
3. 集成到 `LLMService`

### 阶段 3: 优化 (1 周)
1. 添加上下文适配
2. 实现策略切换 UI
3. 添加使用统计

---

## 预期效果

1. **成本优化**: 简单任务使用便宜模型，节省 30-50% 成本
2. **响应速度**: 快速任务响应时间减少 40-60%
3. **质量保障**: 复杂任务自动选择高质量模型
4. **用户体验**: 用户无需手动切换模型

---

## 参考资源

- [Cursor 多模型设计](https://cursor.sh/docs/models)
- [OpenAI Model Endpoints](https://platform.openai.com/docs/models)
- [Anthropic Models](https://www.anthropic.com/models)

---

*创建时间: 2026-03-13*