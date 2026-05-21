# Lumi Memory Growth Audit

Scope: `/Users/colorfy/Code/CofficLab/Lumi`

This report tracks modules that may cause memory or resource usage to keep rising over long sessions. It focuses on concrete ownership chains, unbounded collections, observers, tasks, timers, processes, database connections, and plugin lifecycle behavior.

## Batch 1: Core Lifecycle And High-Risk Plugins

### 1. Plugin disable does not call `onDisable`

- Module: Core plugin lifecycle
- Path: `LumiApp/Core/ViewModels/AppPluginVM.swift`
- Risk: High
- Evidence:
  - `AppPluginVM` discovers plugins once and calls `onRegister()` / `onEnable()` at lines 315-321.
  - `AppPluginSettingsVM.setPluginEnabled` only mutates settings and posts `.pluginSettingsChanged` at `LumiApp/Core/ViewModels/AppPluginSettingsVM.swift:32-40`.
  - Search found no call site for `plugin.onDisable()` except protocol defaults and plugin implementations.
- Why this can grow memory:
  - Plugins with timers, hotkey monitors, background services, process/session managers, or global caches are filtered out of UI, but their cleanup hook is never invoked.
  - Examples affected by design: `ClipboardManagerPlugin` starts `ClipboardMonitor.shared`, `QuickFileSearchPlugin` starts a local event monitor, `AppUpdateStatusBarPlugin` has a store with subscriptions, and future MCP enablement would hold subprocess/SSE clients.
- Trigger:
  - User disables a configurable plugin from settings or onboarding.
- Suggested fix:
  - Track previous enabled state in `AppPluginVM` and call `onEnable()` / `onDisable()` on settings changes before clearing UI caches.
  - Add a regression test with a fake plugin that increments enable/disable counters.

### 2. Cached plugin `AnyView`s retain plugin UI state for the whole app lifetime

- Module: Core plugin UI aggregation
- Path: `LumiApp/Core/ViewModels/AppPluginVM.swift`
- Risk: High
- Evidence:
  - `AppPluginVM` is a global singleton at line 63 and holds all plugin instances in `plugins` at line 75.
  - It also caches multiple `AnyView` arrays/dictionaries at lines 102-119.
  - `getActivePanelItem`, `getBottomPanelContentView`, `getRailContentView`, `getSidebarToolbarItemView`, and status/menu/toolbar getters store plugin-created views at lines 496-573, 612-626, 694-707, 734-742, 752-823.
- Why this can grow memory:
  - SwiftUI views can capture `@StateObject`, closures, services, and large state graphs. Caching `AnyView` in a global VM can keep those graphs alive after the user switches panels/tabs or after the plugin is disabled.
  - Cache keys include active icon/tab suffixes. The current key space is bounded by known plugin tabs, but captured state can still be retained much longer than visible UI lifetime.
- Trigger:
  - Switching panels, opening bottom/rail content, plugin settings changes, and long-running app sessions.
- Suggested fix:
  - Cache only lightweight metadata where possible. Rebuild `AnyView` on demand or cache factories instead of concrete `AnyView`.
  - At minimum, clear all UI caches on window close, plugin disable, active project close, and memory warning style events.

### 3. Window close does not perform scope teardown

- Module: Window lifecycle
- Paths:
  - `LumiApp/Core/ViewModels/WindowManagerVM.swift`
  - `LumiApp/Core/Entities/WindowScope.swift`
  - `LumiApp/Core/Controllers/SendController.swift`
  - `LumiApp/Core/ViewModels/WindowEditorVM.swift`
- Risk: High
- Evidence:
  - `WindowManagerVM.unregisterScope` only removes the scope from arrays/maps and posts notification at `WindowManagerVM.swift:71-80`.
  - `WindowScope` owns many VMs and controllers but has no `deinit` or `cleanup` (`WindowScope.swift:157-230`, file ends at line 367).
  - `SendController` stores active send tasks in `activeSendTasksByConversation` at `SendController.swift:18`, starts tasks at lines 72-78, and only cancels individual conversations through `cancelSend` at lines 81-99.
  - `WindowEditorVM` owns `EditorService` and subscriptions but has no explicit teardown at `WindowEditorVM.swift:37-65`.
