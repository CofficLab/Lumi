import Foundation
import Testing
@testable import ProviderToast

/// ToastProviding 协议与 LumiToast 模型的基础验证。
@Suite("ProviderToast")
@MainActor
struct ProviderToastTests {

    /// 测试用实现：记录收到的 Toast。
    private final class RecordingToastProvider: ToastProviding {
        var received: [LumiToast] = []

        func show(_ toast: LumiToast) {
            received.append(toast)
        }
    }

    @Test("LumiToast 可创建且 Equatable")
    func toastValueSemantics() {
        let a = LumiToast(title: "hi", detail: "d", style: .warning, duration: 2)
        let b = LumiToast(title: "hi", detail: "d", style: .warning, duration: 2)
        let c = LumiToast(title: "hi", detail: "d", style: .error, duration: 2)

        #expect(a == b)
        #expect(a != c)
        #expect(a.style == .warning)
    }

    @Test("便捷 show 方法构造正确的 LumiToast")
    func convenienceShowBuildsToast() {
        let provider = RecordingToastProvider()

        provider.show("保存成功", style: .success)

        #expect(provider.received.count == 1)
        #expect(provider.received[0].title == "保存成功")
        #expect(provider.received[0].detail == nil)
        #expect(provider.received[0].style == .success)
        #expect(provider.received[0].duration == nil)
    }

    @Test("ToastProviding 可作为 any ToastProviding 使用")
    func providerAccessibleThroughProtocol() {
        let provider: any ToastProviding = RecordingToastProvider()

        provider.show(LumiToast(title: "hello"))

        let recording = provider as! RecordingToastProvider
        #expect(recording.received.count == 1)
        #expect(recording.received[0].title == "hello")
    }
}
