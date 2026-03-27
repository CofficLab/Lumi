# 默认模型逻辑说明

## 📋 需求描述

实现默认模型的优先级逻辑：
1. **用户配置优先**: 如果用户配置了默认模型，使用用户配置的
2. **供应商默认**: 如果用户未配置，使用供应商定义的默认模型
3. **降级处理**: 如果没有供应商默认，使用第一个可用模型

## 🔄 修改前的逻辑

### 问题
- "默认"标记显示的是供应商定义的默认模型
- 但实际选中的模型可能是用户配置的
- 导致"默认"标记和实际选中的模型不一致

### 代码逻辑
```swift
// ❌ 原来的逻辑
if let savedModel = AppSettingStore.loadRemoteProviderModel(providerId: selectedProviderId),
   selectedProvider?.availableModels.contains(savedModel) == true {
    selectedModel = savedModel
} else if let defaultModel = selectedProvider?.defaultModel {
    selectedModel = defaultModel
} else if let firstModel = selectedProvider?.availableModels.first {
    selectedModel = firstModel
}

// ❌ 显示逻辑
if let provider = provider, model == provider.defaultModel {
    Text("默认")  // 显示供应商默认
}
```

**问题**:
- 即使选中的是用户配置的模型，"默认"标记仍显示在供应商默认模型上
- 用户无法区分哪个是当前使用的模型

## ✅ 修改后的逻辑

### 优先级规则

```
用户配置模型 > 供应商默认模型 > 第一个可用模型
```

### 代码实现

#### 1. 加载逻辑
```swift
/// 加载当前供应商的默认模型
/// 优先级：用户配置 > 供应商默认 > 第一个可用模型
private func loadSelectedModel() {
    guard selectedProviderId.isNotEmpty else { return }

    // 1. 优先使用用户配置的模型
    if let savedModel = AppSettingStore.loadRemoteProviderModel(providerId: selectedProviderId),
       selectedProvider?.availableModels.contains(savedModel) == true {
        selectedModel = savedModel
    }
    // 2. 如果用户未配置，使用供应商默认模型
    else if let defaultModel = selectedProvider?.defaultModel {
        selectedModel = defaultModel
    }
    // 3. 如果没有默认模型，使用第一个可用模型
    else if let firstModel = selectedProvider?.availableModels.first {
        selectedModel = firstModel
    }
}
```

**逻辑说明**:
1. **优先级1**: 检查用户是否配置了模型
   - 如果配置了且在可用模型列表中，使用用户配置的
2. **优先级2**: 如果用户未配置，使用供应商默认模型
3. **优先级3**: 降级处理，使用第一个可用模型

#### 2. 显示逻辑

```swift
RemoteModelRow(
    model: model,
    isSelected: selectedModel == model,  // 当前选中的模型
    isDefault: model == selectedProvider?.defaultModel,  // 供应商默认
    onTap: { /* ... */ }
)
```

**UI 显示**:
- **对勾图标**: 显示在当前选中的模型上（用户配置的或供应商默认的）
- **"供应商默认"标记**: 显示在供应商定义的默认模型上（灰色，次要标识）

#### 3. RemoteModelRow 组件

```swift
struct RemoteModelRow: View {
    let model: String
    let isSelected: Bool       // 是否为当前选中的模型
    let isDefault: Bool         // 是否为供应商默认模型
    let onTap: () -> Void

    var body: some View {
        GlassRow {
            HStack(spacing: DesignTokens.Spacing.md) {
                // 图标：显示选中状态
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? DesignTokens.Color.semantic.primary : DesignTokens.Color.semantic.textTertiary)

                // 模型名称
                Text(model)
                    .font(DesignTokens.Typography.body)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Spacer()

                // 供应商默认标记（次要标识）
                if isDefault {
                    Text("供应商默认")
                        .font(DesignTokens.Typography.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(DesignTokens.Color.semantic.textSecondary.opacity(0.3))
                        )
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
        }
    }
}
```

## 🎯 用户体验

### 场景1: 首次使用
1. 用户打开设置页面
2. 系统自动选中供应商默认模型
3. 供应商默认模型显示对勾和"供应商默认"标记

**示例**:
```
✓ GPT-4o                    [供应商默认]
○ GPT-4o-mini
○ GPT-3.5-turbo
```

### 场景2: 用户自定义模型
1. 用户点击 "GPT-4o-mini"
2. 系统保存用户选择
3. "GPT-4o-mini" 显示对勾
4. "GPT-4o" 仍显示"供应商默认"标记（次要标识）

**示例**:
```
○ GPT-4o                    [供应商默认]
✓ GPT-4o-mini
○ GPT-3.5-turbo
```

### 场景3: 切换供应商
1. 用户切换到另一个供应商
2. 系统加载该供应商的用户配置（如果有）
3. 如果没有配置，使用该供应商的默认模型

