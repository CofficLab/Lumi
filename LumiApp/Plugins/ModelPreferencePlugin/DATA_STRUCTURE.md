# ModelPreferencePlugin 数据存储结构

## 📁 目录结构

```
~/Library/Application Support/com.cofficlab.Lumi/
└── db_debug/ (或 db_production/)
    └── ModelPreference/
        └── projects/
            ├── <project_hash_1>/
            │   └── preference.plist
            ├── <project_hash_2>/
            │   └── preference.plist
            └── <project_hash_3>/
                └── preference.plist
```

## 📄 文件内容示例

### 文件路径
```
~/Library/Application Support/com.cofficlab.Lumi/db_debug/ModelPreference/projects/a3f5e9c2b1d4/preference.plist
```

### 文件内容（二进制 plist 格式）

使用 `plutil` 命令查看：
```bash
plutil -p ~/Library/Application\ Support/com.cofficlab.Lumi/db_debug/ModelPreference/projects/a3f5e9c2b1d4/preference.plist
```

输出示例：
```json
{
  "provider" : "anthropic",
  "model" : "claude-3-5-sonnet-20241022",
  "lastUpdated" : "2024-03-24T09:30:00Z"
}
```

## 🔑 项目路径哈希

目录名使用项目路径的 MD5 哈希：

| 项目路径 | 哈希目录名 |
|---------|-----------|
| `/Users/dev/Projects/MyApp` | `5f4dcc3b5aa765d61d8327deb882cf99` |
| `/Users/dev/Projects/AnotherApp` | `098f6bcd4621d373cade4e832627b4f6` |
| `/Users/dev/Code/Lumi` | `5d41402abc4b2a76b9719d911017c592` |

## 📊 存储特性

### 1. 每个项目独立配置
- 每个项目有自己的 `preference.plist` 文件
- 项目之间互不干扰
- 切换项目时自动加载对应的配置

### 2. 原子写入
- 使用临时文件 + 替换的方式写入
- 避免写入过程中断电导致文件损坏
- 保证数据完整性

### 3. 二进制格式
- 使用二进制 plist 格式（非 XML）
- 文件体积小
- 读写性能好

### 4. 包含元数据
- `provider`: 供应商 ID（如 "anthropic", "openai"）
- `model`: 模型名称（如 "claude-3-5-sonnet-20241022"）
- `lastUpdated`: 最后更新时间（Date 类型）

## 🔍 查看实际数据

### 方法 1：使用 plutil
```bash
# 列出所有项目配置
ls ~/Library/Application\ Support/com.cofficlab.Lumi/db_debug/ModelPreference/projects/

# 查看特定项目的配置
plutil -p ~/Library/Application\ Support/com.cofficlab.Lumi/db_debug/ModelPreference/projects/<hash>/preference.plist
```

### 方法 2：使用 Swift 代码
```swift
let store = ModelPreferenceStore.shared
if let pref = store.getPreference(forProject: "/Users/dev/Projects/MyApp") {
    print("Provider: \(pref.provider)")
    print("Model: \(pref.model)")
    print("Updated: \(pref.lastUpdated ?? Date())")
}
```

### 方法 3：直接查看文件
```bash
# 打开 Finder
open ~/Library/Application\ Support/com.cofficlab.Lumi/db_debug/ModelPreference/projects/
```

## 🗑️ 清除数据

### 清除特定项目
```bash
rm -rf ~/Library/Application\ Support/com.cofficlab.Lumi/db_debug/ModelPreference/projects/<hash>/
```

### 清除所有项目配置
```bash
rm -rf ~/Library/Application\ Support/com.cofficlab.Lumi/db_debug/ModelPreference/projects/*
```

## 📝 示例场景

### 场景 1：用户切换项目

1. 用户在项目 A 中选择 `anthropic` / `claude-3-5-sonnet`
   - 保存：`projects/<hash_A>/preference.plist`
   
2. 用户切换到项目 B
   - 自动加载：`projects/<hash_B>/preference.plist`
   - 如果不存在，保持当前选择或默认值

3. 用户在项目 B 中选择 `openai` / `gpt-4-turbo`
   - 保存：`projects/<hash_B>/preference.plist`
   
4. 用户再次切换回项目 A
   - 自动加载：`projects/<hash_A>/preference.plist`
   - 恢复到 `anthropic` / `claude-3-5-sonnet`

### 场景 2：数据文件内容对比

**项目 A 的配置：**
```json
{
  "provider": "anthropic",
  "model": "claude-3-5-sonnet-20241022",
  "lastUpdated": "2024-03-24T09:30:00Z"
}
```

**项目 B 的配置：**
```json
{
  "provider": "openai",
  "model": "gpt-4-turbo-preview",
  "lastUpdated": "2024-03-24T10:15:00Z"
}
```

## 🔐 安全性

- 数据存储在用户专属的 Application Support 目录
- 不涉及敏感信息（仅存储供应商和模型名称）
- 不使用 Keychain（因为不是敏感数据）
- 文件权限遵循 macOS 默认设置

## 📈 性能优化

1. **异步队列**: 所有读写操作在专用 Dispatch Queue 上执行
2. **哈希目录**: 使用路径哈希避免长路径问题
3. **按需加载**: 只在项目切换时读取配置
4. **防重复写入**: 检测配置变化，避免不必要的写操作
