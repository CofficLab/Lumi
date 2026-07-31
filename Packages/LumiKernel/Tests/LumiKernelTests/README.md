# LumiKernel 测试目录

测试目录与内核模块(**`Sources/LumiKernel/`**)一一对应 —— 找位置零思考。

## 目录与归属

| 测试目录 | 内核模块 | 放什么 |
|---|---|---|
| `Core/` | `LumiKernel.swift` / `Managers/` | 内核容器本身:服务注册表、解析、启动校验;`BuiltinPluginManager`/`EventManager` |
| `Coordinators/` | `Coordinators/` | 协调层:装配契约(`LumiCoordinator`)+ 各协调器的编排规则 |
| `Providers/` | `Providers/` | 各能力协议的契约测试:注册/解析/可选语义 |
| `Services/` | `Services/` | 内核内置服务实现(如 `ModelUsageStats`、`LumiMessageSender` 的规则) |
| `Types/` | `Types/` | 纯值类型 / DTO / 编解码(无内核状态依赖) |
| `Support/` | — | 跨测试共享的 mock 与夹具 |

## Support(共享基础设施)

- `Support/Mocks/` —— **唯一的 mock 仓库**。每个 mock 一个文件,`internal`(经 `@testable` 可访问)。
  禁止在测试文件里内联 mock,统一来这里加。命名:`Mock<协议名>`。
- `Support/Fixtures/` —— 把多个 mock + 公共构造打包的夹具(如 `SendPipelineFixture`),
  以及 `KernelTestKit`(内核测试公共构造工具)。

## 新增测试的步骤

1. 先判断它属于哪个内核模块 → 进入对应子目录。
2. 夹具/mock 复用 `Support/`;若需新 mock,加到 `Support/Mocks/` 而非内联。
3. 测试名用中文描述(挂在 `@Test("…")` 上),Suite 名用英文模块名,便于 `swift test --filter` 定位。

## 规范

- 测试只依赖**协议/契约**,不依赖具体实现(实现多在插件层,内核侧测不到,属正常边界)。
- 一个 `@Suite` 对应一个内核单元(一个协议 / 一个协调器 / 一个服务)。
