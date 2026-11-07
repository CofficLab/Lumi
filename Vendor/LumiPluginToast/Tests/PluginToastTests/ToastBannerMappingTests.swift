import LumiUI
import ProviderToast
import XCTest
@testable import PluginToast

/// `LumiToastStyle` → `AppStatusBanner.Kind` 的映射是 UI 语义桥接：
/// 每个风格都必须命中对应的横幅种类，防止新增风格时静默落空或映射错位。
@MainActor
final class ToastBannerMappingTests: XCTestCase {

    func testEveryStyleMapsToMatchingBannerKind() {
        assertMapping(style: .info, expected: .info)
        assertMapping(style: .success, expected: .success)
        assertMapping(style: .warning, expected: .warning)
        assertMapping(style: .error, expected: .error)
    }

    private func assertMapping(
        style: LumiToastStyle,
        expected: AppStatusBanner.Kind
    ) {
        let actual = style.statusBannerKind
        switch (actual, expected) {
        case (.info, .info), (.success, .success), (.warning, .warning), (.error, .error):
            break
        default:
            XCTFail("风格 \(style.rawValue) 映射到 \(actual)，期望 \(expected)")
        }
    }
}
