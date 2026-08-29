# Lumi Editor Workspace Design

## Goal

Lumi shall expose a complete, plugin-controlled code workspace. When the user enables the Code Editor plugin, an editor entry appears in the Activity Bar. Activating it shows the current project's file explorer in the Rail and a tabbed source editor in the main content area. Users can open, edit, save, auto-save, close, and restore files with syntax highlighting and clear dirty, loading, read-only, conflict, and error states.

## Product boundary

The first release targets the daily editing loop rather than every VS Code subsystem. It includes project file browsing, lazy folder expansion, multiple tabs, active-tab restoration, breadcrumbs, find/replace, line numbers, folding, minimap, syntax highlighting, manual save, configurable auto-save, external-change conflict protection, keyboard shortcuts, and an editor status bar. It does not include an extension marketplace, debugger, integrated terminal ownership, or remote workspaces; those remain separate Lumi plugins.

The initial built-in language set is Swift, JavaScript/TypeScript, JSON, Markdown, Python, Shell, and YAML. The language registry remains open so future language plugins can contribute grammars and LSP configuration without changing the workspace plugin.

## Architecture

The implementation uses two plugins with different lifecycles:

- `PluginEditorHost` is required infrastructure. It remains UI-neutral and owns the single `EditorService`, the V2 editor contract adapter, the standard source-editor surface, and the embedded editor provider used by feature plugins.
- `PluginCodeEditor` is user-facing and `disabledByDefault`. Its `onBoot` registers one Activity Bar item. Activating the Activity Bar item installs the editor workbench into `ContentViewProviding` and activates the canonical `PluginProjectFileTree` Rail group. `onShutdown` removes every contribution and clears the content only when the editor owns it.

`FactoryLumi` includes both plugins. The host boots before language and workspace plugins. Enabling or disabling the workspace therefore changes only visible workspace contributions and does not invalidate embedded editors used elsewhere.

## Components and data flow

`EditorWorkspaceController` observes `ProjectProviding`, `EditorService`, and `EditorSessionStore`. The current project path is the authoritative workspace root. Project changes update `EditorService.projectRootPath`, restore that project's tabs, and select its current file. The existing `PluginProjectFileTree` owns the canonical project explorer and file selection; editor session changes are mirrored back to `ProjectProviding.openFileURLs` and `currentFileURL`, preserving the existing Projects persistence format.

`PluginProjectFileTree` owns cancellable directory enumeration, folder expansion, selection, and file operations. The editor workspace consumes its selected-file/project provider contract and does not duplicate the file-tree implementation.

`EditorWorkbenchView` contains a tab strip, optional breadcrumb row, editor surface, empty/loading/error states, and status bar. The editor surface binds `SourceEditor` to the active `EditorState`, preserving its existing coordinators, highlighter, find/replace, multi-cursor, folding, minimap, completion, and LSP bridges. Dirty tabs show a marker; close requests use the existing save workflow and never silently discard changes.

## Saving and external changes

Cmd-S invokes `EditorService.files.saveNow()`. Auto-save uses the existing editor auto-save scheduler and persisted configuration. Successful saves update the tab dirty state and send LSP `didSave`. Save failures remain dirty and surface a visible error. External changes reload clean buffers automatically; dirty buffers enter the existing conflict workflow and require an explicit user choice before overwrite or reload.

Binary, truncated, and mega files open in read-only mode with an explanatory banner. Unsupported text encodings and permission failures produce recoverable error states rather than an empty editor.

## Language support

Language support is contributed through `EditorExtensionRegistry`. Each built-in language contributes an `EditorLanguageDescriptor`, Tree-sitter grammar provider, highlight queries, comment syntax, file extensions, and optional LSP discovery. Missing grammar or language server never prevents editing: the editor falls back to plain text and reports LSP as unavailable in the status bar.

Language support is packaged separately from the workspace shell so it can be tested and expanded independently. Swift uses SourceKit-LSP discovery; other LSP integrations are opportunistic and must not block plugin boot.

## Verification

Package tests cover plugin lifecycle registration and removal, file-tree ordering and filtering, lazy expansion, project/session synchronization, tab activation and close behavior, dirty-state protection, save/error state mapping, and language detection. Integration tests start a real `KernelCoreContainer` with host and workspace plugins and assert that enabling the workspace contributes Activity Bar/Rail/content views.

The final gate is an unsigned Debug build of the Lumi scheme plus a macOS UI smoke test: enable plugin, activate editor, choose project, expand tree, open two files, verify highlighting, edit both, save with Cmd-S, confirm disk contents, trigger an external modification, close/reopen the app, and verify session restoration.
