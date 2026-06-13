# EditorGoCore

EditorGoCore provides the Go-specific editor domain logic used by Lumi.

## 全局技术架构

Lumi 代码编辑器采用分层 + 插件扩展架构。完整说明见 [docs/editor-architecture.md](../../docs/editor-architecture.md)。

```text
应用装配层 (LumiApp)
    ↓
插件扩展层 (Plugins/Editor*, LSP*)
    │  EditorGoPlugin
    │      ↓
    │  EditorGoCore  ← 本 Package（邻接模块）
    ↓
服务门面层 (EditorService)
    ↓                    ↓
视图层 (EditorSource)   内核逻辑层 (EditorKernel)
    ↓
渲染基础层 (EditorTextView, EditorLanguages, EditorSymbols)
```

## 本 Package 的位置

| 属性 | 值 |
|------|-----|
| **层级** | 邻接模块（Go 语言领域） |
| **职责** | Go 模块/工作区检测、工具链解析、构建/测试命令描述、输出解析、轻量补全与格式化辅助 |
| **上游依赖** | `ShellKit` |
| **下游消费者** | `EditorGoPlugin`（语言插件，向 `EditorExtensionRegistry` 注册 LSP 与命令） |
| **说明** | 不属于主编辑链路的核心分层；是语言专属领域逻辑，供对应语言插件消费 |

## Features

- Detects Go modules and optional `go.work` workspaces.
- Resolves Go toolchain paths and process environment values.
- Builds standard `go build`, `go test`, `go fmt`, and `go mod tidy` command descriptors.
- Parses Go build output and `go test -json` events.
- Provides lightweight completion, inlay hint, code lens, format-on-save, and Delve launch helpers.

## Usage

```swift
import EditorGoCore

if let project = GoProjectDetector.findProject(from: "/path/to/app/main.go") {
    print(project.rootPath)
}

let command = GoTestCommand.allPackagesJSON
print(command.command, command.arguments)
```

## Testing

```bash
swift test
```
