# 项目开发通用规则

> 本规范定义了 Lumi 项目的通用开发规则和指导方针。

---

## 项目信息

- **平台**: macOS APP
- **技术栈**: SwiftUI, Swift, LumiLoggingKit, KitOpenIn

### 模块导入（LumiApp）

`LumiApp/Core/Bootstrap/Global.swift` 通过 `@_exported import` 向整个 **LumiApp** 模块透出 `LumiLoggingKit`（`SuperLog`）、`KitOpenIn`（`URL.openIn*`）与 `EditorService`。`SuperPlugin`、`SuperAgentTool` 等定义在 `LumiApp/Core/Proto/`。因此 **LumiApp 内**一般**不必**再写 `import LumiLoggingKit`、`import KitOpenIn` 或 `import EditorService`。

独立 **SPM Package** 仍是独立模块，须按需自行 `import LumiLoggingKit` 等，并尽量少依赖。

---

## 通用规则

### 1. 文档管理

在完成代码修改、重构或功能开发后，**禁止**创建或更新 README 文件。

### 2. 构建要求

无需构建，除非用户明确说明。

### 3. 错误处理

如果任何函数会抛出错误，必须设计合理的视图来展示错误。

### 4. 内核与插件边界

内核不得依赖插件实现；插件之间不得相互依赖。细则见 [内核与插件边界规范](./core-plugin-boundary-rules.md)。

### 5. 依赖升级

改动 `LumiUI` / `LumiProviders` / `LumiLogging` 等**共享依赖**的版本时，主工程 lock 与 `Packages/FactoryLumiACP/Package.resolved` 必须**同时更新**，并跑通 `verify-package-locks.py`。否则 Release workflow 会在编译前直接失败。细则见 [SPM 依赖锁文件同步规范](./spm-package-lock-sync.md)。

### 6. 条件编译

只在 `#if DEBUG` 内定义的类型，其引用点（含函数体）必须同等包裹；改动夹具或 `#if DEBUG` 代码后需用 `swift build -c release` 验证。本地 Debug 通过不代表 Release 可编译。细则见 [条件编译（DEBUG / Release）规范](./debug-only-code-guards.md)。

### 7. 项目配置目录

项目级配置（规则、技能、命令）统一放在项目的 `.lumi/` 目录下；写入只落 `.lumi/`，读取兼容历史目录 `.agent/`。新增插件读写项目配置时必须复用 `KitAgentTool` 的 `ProjectConfigDirectory`，不要自行硬编码目录名。细则见 [项目配置目录规范](./project-config-directory-rules.md)。

---

## 相关规范

- [内核与插件边界](./core-plugin-boundary-rules.md)
- [SPM 依赖锁文件同步](./spm-package-lock-sync.md)
- [条件编译 DEBUG / Release](./debug-only-code-guards.md)
- [项目配置目录](./project-config-directory-rules.md)
- [数据存储规范](./plugin-storage-rules.md)
- [目录结构规范](./plugin-directory-rules.md)
- [国际化规范](./plugin-i18n-rules.md)
- [设置界面 LumiUI 规范](./settings-ui.md)
- [最少功能原则](./minimal-functionality.md)
- [自动化测试 / 大模型自测](./automation-system-rules.md)