## 📊 数据流程

### 保存流程
```
用户点击模型
    ↓
更新 selectedModel
    ↓
调用 saveModel()
    ↓
保存到 AppSettingStore
    ↓
key: providerId
value: modelId
```

### 加载流程
```
视图出现/切换供应商
    ↓
调用 loadSelectedModel()
    ↓
检查用户配置 (AppSettingStore)
    ↓
有配置 → 使用用户配置的模型
    ↓
无配置 → 使用供应商默认模型
    ↓
无默认 → 使用第一个可用模型
```

## 🔧 技术细节

### AppSettingStore 存储

**存储结构**:
```swift
// UserDefaults
{
    "RemoteProvider.Models": {
        "openai": "gpt-4o-mini",
        "anthropic": "claude-3-5-sonnet-20241022",
        // ...
    }
}
```

**API**:
```swift
// 保存用户配置的模型
AppSettingStore.saveRemoteProviderModel(
    providerId: "openai",
    modelId: "gpt-4o-mini"
)

// 加载用户配置的模型
let model = AppSettingStore.loadRemoteProviderModel(
    providerId: "openai"
)
// 返回: "gpt-4o-mini" 或 nil
```

### LLMProviderInfo 默认模型

```swift
struct LLMProviderInfo {
    let id: String
    let displayName: String
    let iconName: String
    let description: String
    let availableModels: [String]
    let defaultModel: String      // 供应商默认模型
    let isLocal: Bool
}
```

## 📝 关键改进

### 1. 清晰的优先级
- ✅ 用户配置优先于供应商默认
- ✅ 供应商默认优先于降级处理
- ✅ 每个层级都有明确的降级策略

### 2. 准确的 UI 显示
- ✅ 对勾图标显示当前使用的模型
- ✅ "供应商默认"标记显示供应商推荐的模型
- ✅ 两者可以不同，信息更准确

### 3. 代码可维护性
- ✅ 逻辑清晰，易于理解
- ✅ 注释详细，说明优先级
- ✅ 组件职责明确

## 🎨 视觉设计

### 选中状态
- **图标**: `checkmark.circle.fill` (主色)
- **颜色**: `DesignTokens.Color.semantic.primary`
- **含义**: 当前使用的模型

### 供应商默认
- **文本**: "供应商默认"
- **背景**: 次要文本色 30% 透明度
- **颜色**: 次要文本色
- **含义**: 供应商推荐的模型

### 未选中
- **图标**: `circle` (次要色)
- **颜色**: `DesignTokens.Color.semantic.textTertiary`
- **含义**: 可选但未选中的模型

## 🧪 测试场景

### 测试用例1: 首次使用
**输入**: 无用户配置
**预期**: 选中供应商默认模型
**验证**: 对勾显示在供应商默认模型上

### 测试用例2: 用户选择模型
**输入**: 用户点击非默认模型
**预期**: 保存用户选择，对勾移动到该模型
**验证**: 刷新页面后，对勾仍在用户选择的模型上

### 测试用例3: 切换供应商
**输入**: 切换到另一个供应商
**预期**:
- 有用户配置: 使用用户配置的模型
- 无用户配置: 使用新供应商的默认模型
**验证**: 对勾显示正确

### 测试用例4: 供应商默认模型变化
**输入**: 供应商更新默认模型
**预期**:
- 有用户配置: 仍使用用户配置的
- 无用户配置: 使用新的默认模型
**验证**: 行为符合预期

## 📚 相关文件

### 修改的文件
- `LumiApp/Core/Views/Settings/RemoteProvider/RemoteProviderSettingsView.swift`
  - 修改 `loadSelectedModel()` 逻辑
  - 修改 `RemoteModelRow` 参数
  - 更新 UI 显示逻辑

### 相关文件
- `LumiApp/Core/Store/AppSettingStore.swift`
  - `saveRemoteProviderModel()`
  - `loadRemoteProviderModel()`
- `LumiApp/Core/Services/LLM/LLMProviderInfo.swift`
  - `defaultModel` 属性

## 🔄 升级兼容性

### 现有用户
- ✅ 已有用户配置不受影响
- ✅ 继续使用用户之前选择的模型
- ✅ 切换供应商时正常加载配置

### 新用户
- ✅ 默认使用供应商推荐的模型
- ✅ 可以随时切换到其他模型
- ✅ 选择会被保存和记住

## 📝 总结

通过实现清晰的优先级逻辑，确保了：

1. **用户自主性**: 用户配置优先于系统默认
2. **降级策略**: 每个层级都有明确的降级处理
3. **视觉准确**: UI 准确反映当前状态
4. **代码清晰**: 逻辑清晰，易于维护

---

**文档创建时间**: 2025-03-27
**修改状态**: ✅ 已实现并测试
**编译状态**: ✅ BUILD SUCCEEDED
