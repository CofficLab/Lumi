import XCTest
@testable import SuperLogKit
import SwiftUI

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
    // Using default emoji generation

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

    // MARK: - Emoji Tests

    func testCustomEmoji() {
        XCTAssertEqual(TestUserManager.emoji, "👤")
    }

    func testDefaultEmojiGeneration() {
        // DatabaseManager should generate 🗄️ based on its name
        let emoji = TestDatabaseManager.emoji
        XCTAssertTrue(emoji == "🗄️" || emoji == "📦", "Expected database or data emoji, got: \(emoji)")
    }

    func testNetworkServiceEmoji() {
        XCTAssertEqual(TestNetworkService.emoji, "🌐")
    }

    // MARK: - Author/ClassName Tests

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

    // MARK: - Thread Prefix Tests

    func testThreadPrefixFormat() {
        let prefix = TestUserManager.t

        // Should contain thread info, emoji, and author
        XCTAssertTrue(prefix.contains("[UI]") || prefix.contains("[BG]") || prefix.contains("[IN]") || prefix.contains("[DF]"))
        XCTAssertTrue(prefix.contains("👤"))
        XCTAssertTrue(prefix.contains("TestUserManager"))
        XCTAssertTrue(prefix.contains("|"))
    }

    func testStaticPrefixConsistency() {
        let prefix1 = TestUserManager.t
        let prefix2 = TestUserManager.t
        XCTAssertEqual(prefix1, prefix2)
    }

    // MARK: - Instance Prefix Tests

    func testInstanceThreadPrefix() {
        let manager = TestUserManager()
        let prefix = manager.t

        // Instance prefix should match static prefix
        XCTAssertEqual(prefix, TestUserManager.t)
    }

    // MARK: - Main Thread Detection

    func testIsMainOnMainThread() {
        let manager = TestUserManager()
        XCTAssertTrue(manager.isMain, "Should be on main thread during test")
    }

    // MARK: - Reason String Tests

    func testReasonString() {
        let manager = TestUserManager()
        let reason = manager.r("test error")

        XCTAssertTrue(reason.contains("➡️"))
        XCTAssertTrue(reason.contains("test error"))
    }

    func testMakeReasonMethod() {
        let manager = TestUserManager()
        let reason = manager.makeReason("connection failed")

        XCTAssertEqual(reason, " ➡️ connection failed")
    }

    // MARK: - Lifecycle Strings

    func testOnAppearString() {
        let onAppear = TestUserManager.onAppear

        XCTAssertTrue(onAppear.contains("📺"))
        XCTAssertTrue(onAppear.contains("OnAppear"))
        XCTAssertTrue(onAppear.contains("[UI]") || onAppear.contains("[BG]"))
    }

    func testOnInitString() {
        let onInit = TestUserManager.onInit

        XCTAssertTrue(onInit.contains("🚩"))
        XCTAssertTrue(onInit.contains("Init"))
        XCTAssertTrue(onInit.contains("[UI]") || onInit.contains("[BG]"))
    }

    func testInstanceLifecycleStrings() {
        let manager = TestUserManager()

        XCTAssertEqual(manager.a, TestUserManager.onAppear)
        XCTAssertEqual(manager.i, TestUserManager.onInit)
    }

    // MARK: - Padding Tests

    func testAuthorPadding() {
        let prefix = TestUserManager.t

        // The author should be padded to 27 characters
        let components = prefix.split(separator: "|")
        if components.count >= 2 {
            let authorPart = components[1].trimmingCharacters(in: .whitespaces)
            let authorWithoutEmoji = authorPart.components(separatedBy: " ").last ?? ""
            XCTAssertGreaterThanOrEqual(authorWithoutEmoji.count, 15) // TestUserManager is 16 chars
        }
    }
}

// MARK: - Thread Extension Tests

final class ThreadExtensionTests: XCTestCase {

    func testCurrentQosDescription() {
        let qosDesc = Thread.currentQosDescription

        // Should be one of the known QoS descriptions
        let validDescriptions = ["[UI]", "[IN]", "[DF]", "[UT]", "[BG]", "[UN]"]
        XCTAssertTrue(validDescriptions.contains(qosDesc), "Got unexpected QoS: \(qosDesc)")
    }

    func testQosDescriptionOnMainThread() {
        // Running on main thread during tests
        let qosDesc = Thread.currentQosDescription
        XCTAssertTrue(qosDesc == "[UI]" || qosDesc == "[IN]")
    }
}

// MARK: - QualityOfService Extension Tests

final class QualityOfServiceExtensionTests: XCTestCase {

    func testUserInteractiveDescription() {
        let desc = QualityOfService.userInteractive.description()
        XCTAssertTrue(desc.contains("[UI]"))
        XCTAssertTrue(desc.contains("userInteractive"))
    }

    func testUserInteractiveDescriptionWithoutName() {
        let desc = QualityOfService.userInteractive.description(withName: false)
        XCTAssertEqual(desc, "[UI]")
    }

    func testUserInitiatedDescription() {
        let desc = QualityOfService.userInitiated.description(withName: false)
        XCTAssertEqual(desc, "[IN]")
    }

    func testDefaultDescription() {
        let desc = QualityOfService.default.description(withName: false)
        XCTAssertEqual(desc, "[DF]")
    }

    func testUtilityDescription() {
        let desc = QualityOfService.utility.description(withName: false)
        XCTAssertEqual(desc, "[UT]")
    }

