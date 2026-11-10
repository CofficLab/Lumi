import Foundation
import ProviderToast
import Testing
@testable import KitOpenIn

@Suite("OpenInFailureReporting")
@MainActor
struct OpenInFailureReportingTests {
    @Test("失败会转换成错误 Toast，并保留标题与原因")
    func reportsFailureAsErrorToast() {
        let toast = SpyToastProvider()
        let reporter = OpenInFailureToastReporter(toast: toast)

        reporter.reportOpenFailure(title: "Cannot open project", detail: "Cursor: app not found")

        #expect(toast.shown.count == 1)
        #expect(toast.shown.first?.title == "Cannot open project")
        #expect(toast.shown.first?.detail == "Cursor: app not found")
        #expect(toast.shown.first?.style == .error)
    }

    @Test("没有注册 Toast 能力时安静降级")
    func toleratesMissingToastProvider() {
        OpenInFailureToastReporter(toast: nil)
            .reportOpenFailure(title: "Cannot open project", detail: nil)
    }
}

@MainActor
private final class SpyToastProvider: ToastProviding {
    private(set) var shown: [LumiToast] = []

    func show(_ toast: LumiToast) {
        shown.append(toast)
    }

    func presentError(title: String, message: String, sourceWindowID: String?) {}

    func dismissError() {}
}
