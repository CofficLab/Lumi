# ModelPreferencePlugin 数据流图

## 📊 完整数据流

```
┌─────────────────────────────────────────────────────────────────────┐
│                         用户操作                                     │
│  ┌──────────────┐  选择模型   ┌──────────────┐                      │
│  │ ModelSelector │───────────→│  LLMVM       │                      │
│  │    View      │            │  - selectedProviderId               │
│  └──────────────┘            │  - currentModel                    │
│                              └───────┬───────┘                      │
│                                      │ onChange                     │
│                                      ▼                              │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │        ModelPreferenceRootView (自动监听)                    │    │
│  │  ┌──────────────────────────────────────────────────────┐  │    │
│  │  │ handleModelChange()                                   │  │    │
│  │  │ 1. 检查是否有项目                                     │  │    │
│  │  │ 2. 检查配置是否变化                                   │  │    │
│  │  │ 3. 调用 Plugin.savePreference()                       │  │    │
│  │  └──────────────────┬───────────────────────────────────┘  │    │
│  │                     │                                       │    │
│  │  ┌──────────────────▼───────────────────────────────────┐  │    │
│  │  │ handleProjectChange()                                 │  │    │
│  │  │ 1. 项目切换时触发                                     │  │    │
│  │  │ 2. 调用 Plugin.getPreference()                        │  │    │
│  │  │ 3. 更新 LLMVM 配置                                     │  │    │
│  │  └──────────────────┬───────────────────────────────────┘  │    │
│  └─────────────────────┼───────────────────────────────────────┘    │
│                        │                                            │
└────────────────────────┼────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      ModelPreferencePlugin                           │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ savePreference(provider:, model:)                            │   │
│  │  - 从 ProjectVM 获取当前项目路径                               │   │
│  │  - 调用 Store.savePreference(forProject:...)                 │   │
│  └────────────────────┬────────────────────────────────────────┘   │
│                       │                                             │
│  ┌────────────────────▼────────────────────────────────────────┐   │
│  │ getPreference() → (provider, model, lastUpdated)?           │   │
│  │  - 从 ProjectVM 获取当前项目路径                               │   │
│  │  - 调用 Store.getPreference(forProject:)                    │   │
│  └────────────────────┬────────────────────────────────────────┘   │
└───────────────────────┼─────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      ModelPreferenceStore                            │
│                                                                      │
│  savePreference(forProject:provider:model:)                          │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ 1. projectPath.md5() → "a3f5e9c2b1d4"                       │   │
│  │ 2. fileURL = baseDirectory/"a3f5e9c2b1d4"/preference.plist  │   │
│  │ 3. 读取现有配置                                              │   │
│  │ 4. 更新 dict["provider"], dict["model"], dict["lastUpdated"]│   │
│  │ 5. 原子写入文件                                              │   │
│  └────────────────────┬────────────────────────────────────────┘   │
│                       │                                             │
│                       ▼                                             │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    磁盘文件结构                              │   │
│  │                                                              │   │
│  │  ~/Library/Application Support/                             │   │
│  │  └── com.cofficlab.Lumi/                                    │   │
│  │      └── db_debug/ (或 db_production/)                      │   │
│  │          └── ModelPreference/                               │   │
│  │              └── projects/                                  │   │
│  │                  ├── a3f5e9c2b1d4/                          │   │
│  │                  │   └── preference.plist                   │   │
│  │                  │       {                                   │   │
│  │                  │         "provider": "anthropic",         │   │
│  │                  │         "model": "claude-3-5-sonnet",    │   │
│  │                  │         "lastUpdated": <Date>            │   │
│  │                  │       }                                   │   │
│  │                  │                                           │   │
│  │                  └── 5d41402abc4b2a76/                      │   │
│  │                      └── preference.plist                   │   │
│  │                          {                                   │   │
│  │                            "provider": "openai",            │   │
│  │                            "model": "gpt-4-turbo",          │   │
│  │                            "lastUpdated": <Date>            │   │
│  │                          }                                   │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  getPreference(forProject:)                                          │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ 1. projectPath.md5() → "a3f5e9c2b1d4"                       │   │
│  │ 2. fileURL = baseDirectory/"a3f5e9c2b1d4"/preference.plist  │   │
│  │ 3. 检查文件是否存在                                          │   │
│  │ 4. 读取并解析 plist                                          │   │
│  │ 5. 返回 (provider, model, lastUpdated)?                     │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

## 🔄 典型使用场景

### 场景 1：用户选择模型

```
用户点击 ModelSelectorView
    ↓
