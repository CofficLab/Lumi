import XCTest
@testable import XcodeKit

final class XcodeLSPErrorTests: XCTestCase {

    // MARK: - Error Description Tests

    func testServerNotStartedDescription() {
        let error = XcodeLSPError.serverNotStarted
        XCTAssertFalse(error.localizedDescription.isEmpty)
    }

    func testServerDisconnectedDescription() {
        let error = XcodeLSPError.serverDisconnected
        XCTAssertFalse(error.localizedDescription.isEmpty)
    }

    func testNoProjectContextDescription() {
        let error = XcodeLSPError.noProjectContext
        XCTAssertFalse(error.localizedDescription.isEmpty)
    }

    func testBuildContextUnavailableDescription() {
        let error = XcodeLSPError.buildContextUnavailable("test reason")
        XCTAssertTrue(error.localizedDescription.contains("test reason"))
    }

    func testSymbolNotResolvedWithSymbol() {
        let error = XcodeLSPError.symbolNotResolved(symbolName: "myFunc")
        XCTAssertTrue(error.localizedDescription.contains("myFunc"))
    }

    func testSymbolNotResolvedWithoutSymbol() {
        let error = XcodeLSPError.symbolNotResolved(symbolName: nil)
        XCTAssertFalse(error.localizedDescription.isEmpty)
    }

    func testSymbolNotFoundDescription() {
        let error = XcodeLSPError.symbolNotFound
        XCTAssertFalse(error.localizedDescription.isEmpty)
    }

    func testIndexingInProgressDescription() {
        let error = XcodeLSPError.indexingInProgress
        XCTAssertFalse(error.localizedDescription.isEmpty)
    }

    func testFileNotInTargetDescription() {
        let error = XcodeLSPError.fileNotInTarget("MyFile.swift")
        XCTAssertTrue(error.localizedDescription.contains("MyFile.swift"))
    }

    func testFileInMultipleTargetsDescription() {
        let error = XcodeLSPError.fileInMultipleTargets(file: "MyFile.swift", targets: ["App", "AppTests"], activeScheme: nil)
        XCTAssertTrue(error.localizedDescription.contains("MyFile.swift"))
        XCTAssertTrue(error.localizedDescription.contains("App"))
        XCTAssertTrue(error.localizedDescription.contains("AppTests"))
    }

    func testFileInMultipleTargetsWithScheme() {
        let error = XcodeLSPError.fileInMultipleTargets(file: "MyFile.swift", targets: ["App", "AppTests"], activeScheme: "App")
        XCTAssertTrue(error.localizedDescription.contains("App"))
    }

    func testFileTargetsExcludedByActiveScheme() {
        let error = XcodeLSPError.fileTargetsExcludedByActiveScheme(file: "MyFile.swift", targets: ["App"], activeScheme: "Other")
        XCTAssertTrue(error.localizedDescription.contains("MyFile.swift"))
        XCTAssertTrue(error.localizedDescription.contains("App"))
    }

    func testRequestTimeoutDescription() {
        let error = XcodeLSPError.requestTimeout
        XCTAssertFalse(error.localizedDescription.isEmpty)
    }

    func testUnknownDescription() {
        let error = XcodeLSPError.unknown("some error message")
        XCTAssertEqual(error.localizedDescription, "some error message")
    }

    // MARK: - Category Tests

    func testCategoryServer() {
        XCTAssertEqual(XcodeLSPError.serverNotStarted.category, "server")
        XCTAssertEqual(XcodeLSPError.serverDisconnected.category, "server")
    }

    func testCategoryProject() {
        XCTAssertEqual(XcodeLSPError.noProjectContext.category, "project")
        XCTAssertEqual(XcodeLSPError.fileNotInTarget("").category, "project")
        XCTAssertEqual(XcodeLSPError.fileInMultipleTargets(file: "", targets: [], activeScheme: nil).category, "project")
        XCTAssertEqual(XcodeLSPError.fileTargetsExcludedByActiveScheme(file: "", targets: [], activeScheme: nil).category, "project")
    }

