# ProjectFilesPlugin

Project Files plugin for Lumi. It reads the current project state from `ProjectProviding`, shows the project's open files, and lets the user switch the current file.

## Responsibilities

- Display files from `openFileURLs`
- Highlight the active `currentFileURL`
- Update the active file through `ProjectProviding`
- Expose current-file agent tools

## Structure

```
ProjectFilesPlugin/
├── Package.swift
├── README.md
├── Sources/
│   ├── ProjectFilesPlugin.swift
│   ├── ProjectFilesState.swift
│   ├── Tools/
│   │   ├── GetCurrentFileTool.swift
│   │   └── SetCurrentFileTool.swift
│   └── Views/
│       ├── ProjectFileItemView.swift
│       └── ProjectFilesHeaderView.swift
└── Tests/
```
