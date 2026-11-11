import Foundation
import Testing
@testable import PluginAppStoreConnect

/// 回归 #862：多 Target 工程把测试 Target 的 Bundle ID 当成主 App。
///
/// 自动绑定从 `project.pbxproj` 的文本顺序里挑第一个「看起来像真实 Bundle ID」
/// 的值。此前唯一的测试 Target 过滤条件是「不以小写 `.tests` 结尾」，于是
/// `DemoTests`、`.Tests`、`.UITests` 这些常见形式都会被当成主 App，
/// 自动绑定拿到测试 Target 的 ID，最终查不到对应的 ASC App。
@Suite("ASC Bundle ID 检测")
struct ASCBundleIDDetectorTests {

    // MARK: - 测试 Target 过滤

    @Test("测试 Target 排在前面时返回主 App 的 Bundle ID")
    func skipsTestTargetBeforeAppTarget() {
        let contents = """
        PRODUCT_BUNDLE_IDENTIFIER = com.example.DemoTests;
        PRODUCT_BUNDLE_IDENTIFIER = com.example.Demo;
        """

        #expect(ASCBundleIDDetector.parseBundleID(fromPbxproj: contents) == "com.example.Demo")
    }

    @Test("常见的测试 Bundle ID 形式都被跳过")
    func skipsCommonTestBundleIDForms() {
        let contents = """
        PRODUCT_BUNDLE_IDENTIFIER = com.example.DemoTests;
        PRODUCT_BUNDLE_IDENTIFIER = com.example.DemoTests.debug;
        PRODUCT_BUNDLE_IDENTIFIER = com.example.DemoUITests;
        PRODUCT_BUNDLE_IDENTIFIER = com.example.Demo.tests;
        PRODUCT_BUNDLE_IDENTIFIER = com.example.Demo;
        """

        #expect(ASCBundleIDDetector.parseBundleID(fromPbxproj: contents) == "com.example.Demo")
    }

    @Test("只有测试 Target 时仍然返回它，不返回 nil")
    func returnsTestTargetWhenItIsTheOnlyCandidate() {
        let contents = """
        PRODUCT_BUNDLE_IDENTIFIER = com.example.DemoTests;
        """

        #expect(ASCBundleIDDetector.parseBundleID(fromPbxproj: contents) == "com.example.DemoTests")
    }

    @Test("主 App 在前时不会被后续的测试 Target 覆盖")
    func keepsAppTargetWhenItComesFirst() {
        let contents = """
        PRODUCT_BUNDLE_IDENTIFIER = com.example.Demo;
        PRODUCT_BUNDLE_IDENTIFIER = com.example.DemoTests;
        """

        #expect(ASCBundleIDDetector.parseBundleID(fromPbxproj: contents) == "com.example.Demo")
    }

    // MARK: - 判定规则

    @Test("测试 Bundle ID 的判定不区分大小写")
    func testDetectionIsCaseInsensitive() {
        #expect(ASCBundleIDDetector.isTestBundleIdentifier("com.example.DemoTests"))
        #expect(ASCBundleIDDetector.isTestBundleIdentifier("com.example.DemoTESTS"))
        #expect(ASCBundleIDDetector.isTestBundleIdentifier("com.example.demotests"))
        #expect(ASCBundleIDDetector.isTestBundleIdentifier("com.example.DemoUITests"))
        #expect(ASCBundleIDDetector.isTestBundleIdentifier("com.example.Demo.tests"))
    }

    @Test("普通 App 的 Bundle ID 不被判成测试 Target")
    func appBundleIDsAreNotTestTargets() {
        #expect(!ASCBundleIDDetector.isTestBundleIdentifier("com.example.Demo"))
        #expect(!ASCBundleIDDetector.isTestBundleIdentifier("com.coffic.Lumi"))
        #expect(!ASCBundleIDDetector.isTestBundleIdentifier("com.example.Latest"))
        #expect(!ASCBundleIDDetector.isTestBundleIdentifier("com.example.Contest"))
        #expect(!ASCBundleIDDetector.isTestBundleIdentifier(""))
    }
}
