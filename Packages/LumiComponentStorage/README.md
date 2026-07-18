# LumiComponentStorage

LumiCore 的存储路径管理组件包。

## ⚠️ 依赖约束

**此包只能被 LumiCoreKit 依赖，不应被其他任何包直接依赖。**

所有外部模块应通过 `LumiCoreKit` 的 typealias 访问此包中的类型：

```swift
// ✅ 正确：通过 LumiCoreKit 访问
import LumiCoreKit

// ❌ 错误：不应直接依赖此包
import LumiComponentStorage
```

## 包含模块

- `StorageComponent` - 存储功能组件，管理数据根目录和子目录

## 依赖

无外部依赖。

## 架构设计

本包提供存储路径管理：

1. **数据根目录** - `dataRootDirectory` 在初始化时确定，整个应用生命周期不变
2. **核心数据目录** - `coreDataDirectory` 返回 `<dataRootDirectory>/Core`，用于 LumiCore 内部数据存储
3. **插件数据目录** - `pluginDataDirectory(for:)` 返回插件专属的数据目录，路径为 `<dataRootDirectory>/<PluginName>`

目录特性：
- 所有子目录自动创建（包括中间目录）
- 插件名称会被 sanitizes（非字母数字字符替换为 `_`）
- 空名称会回退到默认值 "Plugin"

该组件为 LumiCore 和插件提供统一的存储路径管理，确保数据隔离和路径安全。