选择 "Anthropic" → "claude-3-5-sonnet"
    ↓
llmVM.selectedProviderId = "anthropic"
llmVM.currentModel = "claude-3-5-sonnet"
    ↓
触发 onChange
    ↓
ModelPreferenceRootView.handleModelChange()
    ↓
检查：
  - currentProjectPath = "/Users/dev/Projects/MyApp" ✓
  - provider = "anthropic" ✓
  - model = "claude-3-5-sonnet" ✓
  - 与 lastSaved 不同 ✓
    ↓
ModelPreferencePlugin.savePreference(provider: "anthropic", model: "claude-3-5-sonnet")
    ↓
ModelPreferenceStore.savePreference(
  forProject: "/Users/dev/Projects/MyApp",
  provider: "anthropic",
  model: "claude-3-5-sonnet"
)
    ↓
计算哈希："/Users/dev/Projects/MyApp".md5() = "a3f5e9c2b1d4"
    ↓
写入文件：
  ~/Library/Application Support/.../ModelPreference/projects/a3f5e9c2b1d4/preference.plist
    ↓
日志：💾 保存项目偏好：/Users/dev/Projects/MyApp -> anthropic / claude-3-5-sonnet
```

### 场景 2：用户切换项目

```
用户选择新项目 "/Users/dev/Projects/AnotherApp"
    ↓
projectVM.currentProjectPath = "/Users/dev/Projects/AnotherApp"
    ↓
触发 onChange
    ↓
ModelPreferenceRootView.handleProjectChange()
    ↓
清除 lastSavedProjectPath
    ↓
ModelPreferencePlugin.getPreference()
    ↓
ModelPreferenceStore.getPreference(
  forProject: "/Users/dev/Projects/AnotherApp"
)
    ↓
计算哈希："/Users/dev/Projects/AnotherApp".md5() = "5d41402abc4b2b"
    ↓
读取文件：
  ~/Library/Application Support/.../ModelPreference/projects/5d41402abc4b2b/preference.plist
    ↓
如果文件存在：
  返回 (provider: "openai", model: "gpt-4-turbo", lastUpdated: Date)
    ↓
检查：llmVM 当前是否为空？
  - 如果是空 → 加载保存的配置
  - 如果已有值 → 不覆盖（用户手动选择的优先级更高）
    ↓
日志：📂 已加载项目偏好：AnotherApp -> openai / gpt-4-turbo
```

## 🔐 数据安全特性

```
┌─────────────────────────────────────────┐
│          原子写入保证数据完整性          │
└─────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│  1. 写入临时文件                         │
│     preference.tmp                       │
│                                          │
│  2. 验证写入成功                          │
│                                          │
│  3. 原子替换原文件                        │
│     replaceItemAt()                      │
│                                          │
│  4. 如果失败，删除临时文件                │
│                                          │
│  ✅ 即使断电也不会损坏原文件             │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│          线程安全                         │
└─────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│  • 所有操作在专用 DispatchQueue 上执行    │
│  • queue = DispatchQueue(               │
│      label: "ModelPreferenceStore.queue"│
│    )                                     │
│                                          │
│  • 使用 queue.sync {} 确保串行访问       │
│                                          │
│  ✅ 避免多线程并发问题                   │
└─────────────────────────────────────────┘
```

## 📈 性能优化

```
┌──────────────────────────────────────────┐
│  防重复写入                              │
└──────────────────────────────────────────┘
              │
              ▼
检查条件：
  ✓ currentProvider == lastSavedProvider
  ✓ currentModel == lastSavedModel
  ✓ currentProjectPath == lastSavedProjectPath

如果全部相同 → 跳过写入
  ↓
避免不必要的 I/O 操作
  ↓
延长 SSD 寿命，提升性能
```

## 🗂️ 文件生命周期

```
项目创建 → 首次选择模型 → 创建配置文件
    ↓
项目使用中 → 多次切换模型 → 更新配置文件
    ↓
切换项目 → 加载新项目配置 → 读取另一个配置文件
    ↓
清除项目 → 删除配置文件 → 文件被移除
```
