import Foundation
import Testing
@testable import KernelCore

/// 容器本身(KernelCoreContainer)的测试:Provider 注册表的注册/解析/注销语义。
///
/// 模块对应:`Sources/KernelCore/KernelCore.swift` 的 Provider Registry。
/// 具体 Provider 协议不属于 KernelCore,因此这里用测试内私有协议验证泛型机制。
@Suite("KernelCore Provider Registry")
@MainActor
struct KernelCoreRegistryTests {

    // MARK: - 测试用 Provider 协议(仅用于测试,不属于 KernelCore)

    private protocol GreetingProviding: AnyObject {
        func greet() -> String
    }

    private final class MockGreeting: GreetingProviding {
        func greet() -> String { "hello" }
    }

    private protocol CountingProviding: AnyObject {
        var count: Int { get }
    }

    private final class MockCounter: CountingProviding {
        var count = 0
    }

    // MARK: - 注册 / 解析

    @Test("注册后可通过同类型解析")
    func registerAndResolve() throws {
        let core = KernelCoreContainer()
        let greeting = MockGreeting()

        try core.registerProvider(GreetingProviding.self, greeting)

        let resolved = core.resolveProvider(GreetingProviding.self)
        #expect(resolved != nil)
        #expect(resolved as? MockGreeting === greeting)
    }

    @Test("默认类型参数推断:T.self 可省略")
    func resolveWithInferredType() throws {
        let core = KernelCoreContainer()
        try core.registerProvider(GreetingProviding.self, MockGreeting())

        // resolveProvider() 无参时从赋值目标推断 T
        let resolved: (any GreetingProviding)? = core.resolveProvider()
        #expect(resolved != nil)
    }

    @Test("重复注册同类型抛错")
    func duplicateRegistrationThrows() throws {
        let core = KernelCoreContainer()
        try core.registerProvider(GreetingProviding.self, MockGreeting())

        #expect(throws: KernelCoreError.self) {
            try core.registerProvider(GreetingProviding.self, MockGreeting())
        }
        #expect(core.registeredProviderCount == 1)
    }

    @Test("未注册类型解析为 nil")
    func resolveMissingReturnsNil() {
        let core = KernelCoreContainer()
        #expect(core.resolveProvider(GreetingProviding.self) == nil)
        #expect(!core.isProviderRegistered(GreetingProviding.self))
        #expect(core.registeredProviderCount == 0)
    }

    @Test("不同协议类型互不干扰")
    func distinctTypesAreIndependent() throws {
        let core = KernelCoreContainer()
        let greeting = MockGreeting()
        let counter = MockCounter()

        try core.registerProvider(GreetingProviding.self, greeting)
        try core.registerProvider(CountingProviding.self, counter)

        #expect(core.resolveProvider(GreetingProviding.self) as? MockGreeting === greeting)
        #expect(core.resolveProvider(CountingProviding.self) as? MockCounter === counter)
        #expect(core.registeredProviderCount == 2)
    }

    // MARK: - 注销

    @Test("注销后不可再解析")
    func unregisterRemovesProvider() throws {
        let core = KernelCoreContainer()
        try core.registerProvider(GreetingProviding.self, MockGreeting())

        core.unregisterProvider(GreetingProviding.self)

        #expect(core.resolveProvider(GreetingProviding.self) == nil)
        #expect(!core.isProviderRegistered(GreetingProviding.self))
    }

    @Test("注销未注册类型为幂等 no-op")
    func unregisterMissingIsNoOp() {
        let core = KernelCoreContainer()
        core.unregisterProvider(GreetingProviding.self)
        #expect(core.registeredProviderCount == 0)
    }

    // MARK: - 观察边界

    @Test("Provider 变化不改变 Kernel 注册表")
    func providerChangesDoNotAffectRegistry() throws {
        let core = KernelCoreContainer()
        let counter = MockCounter()
        try core.registerProvider(CountingProviding.self, counter)

        counter.count = 1

        #expect(core.registeredProviderCount == 1)
        #expect(core.resolveProvider(CountingProviding.self) as? MockCounter === counter)
    }

    // MARK: - 非 ObservableObject 的 Provider

    @Test("非 ObservableObject 的 Provider 也可注册与解析")
    func plainProviderWorks() throws {
        let core = KernelCoreContainer()
        let greeting = MockGreeting()

        try core.registerProvider(GreetingProviding.self, greeting)

        #expect(core.resolveProvider(GreetingProviding.self)?.greet() == "hello")
    }
}
