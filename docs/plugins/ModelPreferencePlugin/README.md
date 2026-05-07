# Model Preference Plugin

## 📋 说明

这个插件用于记录和获取当前项目使用的供应商和模型偏好设置。

## 🎯 功能

- **保存模型偏好**：保存当前项目使用的供应商和模型
- **获取模型偏好**：读取之前保存的偏好设置
- **清除偏好**：清除保存的偏好设置

## 📁 数据存储

数据保存在：
```
~/Library/Application Support/com.coffic.Lumi/db_production/ModelPreference/settings/preference.plist
```

使用 Property List (Plist) 格式存储，包含以下键：
- `provider`: 供应商名称（如 "OpenAI", "Anthropic"）
- `model`: 模型名称（如 "gpt-4", "claude-3-opus"）

## 💻 使用示例

### 保存偏好

```swift
await ModelPreferencePlugin.shared.savePreference(
    provider: "OpenAI",
    model: "gpt-4"
)
```

### 获取偏好

```swift
if let preference = await ModelPreferencePlugin.shared.getPreference() {
    print("供应商: \(preference.provider)")
    print("模型: \(preference.model)")
}
```

### 清除偏好

```swift
await ModelPreferencePlugin.shared.clearPreference()
```

## 🔧 特性

- ✅ 线程安全（使用 DispatchQueue 保护）
- ✅ 原子写入操作（避免数据损坏）
- ✅ 无 UI（纯后台插件）
- ✅ 支持日志记录（可开关）