import XCTest
@testable import MagicLog

final class MagicLogTests: XCTestCase {

    // Test class conforming to SuperLog
    class TestLogger: SuperLog {
        static var emoji: String { "🧪" }
    }

    func testEmojiGeneration() {
        let testString = "网络请求失败"
        let emoji = testString.generateContextEmoji()
        XCTAssertEqual(emoji, "❌", "Should generate error emoji for text containing '失败' (fail)")

        let successString = "数据保存成功"
        let successEmoji = successString.generateContextEmoji()
        XCTAssertEqual(successEmoji, "💾", "Should generate data emoji for data-related text")
    }

    func testSuperLogProtocol() {
        let logger = TestLogger()

        // Test emoji property
        XCTAssertEqual(TestLogger.emoji, "🧪", "Should return custom emoji")

        // Test author property
        XCTAssertEqual(TestLogger.author, "TestLogger", "Should return class name without generics")

        // Test thread prefix
        let prefix = TestLogger.t
        XCTAssertTrue(prefix.contains("🧪"), "Prefix should contain emoji")
        XCTAssertTrue(prefix.contains("TestLogger"), "Prefix should contain class name")

        // Test reason method
        let reason = logger.r("测试原因")
        XCTAssertEqual(reason, " ➡️ 测试原因", "Should format reason with arrow")

        // Test thread detection
        XCTAssertEqual(logger.isMain, Thread.isMainThread, "Should correctly detect main thread")
    }

    func testQoSDescription() {
        let qos = QualityOfService.default

        let withName = qos.description(withName: true)
        XCTAssertTrue(withName.contains("Default"), "Should include name when requested")

        let withoutName = qos.description(withName: false)
        XCTAssertFalse(withoutName.contains("Default"), "Should not include name when not requested")
        XCTAssertEqual(withoutName, "3️⃣", "Should return only emoji for default QoS")
    }

    func testThreadQoSDescription() {
        let description = Thread.currentQosDescription
        XCTAssertFalse(description.isEmpty, "Should return non-empty QoS description")

        // Should be emoji like "🔥", "2️⃣", "3️⃣", etc. (no brackets)
        XCTAssertFalse(description.hasPrefix("["), "Should not have brackets")
        XCTAssertFalse(description.hasSuffix("]"), "Should not have brackets")
    }

    func testStringEmojiExtension() {
        let testString = "成功"
        let withEmoji = testString.withContextEmoji
        XCTAssertTrue(withEmoji.hasPrefix("📝"), "Should prepend default emoji for unmatched text")
        XCTAssertTrue(withEmoji.contains(testString), "Should contain original text")
    }
}