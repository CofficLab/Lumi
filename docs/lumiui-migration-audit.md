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

- `Plugins/PluginGit/Sources/PluginGit/Views/GitCommitDetailView.swift`
- `Plugins/PluginAgentRequestLog/Sources/PluginAgentRequestLog/Views/RequestLogDetailView.swift`
- `Plugins/PluginDockerManager/Sources/PluginDockerManager/Views/DockerImagesView.swift`
- `Plugins/PluginModelSelector/Sources/PluginModelSelector/Views/AvailabilityDetailView.swift`
- `Plugins/PluginAgentMessageRenderer/Sources/PluginAgentMessageRenderer/MessageComponent/MessageWithToolCallsView.swift`
- `LumiApp/Core/Views/Settings/LocalProvider/LocalModelRow.swift`

`Color(hex:)` 主要集中在 Editor Plugins、系统监控类插件、Core Settings 和 Status/Menu Bar。优先文件：

- `Plugins/PluginEditorPanel/Sources/PluginEditorPanel/Views/EditorCommandPaletteView.swift`
- `Plugins/PluginNetworkManager/Sources/PluginNetworkManager/Views/NetworkMenuBarPopupView.swift`
- `Plugins/PluginDeviceInfo/Sources/PluginDeviceInfo/Views/DeviceInfoView.swift`
- `Plugins/PluginAgentGitHubTools/Sources/PluginAgentGitHubTools/Views/GitHubPluginSettingsView.swift`
- `LumiApp/Core/Views/Settings/PluginSettingsView.swift`

### Typography

`.font(.system...)` 是最大逃逸点，共 1157 处。优先文件：

- `Plugins/PluginGit/Sources/PluginGit/Views/GitCommitDetailView.swift`
- `Plugins/PluginAgentRAG/Sources/PluginAgentRAG/Views/RAGStatusBarView.swift`
- `Plugins/PluginModelSelector/Sources/PluginModelSelector/Views/AvailabilityDetailView.swift`
- `Plugins/PluginAgentRequestLog/Sources/PluginAgentRequestLog/Views/RequestLogDetailView.swift`
- `Plugins/PluginEditorPanel/Sources/PluginEditorPanel/Views/EditorCommandPaletteView.swift`
- `Plugins/PluginNetworkManager/Sources/PluginNetworkManager/Views/NetworkMenuBarPopupView.swift`

这说明 LumiUI 需要先暴露更完整的 typography API，否则迁移会变成把 `.font(.system...)` 换成另一组业务层 modifier。

### Surface, Card, Row

`RoundedRectangle` 和 `.background(...)` 的热点说明许多页面仍在手写 card、row、badge 和 panel surface。优先文件：

- `Plugins/PluginEditorPreview/Sources/PluginEditorPreview/Views/EditorPreviewDetailView.swift`
- `Plugins/PluginAgentGitHubTools/Sources/PluginAgentGitHubTools/Views/GitHubPluginSettingsView.swift`
- `Plugins/PluginAgentOnboarding/Sources/PluginAgentOnboarding/Views/OnboardingRootOverlay.swift`
- `Plugins/PluginGit/Sources/PluginGit/Views/GitCommitDetailView.swift`
- `LumiApp/Core/Views/Layout/ContentView.swift`
- `Plugins/PluginLSPCodeActionEditor/Sources/PluginLSPCodeActionEditor/Views/CodeActionPanel.swift`

### Chrome Theme Coupling

`activeChromeTheme.*Color()` 主要集中在 editor panels。优先文件：

- `Plugins/PluginEditorRailWorkspaceSearch/Sources/PluginEditorRailWorkspaceSearch/Views/EditorWorkspaceSearchPanelView.swift`
- `Plugins/PluginEditorPreview/Sources/PluginEditorPreview/Views/EditorPreviewDetailView.swift`
- `Plugins/PluginEditorBottomSearch/Sources/PluginEditorBottomSearch/Views/BottomEditorWorkspaceSearchPanelView.swift`
- `Plugins/PluginEditorRailReferences/Sources/PluginEditorRailReferences/Views/EditorReferencesWorkspacePanelView.swift`
- `Plugins/PluginEditorBottomReferences/Sources/PluginEditorBottomReferences/Views/BottomEditorReferencesWorkspacePanelView.swift`

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