    func testCategoryBuild() {
        XCTAssertEqual(XcodeLSPError.buildContextUnavailable("").category, "build")
    }

    func testCategorySemantic() {
        XCTAssertEqual(XcodeLSPError.symbolNotResolved(symbolName: nil).category, "semantic")
        XCTAssertEqual(XcodeLSPError.symbolNotFound.category, "semantic")
        XCTAssertEqual(XcodeLSPError.indexingInProgress.category, "semantic")
    }

    func testCategoryTimeout() {
        XCTAssertEqual(XcodeLSPError.requestTimeout.category, "timeout")
    }

    func testCategoryUnknown() {
        XCTAssertEqual(XcodeLSPError.unknown("").category, "unknown")
    }

    // MARK: - RequiresUserAction Tests

    func testRequiresUserAction() {
        XCTAssertTrue(XcodeLSPError.serverNotStarted.requiresUserAction)
        XCTAssertTrue(XcodeLSPError.noProjectContext.requiresUserAction)
        XCTAssertTrue(XcodeLSPError.fileNotInTarget("").requiresUserAction)
    }

    func testDoesNotRequireUserAction() {
        XCTAssertFalse(XcodeLSPError.serverDisconnected.requiresUserAction)
        XCTAssertFalse(XcodeLSPError.indexingInProgress.requiresUserAction)
    }

    // MARK: - SuggestedAction Tests

    func testSuggestedActionNotNil() {
        XCTAssertNotNil(XcodeLSPError.serverNotStarted.suggestedAction)
        XCTAssertNotNil(XcodeLSPError.fileNotInTarget("").suggestedAction)
    }

    func testSuggestedActionNil() {
        XCTAssertNil(XcodeLSPError.symbolNotFound.suggestedAction)
        XCTAssertNil(XcodeLSPError.unknown("").suggestedAction)
    }

    // MARK: - Equality Tests

    func testEquality() {
        XCTAssertEqual(XcodeLSPError.serverNotStarted, XcodeLSPError.serverNotStarted)
        XCTAssertEqual(XcodeLSPError.serverDisconnected, XcodeLSPError.serverDisconnected)
        XCTAssertEqual(XcodeLSPError.symbolNotFound, XcodeLSPError.symbolNotFound)
    }

    func testInequality() {
        XCTAssertNotEqual(XcodeLSPError.serverNotStarted, XcodeLSPError.serverDisconnected)
        XCTAssertNotEqual(XcodeLSPError.symbolNotResolved(symbolName: "a"), XcodeLSPError.symbolNotResolved(symbolName: "b"))
    }

    // MARK: - userMessage Tests

    func testUserMessage() {
        let message = XcodeLSPError.userMessage(for: .serverNotStarted, operation: "Go to Definition")
        XCTAssertTrue(message.contains("Go to Definition"))
        XCTAssertTrue(message.contains("serverNotStarted") || message.contains("not started"))
    }

    func testUserMessageWithSuggestion() {
        let message = XcodeLSPError.userMessage(for: .fileNotInTarget("File.swift"), operation: "Jump")
        XCTAssertTrue(message.contains("💡"))
    }

    // MARK: - LSPErrorContext Tests

    func testLSPErrorContextDefaultValues() {
        let context = LSPErrorContext()
        XCTAssertNil(context.uri)
        XCTAssertNil(context.symbolName)
        XCTAssertNil(context.operation)
    }

    func testLSPErrorContextWithValues() {
        let context = LSPErrorContext(uri: "file:///test.swift", symbolName: "myFunc", operation: "Go to Definition")
        XCTAssertEqual(context.uri, "file:///test.swift")
        XCTAssertEqual(context.symbolName, "myFunc")
        XCTAssertEqual(context.operation, "Go to Definition")
    }
}
