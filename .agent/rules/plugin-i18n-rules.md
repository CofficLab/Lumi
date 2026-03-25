# 插件国际化（i18n）规范

> 本规范定义了 Lumi 项目中所有插件的多语言（国际化）实现方式和最佳实践。

---

## 核心原则

**每个插件独立管理国际化资源，使用统一的 `.xcstrings` 格式，支持动态多语言切换。**

所有用户可见的文本都必须进行国际化，禁止在代码中硬编码用户可见字符串。

---

## 文件格式

### 文件扩展名

```
<PluginName>.xcstrings
```

### 文件结构

```json
{
  "sourceLanguage": "en",
  "version": "1.0",
  "strings": {
    "Key String": {
      "localizations": {
        "en": {
          "stringUnit": {
            "state": "translated",
            "value": "Key String"
          }
        },
        "zh-Hans": {
          "stringUnit": {
            "state": "translated",
            "value": "键字符串"
          }
        },
        "zh-HK": {
          "stringUnit": {
            "state": "translated",
            "value": "鍵字符串"
          }
        }
      }
    }
  }
}
```

### 字段说明

| 字段 | 说明 | 必填 | 示例 |
|------|------|------|------|
| `sourceLanguage` | 源语言代码 | ✅ | `"en"` |
| `version` | 文件格式版本 | ✅ | `"1.0"` |
| `strings` | 字符串字典 | ✅ | - |
| `localizations` | 语言列表 | ✅ | - |
| `state` | 翻译状态 | ✅ | `"translated"` |
| `value` | 翻译后的文本 | ✅ | `"键字符串"` |

### 翻译状态

| 状态 | 说明 |
|------|------|
| `translated` | 已完成翻译 |
| `needsReview` | 需要审查 |
| `notTranslated` | 未翻译 |

---

## 支持语言

| 语言代码 | 语言 | 优先级 |
|---------|------|--------|
| `en` | 英语 | 必须（源语言） |
| `zh-Hans` | 简体中文 | 必须 |
| `zh-HK` | 繁体中文 | 推荐 |

---

## 文件命名

### 标准命名

```
<PluginName>.xcstrings
```

**示例**：
```
AppManager.xcstrings
ClipboardManager.xcstrings
MemoryManager.xcstrings
```

### 文件位置

```
LumiApp/Plugins/<PluginName>/<PluginName>.xcstrings
```

---

## 使用方式

### 基础用法

```swift
// 视图中使用
Text(String(localized: "Hello World", table: "PluginName"))

// 属性定义
static let displayName = String(localized: "Plugin Name", table: "PluginName")

// 动态消息
let message = String(localized: "Hello, %@", table: "PluginName", arguments: userName)
```

### 完整示例

```swift
import MagicKit
import SwiftUI

struct MemoryManagerPlugin: SuperPlugin {
    static let displayName = String(localized: "Memory Monitor", table: "MemoryManager")
    static let description = String(localized: "Real-time monitoring of system memory usage", table: "MemoryManager")
    
    var body: some View {
        VStack {
            Text(String(localized: "Memory Usage", table: "MemoryManager"))
                .font(.headline)
            
            Text(String(localized: "Total: %@", table: "MemoryManager", arguments: totalMemory))
            
            Button(String(localized: "Refresh", table: "MemoryManager")) {
                // ...
            }
        }
    }
}
```

### 带参数的字符串

**xcstrings 文件**：
```json
{
  "Selected: %@": {
    "localizations": {
      "en": {
        "stringUnit": {
          "state": "translated",
          "value": "Selected: %@"
        }
      },
      "zh-Hans": {
        "stringUnit": {
          "state": "translated",
          "value": "已选：%@"
        }
      }
    }
  },
  "%lld Apps": {
    "localizations": {
      "en": {
        "stringUnit": {
          "state": "translated",
          "value": "%lld Apps"
        }
      },
      "zh-Hans": {
        "stringUnit": {
          "state": "translated",
          "value": "%lld 个应用"
        }
      }
    }
  }
}
```

**Swift 代码**：
```swift
Text(String(localized: "Selected: %@", table: "AppManager", arguments: selectedCount))
Text(String(localized: "%lld Apps", table: "AppManager", arguments: appCount))
```

### 带命名参数的字符串

**xcstrings 文件**：
```json
{
  "Switched {type} registry to {name}": {
    "localizations": {
      "en": {
        "stringUnit": {
          "state": "translated",
          "value": "Switched {type} registry to {name}"
        }
      },
      "zh-Hans": {
        "stringUnit": {
          "state": "translated",
          "value": "已切换 {type} 源为 {name}"
        }
      }
    }
  }
}
```

**Swift 代码**：
```swift
let message = String(
    localized: "Switched {type} registry to {name}",
    table: "RegistryManager",
    arguments: ["type": registryType, "name": registryName]
)
```

---

## 创建 xcstrings 文件

### 步骤 1：创建文件

在插件目录下创建 `<PluginName>.xcstrings` 文件

