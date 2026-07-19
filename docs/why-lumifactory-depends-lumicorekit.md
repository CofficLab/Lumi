# LumiFactory 依赖 LumiCoreKit 的原因分析

## 问题

LumiFactory 为什么依赖 LumiCoreKit？

## 答案

LumiFactory 处于**新旧架构过渡阶段**，视图层仍在使用旧架构的核心类型。

## 详细分析

### 1. 使用的主要类型

LumiFactory 中有 **20个文件** 导入了 LumiCoreKit，主要使用：

#### LumiCore 类
- 旧架构的核心类，管理应用状态和组件
- 包含：
  - `projectComponent` - 项目组件
  - `layoutComponent` - 布局组件
  - `logoComponent` - Logo组件
  - `storage` - 存储服务
  - `chatService` - 聊天服务
  - `editorService` - 编辑器服务

#### LumiCoreAccessing 协议
- 定义访问核心服务的接口
- 视图层通过此协议访问各种服务

### 2. 具体使用场景

#### EditorScopeView.swift
```swift
import LumiCoreKit

struct EditorScopeView<Content: View>: View {
    @ObservedObject private var lumiCore: LumiCore  // 观察旧架构核心

    init(lumiCore: LumiCore, editor: any LumiEditorServicing, ...) {
        self._lumiCore = ObservedObject(wrappedValue: lumiCore)
    }

    var body: some View {
        content
            .onAppear {
                // 访问项目路径
                editor.currentProjectPathProvider = {
                    lumiCore.projectComponent.currentProject?.path ?? ""
                }
            }
    }
}
```

#### PanelColumnView.swift
```swift
import LumiCoreKit

struct PanelColumnView: View {
    let lumiCore: LumiCore  // 直接持有旧架构核心实例
    let editor: any LumiEditorServicing
    @ObservedObject var layoutState: LayoutState

    var body: some View {
        EditorScopeView(lumiCore: lumiCore, editor: editor) {
            // ...
        }
    }
}
```

#### ChatView.swift
```swift
import LumiCoreKit

struct ChatView: View {
    init(
        lumiCore: (any LumiCoreAccessing)? = nil,  // 使用协议类型
        ...
    )
}
```

### 3. 依赖关系图

```
LumiFactory (视图层)
    ↓
LumiCoreKit (旧架构核心)
    ├── LumiCore 类
    ├── LumiCoreAccessing 协议
    └── 核心组件和服务

LumiFactory (工厂层)
    ↓
LumiKernel (新架构核心)
    ├── LumiKernel 类
    └── Provider 模式
```

### 4. 架构状态

#### 当前状态：过渡期混合架构

```
┌─────────────────────────────────────┐
│         LumiFactory                 │
│  ┌─────────────┬──────────────────┐ │
│  │ 视图层(旧)   │  工厂层(新)      │ │
│  │ LumiCore    │  LumiKernel      │ │
│  └─────────────┴──────────────────┘ │
└─────────────────────────────────────┘
         ↓                    ↓
    LumiCoreKit           LumiKernel
```

## 解决方案

### 方案1: 渐进式迁移（推荐）

**步骤**：
1. 在 LumiKernel 中提供 LumiCore 的等价功能
2. 创建适配器模式，让视图可以同时支持新旧核心
3. 逐个视图迁移到新架构
4. 最后移除对 LumiCoreKit 的依赖

**优点**：
- 风险可控
- 可以分阶段测试
- 不影响现有功能

**缺点**：
- 需要较长时间
- 需要维护适配器代码

### 方案2: 一次性重构

**步骤**：
1. 同时重构所有视图
2. 直接使用 LumiKernel
3. 删除对 LumiCoreKit 的依赖

**优点**：
- 架构干净
- 一步到位

**缺点**：
- 风险高
- 影响面大
- 需要大量测试

### 方案3: 保留 LumiCoreKit 作为核心类型包

**步骤**：
1. 将 LumiCoreKit 转变为纯类型定义包
2. 保留 LumiCoreAccessing 协议
3. 实现类改用 LumiKernel

**优点**：
- 兼容性好
- 迁移平滑

**缺点**：
- 增加一个包
- 需要维护类型定义

## 建议

**短期**（当前）：
- 保持现状，先完成插件迁移的集成测试
- 确认 LumiKernel 功能完整

**中期**（下一步）：
- 采用方案1，渐进式迁移视图层
- 为关键视图创建 LumiKernel 版本

**长期**：
- 完成所有视图迁移
- 移除 LumiFactory 对 LumiCoreKit 的依赖

---

**创建时间**: 2026-07-19
**状态**: 分析完成