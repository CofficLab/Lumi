import Foundation
import Testing
@testable import ProviderToast

/// ToastProviding 便捷 API（`info` / `success` / `warning` / `error`）的契约测试。
///
/// 这些方法是业务插件的主要调用入口，必须稳定映射到持久化错误或瞬时 toast：
/// - `error` 不带时长 → 持久化错误面板；
/// - `error` 带时长 → 瞬时 `.error` toast；
/// - `info` / `success` / `warning` 使用各自默认时长。
@Suite("ProviderToast conveniences")
@MainActor
struct ToastProvidingConvenienceTests {

    /// 记录所有调用的测试替身。
    private final class RecordingProvider: ToastProviding {
        var shown: [LumiToast] = []
        var errors: [(title: String, message: String, sourceWindowID: String?)] = []
        var dismissErrorCount = 0

        func show(_ toast: LumiToast) {
            shown.append(toast)
        }

        func presentError(title: String, message: String, sourceWindowID: String?) {
            errors.append((title, message, sourceWindowID))
        }

        func dismissError() {
            dismissErrorCount += 1
        }
    }

    @Test("info 便捷方法构造默认时长的 .info toast")
    func infoConvenience() {
        let provider = RecordingProvider()

        provider.info("已连接", detail: "设备在线")

        #expect(provider.shown.count == 1)
        #expect(provider.shown[0].title == "已连接")
        #expect(provider.shown[0].detail == "设备在线")
        #expect(provider.shown[0].style == .info)
        #expect(provider.shown[0].duration == 3)
    }

    @Test("success 便捷方法构造默认时长的 .success toast")
    func successConvenience() {
        let provider = RecordingProvider()

        provider.success("保存成功")

        #expect(provider.shown.count == 1)
        #expect(provider.shown[0].style == .success)
        #expect(provider.shown[0].duration == 3)
    }

    @Test("warning 便捷方法使用 4 秒默认时长")
    func warningConvenienceDefaultsToFourSeconds() {
        let provider = RecordingProvider()

        provider.warning("磁盘空间不足")

        #expect(provider.shown.count == 1)
        #expect(provider.shown[0].style == .warning)
        #expect(provider.shown[0].duration == 4)
    }

    @Test("error 不带时长时进入持久化错误面板")
    func errorWithoutDurationPresentsPersistentError() {
        let provider = RecordingProvider()

        provider.error("同步失败", detail: "网络超时")

        #expect(provider.shown.isEmpty)
        #expect(provider.errors.count == 1)
        #expect(provider.errors[0].title == "同步失败")
        #expect(provider.errors[0].message == "网络超时")
    }

    @Test("error 带时长时展示瞬时 .error toast")
    func errorWithDurationShowsTransientToast() {
        let provider = RecordingProvider()

        provider.error("同步失败", detail: "网络超时", duration: 2)

        #expect(provider.errors.isEmpty)
        #expect(provider.shown.count == 1)
        #expect(provider.shown[0].style == .error)
        #expect(provider.shown[0].duration == 2)
        #expect(provider.shown[0].title == "同步失败")
        #expect(provider.shown[0].detail == "网络超时")
    }

    @Test("error 便捷方法无 detail 时以标题为消息")
    func errorWithoutDetailUsesTitleAsMessage() {
        let provider = RecordingProvider()

        provider.error("认证失败")

        #expect(provider.errors.count == 1)
        #expect(provider.errors[0].title == "认证失败")
        #expect(provider.errors[0].message == "认证失败")
    }

    @Test("error(Error:) 便捷方法使用默认标题与错误描述")
    func errorFromErrorValue() {
        let provider = RecordingProvider()
        struct Failing: Error, LocalizedError {
            var errorDescription: String? { "boom" }
        }

        provider.error(Failing())

        #expect(provider.errors.count == 1)
        #expect(provider.errors[0].title == "Error")
        #expect(provider.errors[0].message == "boom")
    }

    @Test("自定义时长覆盖默认值")
    func explicitDurationOverridesDefault() {
        let provider = RecordingProvider()

        provider.info("注意", duration: 7)
        provider.success("完成", duration: 0.5)

        #expect(provider.shown[0].duration == 7)
        #expect(provider.shown[1].duration == 0.5)
    }

    @Test("非 loading Provider 的 dismissAll 回退为关闭错误")
    func dismissAllFallsBackToDismissError() {
        let provider = RecordingProvider()

        provider.dismissAll()

        #expect(provider.dismissErrorCount == 1)
    }

    @Test("DefaultToastProviding 的便捷方法均为安全 no-op")
    func defaultProviderConveniencesAreNoOps() {
        let provider: any ToastProviding = DefaultToastProviding()

        provider.info("info")
        provider.success("success")
        provider.warning("warning")
        provider.error("error")
        provider.error("error", duration: 1)
        provider.dismissAll()
    }
}