### 步骤 2：添加基础结构

```json
{
  "sourceLanguage": "en",
  "version": "1.0",
  "strings": {}
}
```

### 步骤 3：添加字符串

手动添加或使用 Xcode 的本地化导出功能。

### 步骤 4：翻译

为每种支持的语言添加翻译。

---

## 最佳实践

### ✅ 推荐

1. **所有用户可见文本都国际化**
   - 按钮标题、标签、提示信息
   - 错误消息、成功提示
   - 菜单项、工具提示

2. **使用有意义的键**

   ```swift
   // ✅ 好：使用完整句子作为键
   String(localized: "Confirm Uninstall", table: "AppManager")
   
   // ❌ 避免：使用无意义的键
   String(localized: "btn_confirm_1", table: "AppManager")
   ```

3. **保持翻译文件同步**
   - 添加新字符串时同时提供所有语言的翻译
   - 定期审查 `needsReview` 状态的字符串

4. **使用 Xcode 本地化编辑器**
   - 在 Xcode 中打开 `.xcstrings` 文件
   - 使用可视化编辑器管理翻译

5. **注释复杂字符串**

   ```json
   {
     "Switched {type} registry to {name}": {
       "comment": "{type} = registry type (npm, pypi, etc.), {name} = registry name",
       "localizations": { ... }
     }
   }
   ```

### ❌ 避免

1. **硬编码用户可见文本**

   ```swift
   // ❌ 错误
   Text("Click here to refresh")
   
   // ✅ 正确
   Text(String(localized: "Click here to refresh", table: "PluginName"))
   ```

2. **混合语言**

   ```swift
   // ❌ 错误：中文硬编码
   Text(String(localized: "点击刷新", table: "PluginName"))
   
   // ✅ 正确：使用英文键
   Text(String(localized: "Click to refresh", table: "PluginName"))
   ```

3. **过长的字符串**
   - 将长文本拆分为多个可重用的片段

4. **忽略占位符顺序**
   - 不同语言的语法顺序可能不同，使用命名参数

---

## 现有实现参考

| 插件 | 文件 | 字符串数量 | 特点 |
|-----|------|-----------|------|
| RClickPlugin | `RClick.xcstrings` | 603 行 | 最完整 |
| BrewManagerPlugin | `BrewManager.xcstrings` | 389 行 | 完整 |
| PortManagerPlugin | `PortManager.xcstrings` | 327 行 | 完整 |
| AppManagerPlugin | `AppManager.xcstrings` | 326 行 | 标准实现 |
| TextActionsPlugin | `TextActions.xcstrings` | 304 行 | 完整 |
| CaffeinatePlugin | `Caffeinate.xcstrings` | 165 行 | 完整 |
| RegistryManagerPlugin | `RegistryManager.xcstrings` | 117 行 | 含动态参数 |
| DiskManagerPlugin | `DiskManager.xcstrings` | 117 行 | 完整 |
| SettingsButtonPlugin | `SettingsButton.xcstrings` | 57 行 | 简洁 |
| NettoPlugin | `Netto.xcstrings` | 57 行 | 简洁 |

---

## 检查清单

创建新插件时，确保：

- [ ] 创建 `<PluginName>.xcstrings` 文件
- [ ] 设置 `sourceLanguage` 为 `"en"`
- [ ] 提供英文 (`en`) 翻译
- [ ] 提供简体中文 (`zh-Hans`) 翻译
- [ ] 提供繁体中文 (`zh-HK`) 翻译（推荐）
- [ ] 所有用户可见文本使用 `String(localized:table:)`
- [ ] 动态消息使用占位符 (`%@` 或 `{name}`)
- [ ] 在 Xcode 中验证本地化文件

---

## 附录

### A. 常见占位符

| 占位符 | 类型 | 示例 |
|--------|------|------|
| `%@` | 字符串 | `"Hello, %@"` → `"Hello, World"` |
| `%d` | 整数 | `"%d items"` → `"5 items"` |
| `%lld` | 长整数 | `"%lld Apps"` → `"100 Apps"` |
| `%.2f` | 浮点数 | `"%.2f MB"` → `"12.34 MB"` |
| `{name}` | 命名参数 | `"Hello, {name}"` |

### B. 语言代码参考

| 代码 | 语言 | 地区 |
|------|------|------|
| `en` | 英语 | - |
| `zh-Hans` | 简体中文 | 中国大陆 |
| `zh-HK` | 繁体中文 | 中国香港 |
| `zh-TW` | 繁体中文 | 中国台湾 |
| `ja` | 日语 | 日本 |
| `ko` | 韩语 | 韩国 |

### C. Xcode 本地化导出

1. 在 Xcode 中选择项目
2. 选择 **Editor** → **Export Localizations**
3. 选择导出格式为 `.xcstrings`
4. 选择要导出的语言

### D. 相关文档

- [Apple Localization 文档](https://developer.apple.com/documentation/xcode/localization)
