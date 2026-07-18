# LumiComponentPlugin

LumiCore 的插件系统核心组件包。

## ⚠️ 依赖约束

**此包只能被 LumiCoreKit 依赖，不应被其他任何包直接依赖。**

所有外部模块应通过 `LumiCoreKit` 的 typealias 访问此包中的类型：

```swift
// ✅ 正确：通过 LumiCoreKit 访问
import LumiCoreKit

// ❌ 错误：不应直接依赖此包
import LumiComponentPlugin
```

## 包含模块

### 核心协议和类型
- `LumiPlugin` - 插件协议，定义插件的所有贡献点和生命周期
- `PluginComponent` - 插件功能组件
- `LumiPluginContext` - 插件上下文，提供运行时信息
- `LumiPluginInfo` - 插件元信息

### 插件属性
- `LumiPluginCategory` - 插件分类枚举
- `LumiPluginPolicy` - 插件启用策略（默认启用/默认禁用/必需）
- `LumiPluginStage` - 插件开发阶段（alpha/beta/stable）
- `LumiPluginEligibility` - 插件资格条件

### UI 扩展点
- `LumiTitleToolbarItem` - 标题栏工具项
- `LumiStatusBarItem` - 状态栏项
- `LumiViewContainerItem` - 视图容器项
- `LumiSettingsTabItem` - 设置标签页项
- `LumiLLMProviderSettingsViewItem` - LLM Provider 设置视图项

### 生命周期
- `LumiPluginLifecycle` - 插件生命周期事件（didRegister/appDidLaunch/willDisable）

### 错误处理
- `LumiPluginDependencyError` - 插件依赖错误
- `LumiPluginContributionFailure` - 插件贡献失败
- `LumiPluginContributionFailureAggregate` - 插件贡献失败聚合

## 依赖

- `LumiComponentMessage` - 消息模型
- `LumiComponentAgentTool` - Agent 工具系统
- `LumiComponentLLMProvider` - LLM Provider 支持
- `LumiComponentSubAgent` - 子 Agent 定义
- `LumiComponentLayout` - 布局组件
- `LumiComponentProject` - 项目管理
- `LumiComponentMenuBar` - 菜单栏组件
- `LumiComponentOverlay` - 覆盖层组件
- `LumiComponentPanelChrome` - 面板 UI 元素

## 架构设计

本包定义了 LumiCore 的插件系统架构：

1. **插件协议** - `LumiPlugin` 定义了插件可以贡献的所有扩展点：
   - UI 扩展：工具栏、状态栏、设置页、菜单栏、面板等
   - 功能扩展：LLM Provider、Agent 工具、子 Agent、中间件、渲染器
   - 生命周期：注册、启动、禁用时的回调

2. **插件上下文** - `LumiPluginContext` 为插件提供运行时信息，如当前活跃的 section、项目路径等

3. **插件分类和策略** - 通过 Category/Policy/Stage 描述插件的性质和默认行为

4. **贡献聚合** - `LumiChatContributionProviding` 协议允许统一聚合多个插件的贡献

该设计支持高度模块化的应用架构，所有核心功能都通过插件扩展实现。