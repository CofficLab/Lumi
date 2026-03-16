# 插件代码检查指令

## 重要规则

仅执行检查指令，无需进行总结。检查所有插件文件是否符合 [插件开发规范](../rules/plugin-development.mdc) 的要求。

## 步骤

### 1. 检查插件目录结构

遍历 `LumiApp/Plugins/` 目录下所有插件，检查：

- [ ] 插件目录命名是否为 `PluginNamePlugin` 格式（PascalCase + Plugin 后缀）
- [ ] 主文件名是否与目录名一致（`PluginNamePlugin.swift`）
- [ ] 子目录结构是否规范（Models/, Views/, ViewModels/, Services/）

### 2. 检查插件主文件结构

对每个 `*Plugin.swift` 文件，检查：

- [ ] 是否使用 `actor` 声明（不是 `class`）
- [ ] 是否实现 `SuperPlugin` 协议
- [ ] import 顺序是否正确（`MagicKit` 在前，`SwiftUI` 在后）

### 3. 检查必需属性

对每个插件，验证以下必需属性是否存在且格式正确：

- [ ] `nonisolated static let emoji` - 表情符号
- [ ] `nonisolated static let enable: Bool` - 必须有显式类型注解 `: Bool`
- [ ] `nonisolated static let verbose: Bool` - 必须有显式类型注解
- [ ] `static let id` - 插件唯一标识
- [ ] `static let navigationId` - 导航标识（可为 `nil`）
- [ ] `static let displayName` - 必须使用 `String(localized:)` 本地化
- [ ] `static let description` - 必须使用 `String(localized:)` 本地化
- [ ] `static let iconName` - SF Symbols 图标名称
- [ ] `static var order: Int` - 必须使用计算属性（`var { }` 不是 `let`）
- [ ] `nonisolated var instanceLabel: String` - 实例标签
- [ ] `static let shared` - 单例实例

### 4. 检查协议实现

- [ ] 检查是否统一实现 `SuperLog` 协议（如有日志需求）
- [ ] 如果实现 `SuperLog`，检查是否定义 `verbose` 属性
- [ ] 如果实现 `SuperLog`，检查是否使用 `self.t` 或 `self.log()` 进行日志记录

### 5. 检查生命周期方法

检查生命周期方法的完整性（要么全部实现，要么全部省略）：

- [ ] `nonisolated func onRegister()` 
- [ ] `nonisolated func onEnable()`
- [ ] `nonisolated func onDisable()`

如果实现，检查：
- [ ] `onEnable` 和 `onDisable` 中的主线程操作是否使用 `Task { @MainActor in ... }` 包裹

### 6. 检查 UI 贡献方法

- [ ] 检查 `addNavigationEntries()` 方法实现是否规范
- [ ] 如果有导航条目，检查 `navigationId` 是否非 `nil`
- [ ] 检查 `NavigationEntry.create` 的参数是否完整
- [ ] 如果插件提供状态栏弹窗，检查 `addStatusBarPopupView()` 方法

### 7. 检查代码组织

- [ ] MARK 注释是否规范（`// MARK: - Plugin Properties`, `// MARK: - Lifecycle`, `// MARK: - UI`, `// MARK: - Preview`）
- [ ] 属性声明顺序是否符合规范（emoji → enable → verbose → id → navigationId → ... → shared）
- [ ] 是否有不必要的空方法（如空的 `onRegister`/`onEnable`/`onDisable` 应考虑省略）

### 8. 检查国际化

- [ ] `displayName` 和 `description` 是否使用 `String(localized:)` 
- [ ] 检查 `LumiApp/Core/Localizable.xcstrings` 中是否有对应的本地化条目
- [ ] 检查是否有硬编码的中英文字符串

### 9. 检查 Preview 预览

- [ ] 是否包含 `#Preview` 预览代码
- [ ] 预览是否正确引用插件的 `navigationId`
- [ ] 预览结构是否与模板一致

### 10. 检查禁用状态

- [ ] 检查未完成的插件是否设置 `enable = false`
- [ ] 检查禁用的插件是否有注释说明原因

### 11. 检查单例和实例标签

- [ ] 每个插件是否定义 `static let shared`
- [ ] 每个插件是否实现 `instanceLabel` 计算属性

### 12. 生成检查报告

执行以下操作：

1. **列出所有不符合规范的插件**
2. **对每个问题提供具体的修复建议**
3. **自动修复可以自动修复的问题**（如 import 顺序、类型注解、MARK 注释等）
4. **标记需要手动修复的问题**（如缺失的属性、本地化字符串等）

## 修复优先级

### 高优先级（必须修复）
- 缺少必需属性
- 未使用 `String(localized:)` 进行本地化
- `enable` 缺少类型注解
- `order` 使用 `let` 而非 `var`
- 缺少 `shared` 单例

### 中优先级（建议修复）
- import 顺序不正确
- MARK 注释不规范
- 缺少 `SuperLog` 协议实现
- 缺少 `instanceLabel`

### 低优先级（可选修复）
- 缺少 Preview 预览
- 生命周期方法不完整
- 属性声明顺序不一致

## 执行命令示例

检查单个插件：
```bash
# 检查指定插件文件
head -50 LumiApp/Plugins/PluginNamePlugin/PluginNamePlugin.swift
```

检查所有插件的 enable 状态：
```bash
grep -h "static let enable" LumiApp/Plugins/*/*Plugin.swift
```

检查所有插件的协议实现：
```bash
grep -h "^actor.*:.*SuperPlugin" LumiApp/Plugins/*/*Plugin.swift
```

检查所有插件的 order 声明：
```bash
grep -h "static.*order" LumiApp/Plugins/*/*Plugin.swift
```

## 输出格式

检查结果应按以下格式输出：

```
## 插件代码检查报告

### ✅ 符合规范的插件 (X 个)
- PluginAPlugin
- PluginBPlugin

### ⚠️ 需要修复的插件 (Y 个)

#### PluginCPlugin
- [HIGH] 缺少 `emoji` 属性
- [HIGH] `enable` 缺少类型注解 `: Bool`
- [MEDIUM] import 顺序不正确
- [LOW] 缺少 Preview 预览

#### PluginDPlugin
- [HIGH] `displayName` 未本地化
- [MEDIUM] 缺少 `SuperLog` 协议实现

### 📊 统计
- 总插件数: Z
- 符合规范: X
- 需要修复: Y
- 高优先级问题: A
- 中优先级问题: B
- 低优先级问题: C
```

## 注意事项

- 检查时不要修改正在开发中的实验性插件（`enable = false` 的插件可适当放宽要求）
- 对于功能重复的插件，标记出来供后续合并或移除参考
- 检查过程中发现严重问题时，应优先修复高优先级问题
