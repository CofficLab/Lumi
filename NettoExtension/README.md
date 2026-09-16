# NettoExtension

Netto 浏览器扩展入口。

## 结构

| 文件 | 说明 |
|------|------|
| `main.swift` | 扩展入口 |
| `FilterDataProvider.swift` | 过滤数据提供器 |
| `Info.plist` | 扩展信息 |
| `NettoExtension.entitlements` | 扩展权限 |
| `Signing.entitlements` | 签名权限 |

## 构建

```sh
xcodebuild -project Lumi.xcodeproj -scheme NettoExtension -destination 'platform=macOS' build
```
