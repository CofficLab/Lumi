import XCTest
@testable import ProjectProfileKit

final class ProjectProfileTests: XCTestCase {
    func testShortTitleUsesLanguageAndFirstFramework() {
        let profile = ProjectProfile(
            projectPath: "/tmp/example",
            primaryLanguage: "TypeScript",
            frameworks: ["React", "Vite"],
            dependencies: [],
            projectType: .web,
            keywords: [],
            description: "",
            platform: nil
        )

        XCTAssertEqual(profile.shortTitle, "TypeScript / React")
    }

    func testShortTitleFallsBackToUnknownLanguage() {
        let profile = ProjectProfile(
            projectPath: "/tmp/example",
            primaryLanguage: nil,
            frameworks: [],
            dependencies: [],
            projectType: .unknown,
            keywords: [],
            description: "",
            platform: nil
        )

        XCTAssertEqual(profile.shortTitle, "Unknown")
    }

    func testProfileRoundTripsThroughCodable() throws {
        let profile = ProjectProfile(
            projectPath: "/tmp/example",
            primaryLanguage: "Swift",
            frameworks: ["SwiftUI"],
            dependencies: ["Combine"],
            projectType: .mobile,
            keywords: ["editor", "preview"],
            description: "Example app",
            platform: "Apple platforms"
        )

        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(ProjectProfile.self, from: data)

        XCTAssertEqual(decoded.projectPath, profile.projectPath)
        XCTAssertEqual(decoded.primaryLanguage, profile.primaryLanguage)
        XCTAssertEqual(decoded.frameworks, profile.frameworks)
        XCTAssertEqual(decoded.dependencies, profile.dependencies)
        XCTAssertEqual(decoded.projectType, profile.projectType)
        XCTAssertEqual(decoded.keywords, profile.keywords)
        XCTAssertEqual(decoded.description, profile.description)
        XCTAssertEqual(decoded.platform, profile.platform)
    }
}
