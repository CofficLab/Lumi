import XCTest
@testable import XcodeKit

final class XcodeBuildSettingsParserTests: XCTestCase {

    // MARK: - parseListOutput Tests

    func testParseListOutputValidJSON() throws {
        let jsonString = """
        {
            "project": {
                "name": "MyProject",
                "targets": ["App", "AppTests"],
                "configurations": ["Debug", "Release"],
                "schemes": ["App", "AppTests"]
            },
            "workspace": {
                "name": "MyWorkspace",
                "schemes": ["App", "AppTests", "Other"]
            }
        }
        """
        let data = jsonString.data(using: .utf8)!
        let result = try XcodeBuildSettingsParser.parseListOutput(data)

        XCTAssertEqual(result.project?.name, "MyProject")
        XCTAssertEqual(result.project?.targets, ["App", "AppTests"])
        XCTAssertEqual(result.project?.configurations, ["Debug", "Release"])
        XCTAssertEqual(result.project?.schemes, ["App", "AppTests"])

        XCTAssertEqual(result.workspace?.name, "MyWorkspace")
        XCTAssertEqual(result.workspace?.schemes, ["App", "AppTests", "Other"])
    }

    func testParseListOutputEmptyJSON() throws {
        let data = "{}".data(using: .utf8)!
        let result = try XcodeBuildSettingsParser.parseListOutput(data)
        XCTAssertNil(result.project)
        XCTAssertNil(result.workspace)
    }

    func testParseListOutputMissingProject() throws {
        let jsonString = """
        {
            "workspace": {
                "name": "MyWorkspace",
                "schemes": ["App"]
            }
        }
        """
        let data = jsonString.data(using: .utf8)!
        let result = try XcodeBuildSettingsParser.parseListOutput(data)
        XCTAssertNil(result.project)
        XCTAssertNotNil(result.workspace)
    }

    func testParseListOutputInvalidJSON() {
        let data = "not json".data(using: .utf8)!
        XCTAssertThrowsError(try XcodeBuildSettingsParser.parseListOutput(data))
    }

    // MARK: - parseBuildSettingsOutput Tests

    func testParseBuildSettingsOutputValid() throws {
        let jsonString = """
        [
            {
                "buildSettings": {
                    "TARGET_NAME": "MyApp",
                    "SDKROOT": "macosx",
                    "ARCHS": "arm64"
                }
            }
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let results = try XcodeBuildSettingsParser.parseBuildSettingsOutput(data)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0]["TARGET_NAME"], "MyApp")
        XCTAssertEqual(results[0]["SDKROOT"], "macosx")
        XCTAssertEqual(results[0]["ARCHS"], "arm64")
    }

    func testParseBuildSettingsOutputMultiple() throws {
        let jsonString = """
        [
            {
                "buildSettings": {
                    "TARGET_NAME": "App"
                }
            },
            {
                "buildSettings": {
                    "TARGET_NAME": "AppTests"
                }
            }
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let results = try XcodeBuildSettingsParser.parseBuildSettingsOutput(data)

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0]["TARGET_NAME"], "App")
        XCTAssertEqual(results[1]["TARGET_NAME"], "AppTests")
    }

    func testParseBuildSettingsOutputEmpty() throws {
        let data = "[]".data(using: .utf8)!
        let results = try XcodeBuildSettingsParser.parseBuildSettingsOutput(data)
        XCTAssertTrue(results.isEmpty)
    }

    func testParseBuildSettingsOutputMissingBuildSettings() throws {
        let jsonString = """
        [
            {
                "otherKey": "value"
            }
        ]
        """
        let data = jsonString.data(using: .utf8)!
        let results = try XcodeBuildSettingsParser.parseBuildSettingsOutput(data)
        XCTAssertTrue(results.isEmpty)
    }
}