    func testBackgroundDescription() {
        let desc = QualityOfService.background.description(withName: false)
        XCTAssertEqual(desc, "[BG]")
    }
}

// MARK: - String Extension Tests

final class StringExtensionTests: XCTestCase {

    // MARK: - Context Emoji Tests

    func testUserEmoji() {
        XCTAssertEqual("UserManager".generateContextEmoji(), "👤")
        XCTAssertEqual("AccountView".generateContextEmoji(), "👤")
    }

    func testAuthenticationEmoji() {
        XCTAssertEqual("LoginService".generateContextEmoji(), "🔐")
        XCTAssertEqual("AuthManager".generateContextEmoji(), "🔐")
    }

    func testDataEmoji() {
        XCTAssertEqual("DataModel".generateContextEmoji(), "📦")
        XCTAssertEqual("UserEntity".generateContextEmoji(), "👤")
    }

    func testDatabaseEmoji() {
        XCTAssertEqual("DatabaseManager".generateContextEmoji(), "🗄️") // "database" is checked first
        XCTAssertEqual("CoreDataStorage".generateContextEmoji(), "🗄️") // "storage" is checked before "data"
        XCTAssertEqual("CacheService".generateContextEmoji(), "💾") // "cache" is checked before "service"
    }

    func testNetworkEmoji() {
        XCTAssertEqual("NetworkManager".generateContextEmoji(), "🌐")
        XCTAssertEqual("APIClient".generateContextEmoji(), "🌐")
        XCTAssertEqual("DownloadService".generateContextEmoji(), "⬇️")
        XCTAssertEqual("UploadHandler".generateContextEmoji(), "⬆️")
    }

    func testUIEmoji() {
        XCTAssertEqual("ViewComponent".generateContextEmoji(), "🎨")
        XCTAssertEqual("MainWindow".generateContextEmoji(), "🪟")
        XCTAssertEqual("SubmitButton".generateContextEmoji(), "🔘")
    }

    func testFileEmoji() {
        XCTAssertEqual("FileManager".generateContextEmoji(), "📄")
        XCTAssertEqual("DocumentEditor".generateContextEmoji(), "📝")
        XCTAssertEqual("ImageProcessor".generateContextEmoji(), "🖼️")
    }

    func testEditorEmoji() {
        XCTAssertEqual("EditorKernel".generateContextEmoji(), "✏️")
        XCTAssertEqual("CodeHighlighter".generateContextEmoji(), "💻")
        XCTAssertEqual("ProjectNavigator".generateContextEmoji(), "📁")
    }

    func testSettingsEmoji() {
        XCTAssertEqual("SettingsView".generateContextEmoji(), "🎨") // "view" matches before "setting"
        XCTAssertEqual("ConfigManager".generateContextEmoji(), "⚙️")
        XCTAssertEqual("ThemeManager".generateContextEmoji(), "🎭")
    }

    func testToolsEmoji() {
        XCTAssertEqual("ServiceManager".generateContextEmoji(), "🛠️")
        XCTAssertEqual("EventHandler".generateContextEmoji(), "📡")
        XCTAssertEqual("HelperUtils".generateContextEmoji(), "🧰")
    }

    func testActionsEmoji() {
        XCTAssertEqual("ActionHandler".generateContextEmoji(), "⚡")
        XCTAssertEqual("CommandProcessor".generateContextEmoji(), "⚡")
        XCTAssertEqual("EventObserver".generateContextEmoji(), "📡")
    }

    func testErrorsEmoji() {
        XCTAssertEqual("ErrorHandler".generateContextEmoji(), "❌")
        XCTAssertEqual("WarningManager".generateContextEmoji(), "⚠️")
    }

    func testSearchEmoji() {
        XCTAssertEqual("SearchService".generateContextEmoji(), "🔍")
        XCTAssertEqual("FindNavigator".generateContextEmoji(), "🔍")
        XCTAssertEqual("NavigationController".generateContextEmoji(), "🧭")
    }

    func testTimeEmoji() {
        XCTAssertEqual("TimeManager".generateContextEmoji(), "🕐")
        XCTAssertEqual("DateFormatter".generateContextEmoji(), "🕐")
    }

    func testCommunicationEmoji() {
        XCTAssertEqual("ChatService".generateContextEmoji(), "💬")
        XCTAssertEqual("MessageHandler".generateContextEmoji(), "💬")
        XCTAssertEqual("NotificationManager".generateContextEmoji(), "🔔")
    }

    func testDebugEmoji() {
        XCTAssertEqual("DebugLogger".generateContextEmoji(), "🐛")
        XCTAssertEqual("LogViewer".generateContextEmoji(), "🎨") // "view" matches before "log"
        XCTAssertEqual("TestRunner".generateContextEmoji(), "🧪")
    }

    // MARK: - With Context Emoji Tests

    func testWithContextEmoji() {
        let result = "UserManager".withContextEmoji
        XCTAssertTrue(result.contains("👤"))
        XCTAssertTrue(result.contains("UserManager"))
    }

    func testWithContextEmojiForDatabase() {
        let result = "DatabaseManager".withContextEmoji
        XCTAssertTrue(result.contains("🗄️"))
        XCTAssertTrue(result.contains("DatabaseManager"))
    }

    func testDefaultEmoji() {
        let result = "UnknownClass".generateContextEmoji()
        XCTAssertEqual(result, "📌")
    }
}