- Why this can grow memory:
  - Closing a window while a send task, editor load, LSP action, file watcher, or delayed task is running can allow the task/closure chain to retain the scope and its services longer than expected.
  - Without a single teardown point, editor sessions, pending sends, file watchers, diagnostics subscriptions, and plugin-backed providers depend on incidental deallocation.
- Trigger:
  - Open a project, start a send or editor/LSP operation, close the window, repeat.
- Suggested fix:
  - Add `WindowScope.cleanup()` and call it from `WindowManagerVM.unregisterScope` before removing the scope.
  - Cleanup should cancel all send tasks, clear queues, close all editor sessions, close current LSP document, cleanup file watchers, clear Combine subscriptions, and notify plugins that care about window scope teardown.

### 4. `WindowMessagePendingVM` grows without a clear path

- Module: Chat pending messages
- Path: `LumiApp/Core/ViewModels/WindowMessagePendingVM.swift`
- Risk: Medium-High
- Evidence:
  - `messages` is an unbounded array at line 20.
  - Messages are appended from `SendController.beginSendFromQueue` at `LumiApp/Core/Controllers/SendController.swift:108-112`.
  - Project system/assistant messages are also inserted/appended from `ProjectController.swift:61-82`.
  - Search found no clear/remove method for `WindowMessagePendingVM.messages`.
- Why this can grow memory:
  - In active conversations, every selected conversation send appends to a window-level array that is not paged and not cleared on conversation switch.
  - `ChatMessage` can include images/tool calls/large content, so the retained memory can be significant.
- Trigger:
  - Long chat sessions in a single window, switching conversations after many sends, project context changes.
- Suggested fix:
  - Clarify whether `WindowMessagePendingVM` is still needed now that `WindowChatTimelineViewModel` owns paged visible state.
  - If still needed, scope it per conversation and clear it on save/conversation switch, or cap it.

### 5. LSP progress tokens can remain forever when servers do not send `end`

- Module: LSP progress state
- Path: `LumiApp/Plugins/LSPServiceEditorPlugin/LSPProgressProvider.swift`
- Risk: Medium
- Evidence:
  - `activeTasks` dictionary is keyed by server progress token at line 9.
  - `"begin"` stores a task at line 60.
  - `"end"` removes it only after a delayed task at lines 70-79.
  - There is no timeout/maximum count for in-progress entries.
- Why this can grow memory:
  - Some language servers can fail, restart, or omit `$ /progress` end notifications. Tokens then remain indefinitely.
- Trigger:
  - Long-running or crashed LSP indexing/build operations.
- Suggested fix:
  - Add TTL pruning for in-progress tasks and cap dictionary size.
  - Clear progress on transport error, server restart, document close, and `stopAll()`.

### 6. LSP service singleton holds one global document/server state across windows

- Module: LSP service
- Path: `LumiApp/Plugins/LSPServiceEditorPlugin/LSPService.swift`
- Risk: Medium-High
- Evidence:
  - `LSPService.shared` is global at line 18.
  - It stores a single `server`, `currentURI`, `latestDocumentSnapshot`, `pendingChanges`, and `projectRootPath` at lines 31-41.
  - `stopAll()` exists at lines 999-1010, but there is no observed call from window/plugin disable teardown.
- Why this can grow memory:
  - A closed window can leave the last document snapshot and server process retained unless the editor explicitly calls `closeFile()` before teardown.
  - A single shared state is also fragile for multiple windows/projects; one window can overwrite another's LSP state, leading to stale snapshots and server restarts.
- Trigger:
  - Open files across multiple windows/projects, close windows, switch projects, or disable editor/LSP-related plugins.
- Suggested fix:
  - Either make LSP service project/window scoped, or add reference tracking and explicit close/stop when the last editor using a project closes.

### 7. Request log stats fetch all records into memory

