# PluginBookletMaker

Lumi 编辑器插件。

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。

## Package

- Product: `PluginBookletMaker`
- Platform: macOS 14+
- Swift tools: 6.0

## 提供什么

PDF 小册子制作与拆分工具，UI 与 Agent 两条入口共用同一套服务。

### UI

- 侧栏 rail + 内容区工作区：拖入 PDF，配置拼版参数并导出可打印小册子；
- 按切点把 PDF 拆成多个文件；
- 说明书（设置 → 通用 → 新手引导 → 说明书）。

### Agent 工具

| 工具 | 用途 | 风险 |
|------|------|------|
| `pdf_inspect` | 读取页数 / 页面尺寸 / 加密状态，并返回拼版计划 | 低 |
| `booklet_make` | 拼版为可打印装订的小册子 PDF | 中（`overwrite` 为高） |
| `pdf_split` | 按切点拆分为多个 PDF | 中（`overwrite` 为高） |
| `booklet_preview` | 渲染前几个印刷面为 PNG 附件 | 低 |

### Agent 技能

`Resources/Skills/booklet-maker/`：说明工具分组、标准工作流、拼版概念与参数速查。
通过 `BookletMakerSkillContributor` 注入 `SkillProviding`。

## 依赖与集成

插件自身完成工具与技能注册，宿主只需装配对应的 Provider：

```swift
dependencies: [
    .package(path: "../PluginBookletMaker"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["PluginBookletMaker"]),
]
```

宿主须注册 `ToolManagerProviding`（工具）与 `SkillProviding`（技能）。
未注册时插件降级为仅启动 UI，不会启动失败——iOS 专用宿主即依赖此行为。

## Testing

From this package directory:

```sh
swift test
```

