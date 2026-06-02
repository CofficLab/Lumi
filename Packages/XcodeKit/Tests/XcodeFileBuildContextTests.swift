import XCTest
@testable import XcodeKit

final class XcodeFileBuildContextTests: XCTestCase {

    func testFileBuildContextInitialization() {
        let url = URL(filePath: "/test/file.swift")
        let context = XcodeFileBuildContext(fileURL: url, settings: ["KEY": "VALUE"], scheme: "App", workspacePath: "/test")

        XCTAssertEqual(context.fileURL, url)
        XCTAssertEqual(context.settings["KEY"], "VALUE")
        XCTAssertEqual(context.scheme, "App")
        XCTAssertEqual(context.workspacePath, "/test")
    }

    // MARK: - Derived Properties Tests

    func testSdkPath() {
        let settings: [String: String] = ["SDKROOT": "macosx15.0"]
        let context = XcodeFileBuildContext(fileURL: URL(filePath: "/test.swift"), settings: settings, scheme: "App", workspacePath: "/test")
        XCTAssertEqual(context.sdkPath, "macosx15.0")
    }

    func testSdkPathNil() {
        let context = XcodeFileBuildContext(fileURL: URL(filePath: "/test.swift"), settings: [:], scheme: "App", workspacePath: "/test")
        XCTAssertNil(context.sdkPath)
    }

    func testToolchainPath() {
        let settings: [String: String] = ["TOOLCHAIN_DIR": "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain"]
        let context = XcodeFileBuildContext(fileURL: URL(filePath: "/test.swift"), settings: settings, scheme: "App", workspacePath: "/test")
        XCTAssertNotNil(context.toolchainPath)
        XCTAssertTrue(context.toolchainPath!.contains("XcodeDefault.xctoolchain"))
    }

    func testTargetTriple() {
        let settings: [String: String] = ["LLVM_TARGET_TRIPLE_SUFFIX": "-apple-macosx15.0"]
        let context = XcodeFileBuildContext(fileURL: URL(filePath: "/test.swift"), settings: settings, scheme: "App", workspacePath: "/test")
        XCTAssertEqual(context.targetTriple, "-apple-macosx15.0")
    }

    func testHeaderSearchPaths() {
        let settings: [String: String] = ["HEADER_SEARCH_PATHS": "/usr/include /usr/local/include"]
        let context = XcodeFileBuildContext(fileURL: URL(filePath: "/test.swift"), settings: settings, scheme: "App", workspacePath: "/test")
        XCTAssertEqual(context.headerSearchPaths, ["/usr/include", "/usr/local/include"])
    }

    func testHeaderSearchPathsEmpty() {
        let context = XcodeFileBuildContext(fileURL: URL(filePath: "/test.swift"), settings: [:], scheme: "App", workspacePath: "/test")
        XCTAssertTrue(context.headerSearchPaths.isEmpty)
    }

    func testFrameworkSearchPaths() {
        let settings: [String: String] = ["FRAMEWORK_SEARCH_PATHS": "/usr/lib/swift /usr/local/lib"]
        let context = XcodeFileBuildContext(fileURL: URL(filePath: "/test.swift"), settings: settings, scheme: "App", workspacePath: "/test")
        XCTAssertEqual(context.frameworkSearchPaths, ["/usr/lib/swift", "/usr/local/lib"])
    }

    func testActiveCompilationConditions() {
        let settings: [String: String] = ["ACTIVE_COMPILATION_CONDITIONS": "DEBUG MOCK"]
        let context = XcodeFileBuildContext(fileURL: URL(filePath: "/test.swift"), settings: settings, scheme: "App", workspacePath: "/test")
        XCTAssertEqual(context.activeCompilationConditions, ["DEBUG", "MOCK"])
    }

    func testModuleName() {
        let settings: [String: String] = ["PRODUCT_MODULE_NAME": "MyApp"]
        let context = XcodeFileBuildContext(fileURL: URL(filePath: "/test.swift"), settings: settings, scheme: "App", workspacePath: "/test")
        XCTAssertEqual(context.moduleName, "MyApp")
    }

    func testModuleNameNil() {
        let context = XcodeFileBuildContext(fileURL: URL(filePath: "/test.swift"), settings: [:], scheme: "App", workspacePath: "/test")
        XCTAssertNil(context.moduleName)
    }
}
