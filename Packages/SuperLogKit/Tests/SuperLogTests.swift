import XCTest
@testable import SuperLogKit

// MARK: - Test Classes

class TestUserManager: SuperLog {
    static var emoji: String { "👤" }

    func performLogin() {
        print("\(Self.t)Login initiated")
    }

    func loginFailed() {
        print("\(t)Login failed\(r("invalid credentials"))")
    }
}

class TestDatabaseManager: SuperLog {
    func queryData() {
        print("\(Self.t)Querying database")
    }
}

class TestNetworkService: SuperLog {
    static var emoji: String { "🌐" }

    func fetchData() {
        if isMain {
            print("\(t)Warning: Network call on main thread")
        } else {
            print("\(t)Network call on background thread")
        }
    }
}

// MARK: - SuperLog Protocol Tests

final class SuperLogTests: XCTestCase {

    func testCustomEmoji() {
        XCTAssertEqual(TestUserManager.emoji, "👤")
    }

    func testDefaultEmojiGeneration() {
        XCTAssertEqual(TestDatabaseManager.emoji, "💾")
    }

    func testNetworkServiceEmoji() {
        XCTAssertEqual(TestNetworkService.emoji, "🌐")
    }

    func testAuthorProperty() {
        XCTAssertEqual(TestUserManager.author, "TestUserManager")
        XCTAssertEqual(TestDatabaseManager.author, "TestDatabaseManager")
        XCTAssertEqual(TestNetworkService.author, "TestNetworkService")
    }

    func testInstanceAuthorProperty() {
        let manager = TestUserManager()
        XCTAssertEqual(manager.author, "TestUserManager")
        XCTAssertEqual(manager.className, "TestUserManager")
    }

    func testThreadPrefixFormat() {
        let prefix = TestUserManager.t
        let validQoS = ["🔥", "2️⃣", "3️⃣", "4️⃣", "5️⃣", "6️⃣"]
        XCTAssertTrue(validQoS.contains(where: { prefix.contains($0) }))
        XCTAssertTrue(prefix.contains("👤"))
        XCTAssertTrue(prefix.contains("TestUserManager"))
        XCTAssertTrue(prefix.contains("|"))
    }

    func testStaticPrefixConsistency() {
        XCTAssertEqual(TestUserManager.t, TestUserManager.t)
    }

    func testInstanceThreadPrefix() {
        let manager = TestUserManager()
        XCTAssertEqual(manager.t, TestUserManager.t)
    }

    func testIsMainOnMainThread() {
        XCTAssertTrue(TestUserManager().isMain)
    }

    func testReasonString() {
        let reason = TestUserManager().r("test error")
        XCTAssertTrue(reason.contains("➡️"))
        XCTAssertTrue(reason.contains("test error"))
    }

    func testMakeReasonMethod() {
        XCTAssertEqual(TestUserManager().makeReason("connection failed"), " ➡️ connection failed")
    }

    func testOnAppearString() {
        let onAppear = TestUserManager.onAppear
        XCTAssertTrue(onAppear.contains("📺"))
        XCTAssertTrue(onAppear.contains("OnAppear"))
    }

    func testOnInitString() {
        let onInit = TestUserManager.onInit
        XCTAssertTrue(onInit.contains("🚩"))
        XCTAssertTrue(onInit.contains("Init"))
    }

    func testInstanceLifecycleStrings() {
        let manager = TestUserManager()
        XCTAssertEqual(manager.a, TestUserManager.onAppear)
        XCTAssertEqual(manager.i, TestUserManager.onInit)
    }
}

// MARK: - Thread Extension Tests

final class ThreadExtensionTests: XCTestCase {

    func testCurrentQosDescription() {
        let validDescriptions = ["🔥", "2️⃣", "3️⃣", "4️⃣", "5️⃣", "6️⃣"]
        XCTAssertTrue(validDescriptions.contains(Thread.currentQosDescription))
    }

    func testQosDescriptionOnMainThread() {
        XCTAssertTrue(["🔥", "2️⃣"].contains(Thread.currentQosDescription))
    }
}

// MARK: - QualityOfService Extension Tests

final class QualityOfServiceExtensionTests: XCTestCase {

    func testUserInteractiveDescription() {
        let desc = QualityOfService.userInteractive.description()
        XCTAssertTrue(desc.contains("🔥"))
        XCTAssertTrue(desc.contains("UserInteractive"))
    }

    func testUserInteractiveDescriptionWithoutName() {
        XCTAssertEqual(QualityOfService.userInteractive.description(withName: false), "🔥")
    }

    func testUserInitiatedDescription() {
        XCTAssertEqual(QualityOfService.userInitiated.description(withName: false), "2️⃣")
    }

    func testDefaultDescription() {
        XCTAssertEqual(QualityOfService.default.description(withName: false), "3️⃣")
    }

    func testUtilityDescription() {
        XCTAssertEqual(QualityOfService.utility.description(withName: false), "4️⃣")
    }

    func testBackgroundDescription() {
        XCTAssertEqual(QualityOfService.background.description(withName: false), "5️⃣")
    }
}

// MARK: - String Extension Tests

final class StringExtensionTests: XCTestCase {

    func testManagerEmoji() {
        XCTAssertEqual("UserManager".generateContextEmoji(), "👔")
        XCTAssertEqual("NetworkManager".generateContextEmoji(), "👔")
    }

    func testDataEmoji() {
        XCTAssertEqual("DatabaseManager".generateContextEmoji(), "💾")
        XCTAssertEqual("DataModel".generateContextEmoji(), "💾")
    }

    func testNetworkEmoji() {
        XCTAssertEqual("HTTPClient".generateContextEmoji(), "🌐")
    }

    func testPluginEmoji() {
        XCTAssertEqual("MyPlugin".generateContextEmoji(), "🔌")
    }

    func testErrorEmoji() {
        XCTAssertEqual("ErrorHandler".generateContextEmoji(), "❌")
        XCTAssertEqual("WarningHandler".generateContextEmoji(), "⚠️")
    }

    func testConfigEmoji() {
        XCTAssertEqual("ConfigManager".generateContextEmoji(), "🚩")
    }

    func testWithContextEmoji() {
        XCTAssertEqual("UserManager".withContextEmoji, "👔 UserManager")
    }

    func testDefaultEmoji() {
        XCTAssertEqual("UnknownClass".generateContextEmoji(), "📝")
    }

    func testChineseKeywordEmoji() {
        XCTAssertEqual("网络请求".generateContextEmoji(), "🌐")
        XCTAssertEqual("错误处理".generateContextEmoji(), "❌")
    }
}
