# EditorService

Lumi 使用的编辑器服务包。

## 运行测试

### 推荐方式（Xcode 工具链）

在本仓库中，推荐优先通过 Xcode（Test Navigator）运行 `EditorServiceTests`。

命令行推荐使用（已验证可运行）：

```bash
xcodebuild \
  -workspace "Lumi.xcodeproj/project.xcworkspace" \
  -scheme "EditorServiceTests" \
  -destination "platform=macOS" \
  test
```

如果需要覆盖率：

```bash
xcodebuild \
  -workspace "Lumi.xcodeproj/project.xcworkspace" \
  -scheme "EditorServiceTests" \
  -destination "platform=macOS" \
  -enableCodeCoverage YES \
  test
```

### `swift test` 已知问题

在当前仓库中，`swift test` 可能因为上游第三方依赖链
`CodeEditSourceEditor -> CodeEditSymbols` 的资源打包问题而失败。

典型报错：

```text
error: type 'Bundle' has no member 'module'
```

根因是纯 SwiftPM CLI 构建流程与 Xcode 集成构建流程在资源打包行为上存在差异。

因此，为了保证本项目本地和 CI 的稳定性，建议优先使用 `xcodebuild test`。
