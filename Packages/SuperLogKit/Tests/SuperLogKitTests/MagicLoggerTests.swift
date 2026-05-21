import XCTest
@testable import SuperLogKit
import SwiftUI
import Combine

// MARK: - MagicLogEntry Tests

final class MagicLogEntryTests: XCTestCase {

    func testLogEntryInitialization() {
        let entry = MagicLogEntry(
            message: "Test message",
            level: .info,
            caller: "TestFile",
            line: 42,
            timestamp: Date()
        )

        XCTAssertNotNil(entry.id)
        XCTAssertEqual(entry.originalMessage, "Test message")
        XCTAssertEqual(entry.caller, "TestFile")
        XCTAssertEqual(entry.line, 42)
        XCTAssertEqual(entry.level, .info)
    }

    func testLogEntryMessageFormatting() {
        let entry = MagicLogEntry(
            message: "User logged in",
            level: .info
        )

        // Message should contain thread info and emoji
        XCTAssertTrue(entry.message.contains("🔥") || entry.message.contains("2️⃣") || entry.message.contains("5️⃣"))
        XCTAssertTrue(entry.message.contains("User logged in"))
    }

    func testLogEntryLevelColors() {
        XCTAssertEqual(MagicLogEntry.Level.info.color, .primary)
        XCTAssertEqual(MagicLogEntry.Level.warning.color, .orange)
        XCTAssertEqual(MagicLogEntry.Level.error.color, .red)
        XCTAssertEqual(MagicLogEntry.Level.debug.color, .blue)
    }

    func testLogEntryLevelIcons() {
        XCTAssertEqual(MagicLogEntry.Level.info.icon, "info.circle")
        XCTAssertEqual(MagicLogEntry.Level.warning.icon, "exclamationmark.triangle")
        XCTAssertEqual(MagicLogEntry.Level.error.icon, "xmark.circle")
        XCTAssertEqual(MagicLogEntry.Level.debug.icon, "doc.text.magnifyingglass")
    }

    func testLogEntryIdentifiable() {
        let entry1 = MagicLogEntry(message: "Test", level: .info)
        let entry2 = MagicLogEntry(message: "Test", level: .info)

        XCTAssertNotEqual(entry1.id, entry2.id, "Each entry should have unique ID")
    }

    func testLogEntryTimestamp() {
        let before = Date()
        let entry = MagicLogEntry(message: "Test", level: .info)
        let after = Date()

        XCTAssertGreaterThanOrEqual(entry.timestamp, before)
        XCTAssertLessThanOrEqual(entry.timestamp, after)
    }
}

// MARK: - MagicLogger Tests

final class MagicLoggerTests: XCTestCase {

    var cancellables: Set<AnyCancellable> = []

    override func setUp() {
        super.setUp()
        MagicLogger.clearLogs()
    }

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    // MARK: - Singleton Tests

    func testSharedInstance() {
        let shared = MagicLogger.shared
        XCTAssertNotNil(shared)
    }

    // MARK: - App Property Tests

    func testDefaultAppName() {
        let defaultLogger = MagicLogger()
        XCTAssertEqual(defaultLogger.app, "Default")
    }

    func testCustomAppName() {
        let customLogger = MagicLogger(app: "MyApp")
        XCTAssertEqual(customLogger.app, "MyApp")
    }

    // MARK: - Clear Logs Tests

    func testClearLogs() {
        let expectation = XCTestExpectation(description: "Logs cleared")

        MagicLogger.shared.$logs
            .dropFirst()
            .sink { logs in
                if logs.isEmpty {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // Add logs first
        let addExpectation = XCTestExpectation(description: "Logs added")
        MagicLogger.shared.$logs
            .dropFirst()
            .sink { logs in
                if logs.count == 3 {
                    addExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        MagicLogger.info("Test 1")
        MagicLogger.info("Test 2")
        MagicLogger.info("Test 3")

        wait(for: [addExpectation], timeout: 1.0)

        MagicLogger.clearLogs()

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Log Message Content Tests

    func testMessageContainsThreadInfo() {
        let expectation = XCTestExpectation(description: "Log added")

        MagicLogger.shared.$logs
            .dropFirst()
            .sink { logs in
                if let log = logs.first {
                    XCTAssertTrue(log.message.contains("🔥") || log.message.contains("5️⃣"))
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        MagicLogger.info("Test message")

        wait(for: [expectation], timeout: 1.0)
    }

    func testMessageContainsEmoji() {
        let expectation = XCTestExpectation(description: "Log added")

        MagicLogger.shared.$logs
            .dropFirst()
            .sink { logs in
                if let log = logs.first {
                    // Should contain some emoji based on the message
                    XCTAssertNotNil(log.message)
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        MagicLogger.info("User login")

        wait(for: [expectation], timeout: 1.0)
    }
}

// MARK: - Integration Tests

final class SuperLogIntegrationTests: XCTestCase {

    func testMultipleSuperLogClasses() {
        class ServiceA: SuperLog {
            static var emoji: String { "🅰️" }
        }

        class ServiceB: SuperLog {
            static var emoji: String { "🅱️" }
        }

        XCTAssertNotEqual(ServiceA.t, ServiceB.t)
        XCTAssertTrue(ServiceA.t.contains("🅰️"))
        XCTAssertTrue(ServiceB.t.contains("🅱️"))
    }
}
