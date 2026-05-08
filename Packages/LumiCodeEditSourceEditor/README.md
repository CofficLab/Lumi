# LumiCodeEditSourceEditor

本仓库内维护的第三方包（源自 CodeEditApp 的 `CodeEditSourceEditor`），用于提供编辑器 UI 与文本编辑能力（syntax highlight / tree-sitter / 查找替换等）。

### 我们用它做什么

- `EditorService` 通过它提供的组件把内核能力落到具体的编辑器视图实现上。
- 该包依赖 `LumiCodeEditSymbols`（本仓库内维护）以提供编辑器相关图标资源。

### 运行测试

```bash
cd Packages/LumiCodeEditSourceEditor
swift test
```

### 上游文档（英文）

更详细的用法与 API 文档请参考上游项目文档：

- `https://codeeditapp.github.io/CodeEditSourceEditor/documentation/codeeditsourceeditor/`