- Module: Agent request log
- Path: `LumiApp/Plugins/AgentRequestLogPlugin/Services/RequestLogHistoryManager.swift`
- Risk: Medium
- Evidence:
  - Persistent retention is capped by `maxRecords = 10000` at line 14.
  - `getStats()` fetches all request log records at line 94 and maps durations at lines 95-96.
- Why this can grow memory:
  - The permanent cap prevents unbounded growth, but every stats refresh can allocate up to 10,000 SwiftData objects plus DTO data. This is visible as repeated memory spikes and may look like growth if SwiftData retains internals.
- Trigger:
  - Opening request log status/popup repeatedly or refreshing stats during long sessions.
- Suggested fix:
  - Compute aggregate stats in the database or fetch only duration fields with a descriptor/SQL-backed aggregate.

### 8. Terminal sessions are intentionally global and not stopped on plugin disable/window close

- Module: Terminal plugin
- Paths:
  - `LumiApp/Plugins/TerminalPlugin/ViewModels/TerminalTabsViewModelSingleton.swift`
  - `Packages/TerminalCoreKit/Sources/TerminalCoreKit/ViewModels/TerminalTabsViewModel.swift`
  - `Packages/TerminalCoreKit/Sources/TerminalCoreKit/ViewModels/TerminalSession.swift`
- Risk: Medium-High
- Evidence:
  - Terminal plugin uses `TerminalTabsViewModel.shared` globally at `TerminalTabsViewModelSingleton.swift:12-14`.
  - Sessions are stored in an unbounded array at `TerminalTabsViewModel.swift:13`.
  - Closing a single tab terminates the session at `TerminalTabsViewModel.swift:57-66`.
  - `TerminalSession.terminate()` kills the shell process group at `TerminalSession.swift:130-147`.
  - There is no `closeAll` or plugin `onDisable()` cleanup for global sessions.
- Why this can grow memory/resource use:
  - Sessions persist for app lifetime even when the terminal panel is hidden. If the plugin is disabled, no cleanup hook is currently called by core lifecycle.
  - Each session holds a terminal view, scrollback, shell process, and child process tree.
- Trigger:
  - User opens many terminal tabs, hides terminal, disables plugin, or closes windows.
- Suggested fix:
  - Add `TerminalTabsViewModel.closeAllSessions()` and call it from plugin `onDisable()` and app/window teardown when desired.
  - Consider a configurable maximum number of terminal tabs or scrollback limit.

### 9. CodeServer process output handlers are not cleared on stop

- Module: CodeServer plugin
- Path: `LumiApp/Plugins/CodeServerPlugin/CodeServerManager.swift`
- Risk: Medium
- Evidence:
  - `start` installs `readabilityHandler` closures on stdout/stderr handles at lines 277-295.
  - `stop` terminates and waits for the process, then nils `process` at lines 320-327.
  - The pipe handlers are not explicitly set to `nil`.
- Why this can grow memory/resource use:
  - File handle readability handlers can retain closures and their captured objects until the handle is deallocated. Explicitly clearing them avoids stale callback chains and pipe resources.
- Trigger:
  - Repeated start/stop of code-server.
- Suggested fix:
  - Store output/error file handles or pipes as properties and set `readabilityHandler = nil` in `stop` and termination handler.
  - Consider killing process group, not only the parent process, if code-server spawns child processes.

### 10. Database connections are global and not disconnected by ViewModel deinit/plugin lifecycle

- Module: Database manager plugin
- Paths:
  - `LumiApp/Plugins/DatabaseManagerPlugin/ViewModels/DatabaseViewModel.swift`
  - `Packages/DatabaseKit/Sources/DatabaseKit/DatabaseManager.swift`
- Risk: Medium
- Evidence:
  - `DatabaseViewModel` uses `DatabaseManager.shared` at line 19.
  - `connect` stores connections globally through `manager.connect` at `DatabaseViewModel.swift:45-57`.
  - `DatabaseManager` keeps `activeConnections` and `pools` dictionaries at `DatabaseManager.swift:6-8`.
  - `disconnect` and `shutdown` exist at `DatabaseManager.swift:37-49` and `86-89`, but `DatabaseViewModel` has no `deinit`, and plugin lifecycle cleanup is not wired.
