# LumiUI Migration Audit

首轮审计目标是找出业务 UI 中仍绕过 `LumiUI` 的通用视觉样式。审计脚本：

```bash
scripts/audit-lumiui-styles.sh LumiApp
```

脚本排除了 `**/Marketing/**`、`**/ThirdParty/**`、`**/Plugins/Theme*Plugin/*Theme.swift` 和 `*.generated.swift`，避免把营销截图、第三方代码和主题定义里的合法固定色算成迁移债务。

## Baseline

| Check | Hits | Files |
| --- | ---: | ---: |
| `Color.adaptive` | 605 | 158 |
| `Color(hex:)` | 488 | 123 |
| `.font(.system...)` | 1147 | 231 |
| `RoundedRectangle` | 166 | 78 |
| `.cornerRadius(...)` | 33 | 28 |
| `activeChromeTheme.*Color()` | 186 | 32 |
| `.foregroundColor(...)` | 1170 | 228 |
| `.background(...)` | 306 | 163 |

`LumiApp` 当前扫描到 1056 个 Swift 文件，其中 158 个文件已经 `import LumiUI`。这说明迁移重点不是引入依赖，而是把业务视图里散落的颜色、字号、圆角、surface 和 row/button/form 模式收敛回 LumiUI。

## Hotspots

### Direct Color Usage

`Color.adaptive` 主要集中在 Other Plugins、Chat、Status/Menu Bar、Editor Plugins 和 Core Settings。优先文件：

- `LumiApp/Plugins/GitPlugin/Views/GitCommitDetailView.swift`
- `LumiApp/Plugins/AgentRequestLogPlugin/Views/RequestLogDetailView.swift`
- `LumiApp/Plugins/DockerManagerPlugin/Views/DockerImagesView.swift`
- `LumiApp/Plugins/ModelSelectorPlugin/Views/AvailabilityDetailView.swift`
- `LumiApp/Plugins/AgentMessageRendererPlugin/MessageComponent/MessageWithToolCallsView.swift`
- `LumiApp/Core/Views/Settings/LocalProvider/LocalModelRow.swift`

`Color(hex:)` 主要集中在 Editor Plugins、系统监控类插件、Core Settings 和 Status/Menu Bar。优先文件：

- `LumiApp/Plugins/EditorPanelPlugin/Views/EditorCommandPaletteView.swift`
- `LumiApp/Plugins/NetworkManagerPlugin/Views/NetworkMenuBarPopupView.swift`
- `LumiApp/Plugins/DeviceInfoPlugin/Views/DeviceInfoView.swift`
- `LumiApp/Plugins/AgentGitHubToolsPlugin/Views/GitHubPluginSettingsView.swift`
- `LumiApp/Core/Views/Settings/PluginSettingsView.swift`

### Typography

`.font(.system...)` 是最大逃逸点，共 1157 处。优先文件：

- `LumiApp/Plugins/GitPlugin/Views/GitCommitDetailView.swift`
- `LumiApp/Plugins/AgentRAGPlugin/Views/RAGStatusBarView.swift`
- `LumiApp/Plugins/ModelSelectorPlugin/Views/AvailabilityDetailView.swift`
- `LumiApp/Plugins/AgentRequestLogPlugin/Views/RequestLogDetailView.swift`
- `LumiApp/Plugins/EditorPanelPlugin/Views/EditorCommandPaletteView.swift`
- `LumiApp/Plugins/NetworkManagerPlugin/Views/NetworkMenuBarPopupView.swift`

这说明 LumiUI 需要先暴露更完整的 typography API，否则迁移会变成把 `.font(.system...)` 换成另一组业务层 modifier。

### Surface, Card, Row

`RoundedRectangle` 和 `.background(...)` 的热点说明许多页面仍在手写 card、row、badge 和 panel surface。优先文件：

- `LumiApp/Plugins/EditorPreviewPlugin/Views/EditorPreviewDetailView.swift`
- `LumiApp/Plugins/AgentGitHubToolsPlugin/Views/GitHubPluginSettingsView.swift`
- `LumiApp/Plugins/AgentOnboardingPlugin/Views/OnboardingRootOverlay.swift`
- `LumiApp/Plugins/GitPlugin/Views/GitCommitDetailView.swift`
- `LumiApp/Core/Views/Layout/ContentView.swift`
- `LumiApp/Plugins/LSPCodeActionEditorPlugin/Views/CodeActionPanel.swift`

### Chrome Theme Coupling

`activeChromeTheme.*Color()` 主要集中在 editor panels。优先文件：

- `LumiApp/Plugins/EditorRailWorkspaceSearchPlugin/Views/EditorWorkspaceSearchPanelView.swift`
- `LumiApp/Plugins/EditorPreviewPlugin/Views/EditorPreviewDetailView.swift`
- `LumiApp/Plugins/EditorBottomSearchPlugin/Views/BottomEditorWorkspaceSearchPanelView.swift`
- `LumiApp/Plugins/EditorRailReferencesPlugin/Views/EditorReferencesWorkspacePanelView.swift`
- `LumiApp/Plugins/EditorBottomReferencesPlugin/Views/BottomEditorReferencesWorkspacePanelView.swift`

这些文件不一定都要立刻改掉，但应该明确哪些属于 chrome layout 边界，哪些只是普通插件 UI 想拿颜色。

## Recommended First Batch

第一批不要直接动编辑器 overlay 或聊天流式路径。建议从这些低风险、高收益区域开始：

- Core Settings: `PluginSettingsView`、`LocalModelRow`、provider/model row 系列。
- Status/Menu Bar details: DeviceInfo、NetworkManager、HistoryDB、AgentRequestLog、RAG status detail。
- Management plugin detail pages: Git commit detail、Docker images、Model availability、GitHub plugin settings。

## LumiUI Gaps To Fill First

- Public typography tokens: title、section、body、caption、mono caption、status text。
- Public semantic surfaces: panel、popover、toolbar strip、list row hover/selected、divider、focus ring。
- Form/list scaffolds: settings section、row、picker row、text field row、toggle row、footer actions。
- Status components: metric card、status pill、inline progress、inline loading、empty/loading/error state.

## Next Action

public typography 和 semantic surface API 已先行补齐，并用 `PluginSettingsView` 做了小范围试迁移。下一步继续抽 settings/form/list scaffold，然后迁移 `Core/Views/Settings` 中的 2-3 个重复 row/page。
