import Foundation
import Testing
@testable import ProviderToast

/// ToastProviding 协议与 LumiToast 模型的基础验证。
@Suite("ProviderToast")
@MainActor
struct ProviderToastTests {

    /// 测试用实现：记录收到的 Toast。
    private final class RecordingToastProvider: ToastLoadingProviding {
        var received: [LumiToast] = []
        var loading: LumiLoadingNotice?

        func show(_ toast: LumiToast) {
            received.append(toast)
        }

        func presentError(title: String, message: String, sourceWindowID: String?) {}

        func dismissError() {}
        func showLoading(title: String, detail: String?) {
            loading = LumiLoadingNotice(title: title, detail: detail)
        }
        func dismissLoading() { loading = nil }
        func dismissAll() { loading = nil }
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

    @Test("LumiErrorNotice 可创建且 Equatable")
    func errorNoticeValueSemantics() {
        let id = UUID()
        let a = LumiErrorNotice(id: id, title: "错误", message: "详细信息")
        let b = LumiErrorNotice(id: id, title: "错误", message: "详细信息")

        #expect(a == b)
        #expect(a.id == id)
        #expect(a.title == "错误")
        #expect(a.message == "详细信息")
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

    @Test("ToastProviding 错误通知便捷接口可安全调用")
    func errorNoticeMethodsAreAvailable() {
        let provider: any ToastProviding = RecordingToastProvider()

        provider.presentError(title: "错误", message: "详细信息")
        provider.dismissError()
    }

    @Test("ToastLoadingProviding 提供兼容的 loading 能力")
    func loadingMethodsAreAvailable() {
        let provider = RecordingToastProvider()

        provider.showLoading(title: "加载中", detail: "正在准备")

        #expect(provider.loading?.title == "加载中")
        #expect(provider.loading?.detail == "正在准备")
        provider.dismissLoading()
        #expect(provider.loading == nil)
    }

    // MARK: - DefaultToastProviding

    @Test("DefaultToastProviding 为 no-op，不抛错")
    func defaultToastProvidingIsNoOp() {
        let provider: any ToastProviding = DefaultToastProviding()

        // 不应抛错、不应崩溃（契约：非阻塞、不抛错）
        provider.show("hello")
        provider.show(LumiToast(title: "hello", detail: "d", style: .error))
    }
}