- Why this can grow memory/resource use:
  - If a database view disappears or the plugin is disabled without pressing Disconnect, connections can remain open in the shared manager.
- Trigger:
  - Connect to databases, navigate away, close windows, or disable plugin.
- Suggested fix:
  - Add `deinit` to `DatabaseViewModel` to disconnect selected connection.
  - Add plugin disable/app termination cleanup to call `DatabaseManager.shared.shutdown()`.
  - Keep agent-available connection registry consistent with disconnected configs.

### 11. MCP service has no disconnect-all API

- Module: MCPKit / AgentMCPToolsPlugin
- Paths:
  - `Packages/MCPKit/Sources/MCPKit/MCPService.swift`
  - `Packages/MCPKit/Sources/MCPKit/SubprocessTransport.swift`
  - `LumiApp/Plugins/AgentMCPToolsPlugin/AgentMCPToolsPlugin.swift`
- Risk: Medium latent
- Evidence:
  - `MCPService` stores `connectedClients`, `tools`, and `cachedTools` at lines 9-13.
  - `connect` creates clients and subprocess/SSE transports at lines 32-67.
  - `SubprocessTransport.disconnect()` terminates the process at `SubprocessTransport.swift:94-98`.
  - `MCPService` has no `disconnectAll()` or cache cleanup.
  - Current plugin returns no tools and does not auto-connect at `AgentMCPToolsPlugin.swift:30-40`.
- Why this can grow memory/resource use:
  - Once MCP is enabled, clients/transports/subprocesses can stay connected for app lifetime with no plugin disable cleanup.
- Trigger:
  - Future MCP auto-connect or manual connect support.
- Suggested fix:
  - Add `MCPService.disconnectAll()` that closes all clients/transports, clears `connectedClients`, `cachedTools`, and `tools`, then publishes an empty tool list.
  - Call from plugin `onDisable()` and app termination.

## Lower Risk / Bounded Areas Observed

- `AgentChatPlugin` message rendering metadata is capped at 512 entries in `MessageRenderCache`.
- `WindowChatTimelineViewModel` loads messages by pages of 10 and clears conversation-specific tool output state on conversation switch.
- `ToolService` notification observers are removed in `deinit`; this is acceptable if the service is not recreated often.
- `DeviceData` and several DeviceInfo view models stop timers/services in `deinit`; risk depends on whether cached `AnyView`s keep those view models alive.

## Verification Scenarios

1. Open and close 20 windows with projects and editor tabs; watch object graph for retained `WindowScope`, `WindowEditorVM`, `EditorService`, and LSP objects.
2. Start a send, close the window mid-turn, repeat 20 times; verify `activeSendTasksByConversation` and `WindowScope` release.
3. Send 200 messages in one conversation and switch conversations repeatedly; inspect `WindowMessagePendingVM.messages`.
4. Toggle configurable plugins, especially Clipboard, AppUpdateStatusBar, CodeServer, Database, Terminal; verify `onDisable()` is called after core fix.
5. Open LSP-backed files across two windows/projects, close one window, and inspect `LSPService.latestDocumentSnapshot`, server process count, and progress tokens.
6. Start/stop code-server 20 times; inspect file descriptors and retained `CodeServerManager` pipe handlers.
7. Connect/disconnect databases and close the database view without pressing disconnect; inspect `DatabaseManager.activeConnections`.
8. Open many terminal tabs, hide the terminal panel, close windows, then inspect shell process tree and terminal scrollback memory.

## Priority Fix Order

1. Implement real plugin enable/disable transitions in `AppPluginVM`.
2. Add `WindowScope.cleanup()` and call it from `WindowManagerVM.unregisterScope`.
3. Remove or cap `WindowMessagePendingVM.messages`.
4. Add explicit teardown for editor/LSP on window close.
5. Add terminal/database/code-server cleanup hooks.
6. Add TTL/cap for LSP progress tasks.
7. Change request log stats to aggregate without fetching all records.
8. Add MCP disconnect-all before enabling MCP tools.
