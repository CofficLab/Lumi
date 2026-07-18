# LumiComponentSubAgent

LumiCore 的子 Agent 定义组件包。

## ⚠️ 依赖约束

**此包只能被 LumiCoreKit 依赖，不应被其他任何包直接依赖。**

所有外部模块应通过 `LumiCoreKit` 的 typealias 访问此包中的类型：

```swift
// ✅ 正确：通过 LumiCoreKit 访问
import LumiCoreKit

// ❌ 错误：不应直接依赖此包
import LumiComponentSubAgent
```

## 包含模块

- `LumiSubAgentDefinition` - 子 Agent 的声明式定义
- `SubAgentDelegateTool` - 子 Agent 委托工具，将子 Agent 包装为工具

## 依赖

- `LumiComponentMessage` - 消息模型
- `LumiComponentAgentTool` - Agent 工具系统
- `LumiComponentLLMProvider` - LLM Provider 支持

## 架构设计

本包提供子 Agent 的声明式配置：

1. **子 Agent 定义** - `LumiSubAgentDefinition` 包含：
   - 标识：全局唯一 ID 和显示名称
   - 模型绑定：指定 LLM Provider 和模型
   - 行为指导：自定义 system prompt
   - 工具过滤：通过标签和名称控制可用工具集

2. **工具过滤机制**：
   ```
   全集 = toolService.tools
     1. 按 requiredTags 过滤（OR 语义）
     2. 移除 excludedTags（包含任一排除标签即移除）
     3. 移除 excludedToolNames（精确排除）
     4. 加上 additionalToolNames（去重补充）
   ```

3. **委托工具** - `SubAgentDelegateTool` 将子 Agent 包装为 `delegate_<id>` 工具，注入主 Agent 的 toolService

4. **安全约束** - `maxTurns` 限制最大推理轮数，防止失控

该设计支持插件声明专用子 Agent，实现复杂任务的分层处理。