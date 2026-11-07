import Foundation
import XCTest
@testable import PluginToast

/// 本地化契约（基于编译后的资源 bundle）：
/// 1. 视图使用的每个 key 都必须同时存在于 en 与 zh-Hans 语言表；
/// 2. 关键文案的中文翻译正确；
/// 3. 经 `LumiPluginLocalization` 解析后非空（UI 不应出现空白文案）。
///
/// 运行期语言解析顺序由 LumiLocalization 负责（其自身已有测试），
/// 这里直接校验随包交付的语言表这一事实来源，避免依赖宿主机语言环境。
final class LumiPluginLocalizationTests: XCTestCase {

    /// 源码（视图）中实际使用的本地化 key。
    private static let usedKeys: [String] = [
        // ErrorNoticeOverlay
        "Error details", "Close",
        // ToastAboutView
        "Lightweight notifications that never get in your way.",
        "Auto-dismiss", "Non-blocking", "Throttled",
        "default duration", "display position",
        "Core Capabilities", "Auto-Dismiss", "Replacement Throttle", "Top Overlay",
        "How It Works", "Show", "Display", "Dismiss",
        "Each toast fades away on its own after a few seconds.",
        "Rapid-fire messages refresh the current toast instead of stacking.",
        "Toasts render at the top of the window, above all content.",
        "Any plugin calls the toast service with a message and style.",
        "The root overlay renders the toast at the top of the window.",
        "The timer clears it automatically — or a newer toast takes its place.",
    ]

    func testEveryKeyUsedByViewsExistsInBothLanguageTables() throws {
        let en = try Self.loadTable(language: "en")
        let zhHans = try Self.loadTable(language: "zh-Hans")

        for key in Self.usedKeys {
            XCTAssertNotNil(en[key], "en 语言表缺少视图使用的 key: \(key)")
            XCTAssertNotNil(zhHans[key], "zh-Hans 语言表缺少视图使用的 key: \(key)")
        }
    }

    func testBundleContainsExpectedChineseTranslations() throws {
        let en = try Self.loadTable(language: "en")
        let zhHans = try Self.loadTable(language: "zh-Hans")

        XCTAssertEqual(en["Close"], "Close")
        XCTAssertEqual(zhHans["Close"], "关闭")
        XCTAssertEqual(zhHans["Error details"], "错误详情")
        XCTAssertEqual(zhHans["Auto-Dismiss"], "自动消失")
        XCTAssertEqual(zhHans["Replacement Throttle"], "替换式节流")
    }

    func testWrapperResolvesKeysToNonEmptyStrings() throws {
        let bundle = try Self.pluginBundle()

        for key in Self.usedKeys {
            let value = LumiPluginLocalization.string(key, bundle: bundle)
            XCTAssertFalse(value.isEmpty, "key 解析为空: \(key)")
        }
    }

    // MARK: - Helpers

    /// 读取语言表中的 key → value 映射（.strings 为 plist 格式）。
    private static func loadTable(language: String) throws -> [String: String] {
        let bundle = try pluginBundle()
        let url = try XCTUnwrap(
            bundle.url(
                forResource: "Localizable",
                withExtension: "strings",
                subdirectory: "\(language).lproj"
            ),
            "资源 bundle 缺少 \(language).lproj/Localizable.strings"
        )
        let dict = try XCTUnwrap(
            NSDictionary(contentsOf: url) as? [String: String],
            "无法解析 \(language) 语言表"
        )
        return dict
    }

    /// 定位 PluginToast 的资源 bundle（SPM 将其嵌入测试 bundle 的 Resources 目录）。
    private static func pluginBundle() throws -> Bundle {
        let testBundle = Bundle(for: ToastCenter.self)
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: testBundle.bundleURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw LocalizationTestError.bundleNotFound
        }

        var fallback: Bundle?
        for case let url as URL in enumerator where url.pathExtension == "bundle" {
            guard let bundle = Bundle(url: url) else { continue }
            guard bundle.url(
                forResource: "Localizable",
                withExtension: "strings",
                subdirectory: "en.lproj"
            ) != nil else { continue }

            if url.lastPathComponent.contains("PluginToast") {
                return bundle
            }
            fallback = fallback ?? bundle
        }
        return try XCTUnwrap(fallback, "未找到 PluginToast 资源 bundle")
    }

    private enum LocalizationTestError: Error {
        case bundleNotFound
    }
}
