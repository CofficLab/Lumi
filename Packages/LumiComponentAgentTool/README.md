# LumiComponentAgentTool

LumiCore 的 Agent Tool 工具管理组件包。

## ⚠️ 依赖约束

**此包只能被 LumiCoreKit 依赖，不应被其他任何包直接依赖。**

所有外部模块应通过 `LumiCoreKit` 的 typealias 访问此包中的类型：

```swift
// ✅ 正确：通过 LumiCoreKit 访问
import LumiCoreKit

// ❌ 错误：不应直接依赖此包
import LumiComponentAgentTool
```

## 包含模块

- `AgentToolComponent` - Agent Tool 功能组件，管理工具注册和构建 per-request 工具集
- `LumiAgentTool` - Agent 工具协议，定义工具的元信息、执行逻辑和风险等级
- `LumiToolExecutionContext` - 工具执行上下文，包含会话信息、路径权限、取消支持
- `ToolService` - 工具服务，管理工具集合并执行工具调用
- `LumiCommandRiskLevel` - 命令风险等级枚举（safe/low/medium/high）
- `LumiAgentToolInfo` - 工具元信息结构体

## 依赖

- `LumiComponentMessage` - 消息模型（用于 `LumiToolExecutionContext` 的语言偏好等）

## 架构设计

本包是 Agent Tool 系统的核心，提供：

1. **工具协议** - `LumiAgentTool` 定义了工具的标准接口，包括元信息、输入 Schema、执行方法和风险等级评估
2. **执行上下文** - `LumiToolExecutionContext` 为工具执行提供会话上下文、路径权限检查、取消支持和图片附件收集
3. **工具服务** - `ToolService` 管理工具注册和执行，处理工具调用的完整生命周期
4. **Per-request 工具集** - `AgentToolComponent.buildToolSet` 为每次请求构建独立的工具集合，支持多会话并发

工具的风险等级（`LumiCommandRiskLevel`）用于权限控制，`high` 级别的工具需要用户显式批准。