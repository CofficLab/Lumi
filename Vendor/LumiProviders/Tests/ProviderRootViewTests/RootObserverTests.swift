import SwiftUI
import Testing
@testable import ProviderRootView

/// 观察者生命周期。
///
/// provider 只保留观察者的弱引用：句柄被释放后回调立即停止投递，
/// 不会残留闭包把捕获的对象钉住。这与 `RailViewProviding` /
/// `CommandProviding` 的行为一致。
@Suite("RootView 观察者")
@MainActor
struct RootObserverTests {

    @Test("多个观察者都收到事件")
    func multipleObserversReceive() {
        let provider = DefaultRootViewProviding()
        var first = 0
        var second = 0
        let a = provider.addRootViewObserver { _ in first += 1 }
        let b = provider.addRootViewObserver { _ in second += 1 }

        provider.setContentView(AnyView(Text("c")))

        #expect(first == 1)
        #expect(second == 1)
        a.cancel()
        b.cancel()
    }

    @Test("cancel 后不再收到事件且幂等")
    func cancelStopsAndIsIdempotent() {
        let provider = DefaultRootViewProviding()
        var count = 0
        let handle = provider.addRootViewObserver { _ in count += 1 }

        provider.setContentView(AnyView(Text("c")))
        #expect(count == 1)

        handle.cancel()
        handle.cancel()
        provider.setContentView(AnyView(Text("d")))

        #expect(count == 1)
    }

    @Test("句柄释放后自动停止接收（弱引用）")
    func deallocatedHandleStops() {
        let provider = DefaultRootViewProviding()
        var count = 0
        do {
            let _ = provider.addRootViewObserver { _ in count += 1 }
        }

        provider.setContentView(AnyView(Text("c")))

        #expect(count == 0)
    }

    @Test("显式 cancel 后立即停止接收")
    func explicitCancelStopsImmediately() {
        let provider = DefaultRootViewProviding()
        var count = 0
        let handle = provider.addRootViewObserver { _ in count += 1 }

        provider.setContentView(AnyView(Text("a")))
        #expect(count == 1)

        handle.cancel()
        provider.setContentView(AnyView(Text("b")))

        #expect(count == 1)
    }

    @Test("释放的观察者不会把捕获对象钉住")
    func releasedObserverDoesNotRetainCapturedObject() {
        final class Probe {}
        weak var weakProbe: Probe?
        let provider = DefaultRootViewProviding()

        do {
            let probe = Probe()
            weakProbe = probe
            let _ = provider.addRootViewObserver { _ in _ = probe }
        }

        #expect(weakProbe == nil)
        // 触发一次事件，确保 prune 路径可正常执行。
        provider.setContentView(AnyView(Text("c")))
        #expect(weakProbe == nil)
    }

    @Test("emitRootViewEvent 可由子类主动发布")
    func subclassesCanEmitEvents() {
        final class Custom: DefaultRootViewProviding {
            func emitCustom() {
                emitRootViewEvent(.railViewChanged)
            }
        }
        let provider = Custom()
        var events = 0
        let handle = provider.addRootViewObserver { _ in events += 1 }

        provider.emitCustom()

        #expect(events == 1)
        handle.cancel()
    }

    @Test("convenience init(kernel:) 可用")
    func kernelConvenienceInit() {
        struct DummyKernel {}
        let provider = DefaultRootViewProviding(kernel: DummyKernel())

        #expect(provider.overlays.isEmpty)
        #expect(provider.contentFooterHeight == .standard)
    }
}
