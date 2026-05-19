# DatabaseKit

可复用的数据库抽象层（SwiftPM 包）。对不同数据库驱动做一致封装，供任意宿主应用复用。

## Package

- Product: `DatabaseKit`
- Platform: macOS 14+
- Swift tools: 6.0

## 提供什么

- **统一的数据库访问接口**：对不同数据库驱动做一致封装（如 MySQL / PostgreSQL / SQLite 等）。
- **连接/连接池管理**：对连接创建与复用做集中管理。
- **面向上层业务的轻量 API**：避免业务直接依赖具体驱动实现细节。

## 依赖

- **mysql-nio / postgres-nio / swift-nio / swift-log**（见 `Package.swift`）

## 依赖与集成

```swift
dependencies: [
    .package(path: "../DatabaseKit"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["DatabaseKit"]),
]
```

## 基本示例

DatabaseKit 不会自动注册内置驱动；调用方需要显式注册需要使用的驱动。

```swift
import DatabaseKit

let manager = DatabaseManager()

await manager.register(driver: SQLiteDriver())
await manager.register(driver: MySQLDriver())
await manager.register(driver: PostgreSQLDriver())
await manager.register(driver: RedisDriver())
```

### 直接连接

```swift
let config = DatabaseConfig(
    name: "Local SQLite",
    type: .sqlite,
    database: "/tmp/example.sqlite"
)

let connection = try await manager.connect(config: config)
defer {
    Task {
        await manager.disconnect(configId: config.id)
    }
}

_ = try await connection.execute(
    "CREATE TABLE IF NOT EXISTS items (id INTEGER PRIMARY KEY, name TEXT)",
    params: nil
)

let inserted = try await connection.execute(
    "INSERT INTO items (name) VALUES (?)",
    params: [.string("example")]
)

let result = try await connection.query(
    "SELECT id, name FROM items WHERE name = ?",
    params: [.string("example")]
)
```

### 连接池

```swift
let pool = try await manager.getPool(for: config)
let connection = try await pool.acquire()

do {
    let result = try await connection.query("SELECT 1", params: nil)
    await pool.release(connection)
} catch {
    await pool.release(connection)
    throw error
}

await pool.shutdown()
```

`ConnectionPool` 会复用仍然存活的 idle 连接，达到 `maxConnections` 后新的 `acquire()` 会等待已有连接释放。调用方仍然负责在用完连接后调用 `release(_:)`。如果传入小于 1 的 `maxConnections`，连接池会按 1 处理，避免 acquire 永久等待。连接池会跟踪自己创建的连接，重复 release 会被忽略，释放非本池连接时会直接关闭该连接而不是放入池内。

如果需要调整连接池大小，创建池时传入 `maxConnections`：

```swift
let pool = try await manager.getPool(for: config, maxConnections: 10)
```

### 事务

```swift
let transaction = try await connection.beginTransaction()

do {
    _ = try await transaction.execute(
        "INSERT INTO items (name) VALUES (?)",
        params: [.string("transactional")]
    )
    try await transaction.commit()
} catch {
    try? await transaction.rollback()
    throw error
}
```

### 探测配置

```swift
try await manager.probe(config: config)
```

`probe` 会创建一个临时连接并立即关闭，不会把连接保存到 `DatabaseManager`。

### 关闭资源

```swift
await manager.disconnect(configId: config.id)
await manager.disconnectAll()

await manager.shutdownPool(configId: config.id)
await manager.shutdownAllPools()

await manager.shutdown()
```

`shutdown()` 会关闭 `DatabaseManager` 当前追踪的连接和连接池，适合应用退出、workspace 切换或测试 teardown 时调用。

## 参数占位符

- SQLite 使用 `?`，例如 `WHERE name = ?`。
- MySQL 使用 `?`，例如 `WHERE name = ?`。
- PostgreSQL 使用 `$1`, `$2`，例如 `WHERE name = $1 AND age = $2`。
- Redis 的 `execute` / `query` 接收 Redis 命令字符串，支持双引号、单引号和反斜杠转义，例如 `SET greeting "hello world"`；`params` 会作为额外 RESP 参数追加到命令后，例如 `execute("SET", params: [.string("key"), .string("value")])`。

查询结果会尽量保留列元数据；PostgreSQL 即使查询结果为空，也会返回服务端提供的列名。
Redis 查询会把 RESP null bulk string 映射为 `DatabaseValue.null`，UTF-8 bulk string 映射为 `.string`，非 UTF-8 bulk string 映射为 `.data`。

## 生命周期和限制

- `DatabaseManager` 是 actor，可以安全地跨并发任务注册驱动、创建连接和获取连接池。
- 对同一个 `DatabaseConfig.id` 重复调用 `connect(config:)` 时，manager 会先关闭旧连接再保存新连接。
- `DatabaseConnection` 实现通常是 actor，单个连接上的操作会串行化。
- `ConnectionPool` 只管理连接复用和上限，不会自动归还泄漏的连接。
- `DatabaseManager.shutdown()` 只关闭它追踪到的连接和池；如果调用方直接持有并绕过 manager 创建连接，仍然需要自行关闭。
- MySQL、PostgreSQL、Redis 的真实服务覆盖依赖 opt-in 集成测试；默认 `swift test` 不要求本机有这些服务。
- Redis 事务使用 `MULTI` / `EXEC` / `DISCARD` 实现；事务对象只支持通过 `execute` 排队命令。

## Testing

From this package directory:

```sh
swift test
```

## Integration tests

默认测试不连接外部数据库。需要验证真实驱动时，设置对应环境变量后再运行 `swift test`。

MySQL:

```bash
export DATABASEKIT_MYSQL_HOST=127.0.0.1
export DATABASEKIT_MYSQL_PORT=3306
export DATABASEKIT_MYSQL_DATABASE=testdb
export DATABASEKIT_MYSQL_USERNAME=testuser
export DATABASEKIT_MYSQL_PASSWORD=testpass
swift test
```

PostgreSQL:

```bash
export DATABASEKIT_POSTGRES_HOST=127.0.0.1
export DATABASEKIT_POSTGRES_PORT=5432
export DATABASEKIT_POSTGRES_DATABASE=testdb
export DATABASEKIT_POSTGRES_USERNAME=testuser
export DATABASEKIT_POSTGRES_PASSWORD=testpass
swift test
```

Redis:

```bash
export DATABASEKIT_REDIS_HOST=127.0.0.1
export DATABASEKIT_REDIS_PORT=6379
export DATABASEKIT_REDIS_PASSWORD=
swift test
```
