# LumiComponentLLMProvider

LumiCore 的 LLM Provider 管理组件包。

## ⚠️ 依赖约束

**此包只能被 LumiCoreKit 依赖，不应被其他任何包直接依赖。**

所有外部模块应通过 `LumiCoreKit` 的 typealias 访问此包中的类型：

```swift
// ✅ 正确：通过 LumiCoreKit 访问
import LumiCoreKit

// ❌ 错误：不应直接依赖此包
import LumiComponentLLMProvider
```

## 包含模块

### 核心协议和类型
- `LumiLLMProvider` - LLM Provider 协议，定义 API Key 管理和请求发送接口
- `LumiLLMRequest` - LLM 请求结构体，包含消息、模型、工具和图片附件
- `LLMProviderComponent` - LLM Provider 功能组件

### 状态和错误处理
- `LumiProviderState` - Provider 状态枚举
- `LumiLLMProviderStatus` - Provider 状态描述（如缺少 API Key、套餐过期）
- `LumiLLMProviderSupportError` - Provider 支持错误
- `LumiLLMErrorDisposition` - 错误处置策略

### 模型能力
- `LumiModelVisionSupport` - 模型视觉支持检测
- `ProviderRenderKindManager` - 渲染类型管理器

## 依赖

- `LumiComponentMessage` - 消息模型（请求/响应）
- `LumiComponentAgentTool` - Agent 工具（工具定义）
- `SuperLogKit` - 日志系统
- `LumiLocalizationKit` - 本地化支持

## 架构设计

本包定义了 LLM Provider 的标准接口：

1. **Provider 协议** - `LumiLLMProvider` 定义了所有 LLM 供应商必须实现的接口，包括：
   - API Key 管理（存储、读取、删除）
   - 同步和流式请求发送
   - 模型可用性检查
   - 错误处置和渲染类型映射

2. **请求模型** - `LumiLLMRequest` 封装了完整的 LLM 请求参数

3. **状态管理** - `LumiLLMProviderStatus` 提供 UI 可展示的 Provider 状态说明

4. **功能组件** - `LLMProviderComponent` 作为 ObservableObject 管理 Provider 相关状态

该设计支持多种 LLM 供应商的统一接入，包括 OpenAI、Anthropic、StepFun 等。