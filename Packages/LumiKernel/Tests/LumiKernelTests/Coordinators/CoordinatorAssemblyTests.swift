import Foundation
import Testing
@testable import LumiKernel

/// 协调层骨架测试(`LumiCoordinator` / `LumiCoordinatorRegistry`)
///
/// 当前没有内置协调器(发送等链路由插件实现),本套件只覆盖协调层骨架契约:
/// 注册表的可扩展性、`startAll` 的依赖校验 fail-fast。
///
/// 将来某条"纯内核实现"的联动链登记为 `LumiCoordinator` 后,在此补充其装配与
/// 编排规则测试;发送链的编排测试当前随插件实现移除(插件层测试另立)。
@MainActor
@Suite("Coordinator Assembly")
struct CoordinatorAssemblyTests {
    @Test("makeDefault 当前为空注册表(发送等链路由插件实现)")
    func makeDefaultIsEmpty() throws {
        let registry = LumiCoordinatorRegistry.makeDefault()
        #expect(registry.coordinators.isEmpty)
    }

    @Test("startAll 在空注册表上是 no-op,不抛错")
    func startAllEmptyIsNoOp() throws {
        let kernel = KernelTestKit.makeKernel()
        let registry = LumiCoordinatorRegistry()

        // 无协调器 → 循环不执行,正常返回。
        try registry.startAll(kernel: kernel)
    }

    @Test("自定义协调器可注册并被 startAll 装配")
    func customCoordinatorRuns() throws {
        let kernel = KernelTestKit.makeKernel()
        let registry = LumiCoordinatorRegistry()
        let coordinator = SpyCoordinator()

        registry.register(coordinator)
        try registry.startAll(kernel: kernel)

        #expect(coordinator.startCount == 1)
    }

    @Test("协调器依赖缺失时 startAll fail-fast,错误信息含协调器 id")
    func missingDependencyFailsFast() throws {
        let kernel = KernelTestKit.makeKernel()
        let registry = LumiCoordinatorRegistry()
        // 声明依赖一个未注册的服务。
        let coordinator = SpyCoordinator(
            requiredServices: [.init(StorageProviding.self, name: "NeverRegistered")]
        )
        registry.register(coordinator)

        #expect(throws: LumiKernelError.self) {
            try registry.startAll(kernel: kernel)
        }
        // 依赖缺失 → start 未被调用。
        #expect(coordinator.startCount == 0)
    }
}

// MARK: - 测试用协调器

/// 记录 start 调用次数的协调器,可配置 requiredServices 以测试 fail-fast。
@MainActor
private final class SpyCoordinator: LumiCoordinator {
    let id = "test.spy-coordinator"
    var requiredServices: [LumiServiceRequirement]
    private(set) var startCount = 0

    init(requiredServices: [LumiServiceRequirement] = []) {
        self.requiredServices = requiredServices
    }

    func start(kernel: LumiKernel) throws {
        startCount += 1
    }
}
