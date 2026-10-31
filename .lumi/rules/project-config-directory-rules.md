# 项目配置目录规范

> 本规范定义了 Lumi 项目级配置（规则、技能、命令）的存放目录约定。
> 适用于仓库自身的 `.lumi/` 目录，以及 App 内各插件读写用户项目的配置目录。

---

## 核心原则

**项目级配置统一放在项目的 `.lumi/` 目录下；写入只落 `.lumi/`，读取兼容历史目录 `.agent/`。**

---

## 目录约定

| 子目录 | 内容 | 读写方 |
|--------|------|--------|
| `.lumi/rules/` | 规则文档（Markdown，每文件一条规则） | `PluginAgentRules` |
| `.lumi/skills/` | 技能（`<name>/metadata.json` + `<name>/SKILL.md`） | `PluginSkill` |
| `.lumi/commands/` | 命令文档（Markdown） | 人工维护 / 命令面板 |
| `.lumi/prototype/` | 原型任务 | `PluginPrototypeDesigner` |
| `.lumi/app-icon-designer/` | 图标设计产物 | `PluginAppIconDesigner` |
| `.lumi/app-store-connect/` | App Store Connect 素材 | `PluginAppStoreConnect` |

历史目录 `.agent/` 曾承载 `rules/` / `skills/` / `commands/`，现已废弃。

---

## 读写规则

### 写入：一律落 `.lumi/`

新建规则 / 技能时**必须**写入 `.lumi/`，**绝不**写入 `.agent/`。共享的目录约定由
`KitAgentTool` 的 `ProjectConfigDirectory` 统一提供：

```swift
// 写入目标（.lumi/rules、.lumi/skills…）
ProjectConfigDirectory.writeURL(projectPath: path, component: "rules")

// 读取候选（.lumi 优先，.agent 兜底）
ProjectConfigDirectory.readURLs(projectPath: path, component: "rules")

// 定位单个条目实际所在的位置
ProjectConfigDirectory.locate(projectPath: path, component: "skills", name: "my-skill")
```

新增插件若要读写项目级配置，**必须**复用 `ProjectConfigDirectory`，
不要自行拼接 `.lumi` / `.agent` 字面量。

### 读取：`.lumi` 优先，`.agent` 补充

- **列表 / 扫描**：`.lumi/<component>` 全量读取 + `.agent/<component>` 增量补充，
  同名条目以 `.lumi` 为准。
- **单条目读取**：先查 `.lumi/<component>`，未命中再查 `.agent/<component>`。
- **更新 / 删除历史条目**：在其**原位**（`.agent/`）操作，不做隐式迁移——
  用户没要求迁移，就不要替他移动文件。

这样旧项目升级 App 后**无需任何手动改动**即可继续使用既有规则与技能。

---

## 冲突处理

- 同一技能名同时存在于 `.lumi/skills/` 与 `.agent/skills/` 时，**以 `.lumi` 为准**。
- 因此**创建**技能时必须同时检查两个目录，命中任一即拒绝创建，
  避免同名技能分散在两个目录造成读取歧义。

---

## 检查清单

改动项目级配置读写逻辑时，确认：

- [ ] 写入路径只指向 `.lumi/`
- [ ] 读取路径同时覆盖 `.lumi/` 与 `.agent/`，且 `.lumi` 优先
- [ ] 同名条目冲突时以 `.lumi` 为准
- [ ] 更新 / 删除历史条目时不隐式迁移目录
- [ ] 新增插件复用 `ProjectConfigDirectory`，未自行硬编码目录名
- [ ] 工具的 `description(for:)` 与 `inputSchema(for:)` 文案已同步为 `.lumi`
- [ ] `Localizable.xcstrings` 中的相关文案已同步

---

## 相关规范

- [项目开发通用规则](./project-general-rules.md)
- [插件目录结构规范](./plugin-directory-rules.md)
- [插件包目录结构规范](./plugin-package-structure.md)
