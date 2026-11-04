# KitLumiCLI

`lumi` 命令行工具的安装包。负责挑选安装目录、生成脚本、写入磁盘与查询安装状态。

## Package

- Product: `KitLumiCLI`
- Platform: macOS 14+
- Swift tools: 6.0

## Basic Usage

查询当前安装状态：

```swift
import KitLumiCLI

let status = CLIInstaller.status()
print(status.installedPath?.path ?? "未安装")
```

安装到默认目标目录：

```swift
switch CLIInstaller.install() {
case .installed(let target):
    print("已安装到 \(target.directory.path)")
case .installedButNotOnPath(let target):
    print("已安装到 \(target.directory.path)，该目录不在 PATH 中")
case .failed(let reason):
    print("安装失败：\(reason)")
}
```

卸载：

```swift
CLIInstaller.uninstall()
```

## 行为约定

- **不需要管理员权限**：只写入用户可写目录，不修改用户的 shell 配置。
- **复用既有协议**：脚本投递 `lumi://finder/open-project?path=…`，
  由 Lumi 既有的 Finder 命令处理流程打开目录为项目。
- **路径编码**：脚本用 `/usr/bin/perl -MURI::Escape` 做百分号编码，
  App 侧用 `URLComponents` 解析，两侧必须可互相还原。
- **显式指定 App**：脚本通过 `open -g -a <App>` 投递 URL，
  避免依赖 URL scheme 的系统路由（同一 scheme 多版本共存时不稳定）。

## Testing

```bash
swift test
```
