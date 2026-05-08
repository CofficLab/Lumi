# DatabaseKit

Lumi 内部使用的数据库抽象层（SwiftPM 包）。

## 提供什么

- **统一的数据库访问接口**：对不同数据库驱动做一致封装（如 MySQL / PostgreSQL / SQLite 等）。
- **连接/连接池管理**：对连接创建与复用做集中管理。
- **面向上层业务的轻量 API**：避免业务直接依赖具体驱动实现细节。

## 依赖

- **mysql-nio / postgres-nio / swift-nio / swift-log**（见 `Package.swift`）

## 使用方式

在其他 SwiftPM 包的 `Package.swift` 中添加依赖：

```swift
.package(path: "../DatabaseKit")
```

然后在目标依赖中引入：

```swift
.product(name: "DatabaseKit", package: "DatabaseKit")
```

## 运行测试

```bash
cd Packages/DatabaseKit
swift test
```

