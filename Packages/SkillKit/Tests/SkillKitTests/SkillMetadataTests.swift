import Foundation
import Testing
@testable import SkillKit

// MARK: - SkillMetadata Tests

struct SkillMetadataTests {

    // MARK: Initialization

    @Test
    func initWithAllFieldsPreservesValues() {
        let date = Date(timeIntervalSince1970: 1000)
        let skill = SkillMetadata(
            name: "swiftui-expert",
            title: "SwiftUI Expert",
            description: "Best practices for SwiftUI",
            triggers: ["swift", "swiftui"],
            version: "2.0.0",
            contentPath: "/tmp/SKILL.md",
            modifiedAt: date
        )

        #expect(skill.name == "swiftui-expert")
        #expect(skill.title == "SwiftUI Expert")
        #expect(skill.description == "Best practices for SwiftUI")
        #expect(skill.triggers == ["swift", "swiftui"])
        #expect(skill.version == "2.0.0")
        #expect(skill.contentPath == "/tmp/SKILL.md")
        #expect(skill.modifiedAt == date)
    }

    @Test
    func initDefaultsIdToName() {
        let skill = SkillMetadata(name: "git-workflow", title: "Git", description: "Git rules")
        #expect(skill.id == "git-workflow")
    }

    @Test
    func initAcceptsCustomId() {
        let skill = SkillMetadata(id: "custom-id", name: "git", title: "Git", description: "Rules")
        #expect(skill.id == "custom-id")
        #expect(skill.name == "git")
    }

    @Test
    func initDefaultsTriggersToEmpty() {
        let skill = SkillMetadata(name: "test", title: "Test", description: "Desc")
        #expect(skill.triggers.isEmpty)
    }

    @Test
    func initDefaultsVersionTo1() {
        let skill = SkillMetadata(name: "test", title: "Test", description: "Desc")
        #expect(skill.version == "1.0.0")
    }

    @Test
    func initDefaultsContentPathToEmpty() {
        let skill = SkillMetadata(name: "test", title: "Test", description: "Desc")
        #expect(skill.contentPath.isEmpty)
    }

    // MARK: Equatable

    @Test
    func equatableWithSameIdIsEqual() {
        let a = SkillMetadata(name: "x", title: "X", description: "a")
        let b = SkillMetadata(name: "x", title: "X", description: "a")
        #expect(a == b)
    }

    @Test
    func equatableWithDifferentIdIsNotEqual() {
        let a = SkillMetadata(name: "x", title: "X", description: "a")
        let b = SkillMetadata(name: "y", title: "Y", description: "b")
        #expect(a != b)
    }

    // MARK: Identifiable

    @Test
    func idMatchesNameForDefaultInit() {
        let skill = SkillMetadata(name: "my-skill", title: "My Skill", description: "Desc")
        #expect(skill.id == skill.name)
    }

    // MARK: loadContent

    @Test
    func loadContentThrowsWhenPathIsEmpty() {
        let skill = SkillMetadata(name: "test", title: "Test", description: "Desc", contentPath: "")
        #expect(throws: SkillError.self) {
            try skill.loadContent()
        }
    }

    @Test
    func loadContentThrowsForNonexistentFile() {
        let skill = SkillMetadata(name: "test", title: "Test", description: "Desc", contentPath: "/nonexistent/SKILL.md")
        #expect(throws: CocoaError.self) {
            try skill.loadContent()
        }
    }

    // MARK: Codable

    @Test
    func codableRoundTripPreservesFields() throws {
        let original = SkillMetadata(
            name: "code-review",
            title: "Code Review",
            description: "Automated PR review guidelines",
            triggers: ["review", "pr", "pull request"],
            version: "1.5.0"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SkillMetadata.self, from: data)

        #expect(decoded.name == original.name)
        #expect(decoded.title == original.title)
        #expect(decoded.description == original.description)
        #expect(decoded.triggers == original.triggers)
        #expect(decoded.version == original.version)
        #expect(decoded.id == original.name)
    }

    @Test
    func codableDecodesWithMissingOptionalFields() throws {
        let json = """
        {
            "name": "minimal",
            "title": "Minimal Skill",
            "description": "Only required fields"
        }
        """
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(SkillMetadata.self, from: data)

        #expect(decoded.name == "minimal")
        #expect(decoded.triggers.isEmpty)
        #expect(decoded.version == "1.0.0")
    }

    @Test
    func codableRoundTripPreservesSpecialCharacters() throws {
        let original = SkillMetadata(
            name: "special",
            title: "Special: 中文标题 🎉",
            description: "Description with | pipes | and * markdown"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SkillMetadata.self, from: data)

        #expect(decoded.title == "Special: 中文标题 🎉")
        #expect(decoded.description == "Description with | pipes | and * markdown")
    }

    @Test
    func codableFailsOnMissingRequiredField() {
        let json = """
        {
            "title": "No Name",
            "description": "Missing name field"
        }
        """
        let data = Data(json.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(SkillMetadata.self, from: data)
        }
    }

    @Test
    func codableHandlesEmptyStrings() throws {
        let json = """
        {
            "name": "",
            "title": "",
            "description": ""
        }
        """
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(SkillMetadata.self, from: data)

        #expect(decoded.name.isEmpty)
        #expect(decoded.title.isEmpty)
        #expect(decoded.description.isEmpty)
    }
}

// MARK: - SkillError Tests

struct SkillErrorTests {
    @Test
    func skillErrorHasReadableDescription() {
        let error = SkillError.invalidContentPath("path is empty")
        #expect(error.errorDescription == "Invalid content path: path is empty")

        let metaError = SkillError.invalidMetadata("name is blank")
        #expect(metaError.errorDescription == "Invalid metadata: name is blank")
    }

    @Test
    func skillErrorIsEquatable() {
        #expect(SkillError.invalidContentPath("a") == SkillError.invalidContentPath("a"))
        #expect(SkillError.invalidContentPath("a") != SkillError.invalidContentPath("b"))
        #expect(SkillError.invalidContentPath("a") != SkillError.invalidMetadata("a"))
    }
}
