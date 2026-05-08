import Foundation
import Testing
@testable import SkillKit

// MARK: - SkillScanner Tests (Real File System)

struct SkillScannerTests {
    private let scanner = SkillScanner()
    private let tmpRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("SkillKitTests-\(UUID().uuidString)")

    // MARK: - Helpers

    /// 创建一个完整的 Skill 目录结构
    private func createSkill(
        name: String,
        title: String = "Test Skill",
        description: String = "A test skill",
        version: String = "1.0.0",
        triggers: [String] = [],
        skillContent: String = "# Test Skill\n\nInstructions here."
    ) throws {
        let skillDir = tmpRoot.appendingPathComponent(".agent/skills/\(name)")
        try FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)

        let metadata: [String: Any] = [
            "name": name,
            "title": title,
            "description": description,
            "version": version,
            "triggers": triggers
        ]
        let metadataData = try JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted)
        try metadataData.write(to: skillDir.appendingPathComponent("metadata.json"))
        try skillContent.write(
            to: skillDir.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )
    }

    /// 创建一个只有 metadata.json 缺少 SKILL.md 的 Skill
    private func createIncompleteSkill(name: String) throws {
        let skillDir = tmpRoot.appendingPathComponent(".agent/skills/\(name)")
        try FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)

        let metadata: [String: Any] = [
            "name": name,
            "title": "Incomplete",
            "description": "Missing SKILL.md"
        ]
        let metadataData = try JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted)
        try metadataData.write(to: skillDir.appendingPathComponent("metadata.json"))
    }

    private func cleanup() {
        try? FileManager.default.removeItem(at: tmpRoot)
    }

    // MARK: - Empty / Missing Directory

    @Test
    func scanReturnsEmptyWhenDirectoryDoesNotExist() {
        let result = scanner.scanSkills(projectPath: "/nonexistent/path-\(UUID())")
        #expect(result.isEmpty)
    }

    @Test
    func scanReturnsEmptyWhenSkillsDirectoryIsEmpty() throws {
        let skillsDir = tmpRoot.appendingPathComponent(".agent/skills")
        try FileManager.default.createDirectory(at: skillsDir, withIntermediateDirectories: true)

        let result = scanner.scanSkills(projectPath: tmpRoot.path)
        #expect(result.isEmpty)

        cleanup()
    }

    @Test
    func scanReturnsEmptyWhenAgentDirectoryHasNoSkillsSubdir() throws {
        let agentDir = tmpRoot.appendingPathComponent(".agent")
        try FileManager.default.createDirectory(at: agentDir, withIntermediateDirectories: true)

        let result = scanner.scanSkills(projectPath: tmpRoot.path)
        #expect(result.isEmpty)

        cleanup()
    }

    // MARK: - Valid Skills

    @Test
    func scanReturnsSingleSkill() throws {
        try createSkill(name: "swiftui-expert", title: "SwiftUI Expert", description: "SwiftUI best practices")

        let result = scanner.scanSkills(projectPath: tmpRoot.path)

        #expect(result.count == 1)
        let skill = try #require(result.first)
        #expect(skill.name == "swiftui-expert")
        #expect(skill.title == "SwiftUI Expert")
        #expect(skill.description == "SwiftUI best practices")
        #expect(skill.contentPath.hasSuffix("SKILL.md"))

        cleanup()
    }

    @Test
    func scanReturnsMultipleSkillsSortedByName() throws {
        try createSkill(name: "zebra", title: "Zebra", description: "Z skill")
        try createSkill(name: "alpha", title: "Alpha", description: "A skill")
        try createSkill(name: "middle", title: "Middle", description: "M skill")

        let result = scanner.scanSkills(projectPath: tmpRoot.path)

        #expect(result.count == 3)
        #expect(result[0].name == "alpha")
        #expect(result[1].name == "middle")
        #expect(result[2].name == "zebra")

        cleanup()
    }

    @Test
    func scanPreservesMetadataFields() throws {
        try createSkill(
            name: "git-workflow",
            title: "Git Workflow",
            description: "Strict git conventions",
            version: "2.1.0",
            triggers: ["git", "commit"]
        )

        let result = scanner.scanSkills(projectPath: tmpRoot.path)
        let skill = try #require(result.first)

        #expect(skill.name == "git-workflow")
        #expect(skill.title == "Git Workflow")
        #expect(skill.description == "Strict git conventions")
        #expect(skill.version == "2.1.0")
        #expect(skill.triggers == ["git", "commit"])
        #expect(skill.modifiedAt <= Date())

        cleanup()
    }

    @Test
    func scanSetsContentPathToSkillMD() throws {
        try createSkill(name: "my-skill")

        let result = scanner.scanSkills(projectPath: tmpRoot.path)
        let skill = try #require(result.first)

        #expect(skill.contentPath.hasSuffix(".agent/skills/my-skill/SKILL.md"))
        #expect(FileManager.default.fileExists(atPath: skill.contentPath))

        cleanup()
    }

    // MARK: - Content Loading

    @Test
    func loadContentReturnsSkillMDContent() throws {
        let content = "# My Skill\n\n## Instructions\n\nDo this, not that."
        try createSkill(name: "loadable", skillContent: content)

        let result = scanner.scanSkills(projectPath: tmpRoot.path)
        let skill = try #require(result.first)

        let loadedContent = try skill.loadContent()
        #expect(loadedContent == content)

        cleanup()
    }

    @Test
    func loadContentPreservesMultilineAndUnicode() throws {
        let content = "# 中文技能\n\n## 指令\n\n- 步骤一\n- 步骤二\n\n🎉 Done!"
        try createSkill(name: "unicode", skillContent: content)

        let result = scanner.scanSkills(projectPath: tmpRoot.path)
        let skill = try #require(result.first)

        let loadedContent = try skill.loadContent()
        #expect(loadedContent.contains("中文技能"))
        #expect(loadedContent.contains("🎉 Done!"))

        cleanup()
    }

    // MARK: - Incomplete / Invalid Skills

    @Test
    func scanSkipsSkillWithoutSKILLMD() throws {
        try createSkill(name: "valid-skill")
        try createIncompleteSkill(name: "incomplete-skill")

        let result = scanner.scanSkills(projectPath: tmpRoot.path)

        #expect(result.count == 1)
        #expect(result.first?.name == "valid-skill")

        cleanup()
    }

    @Test
    func scanSkipsDirectoryWithInvalidMetadataJSON() throws {
        let skillDir = tmpRoot.appendingPathComponent(".agent/skills/bad-json")
        try FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)

        try "not valid json {{{".write(
            to: skillDir.appendingPathComponent("metadata.json"),
            atomically: true,
            encoding: .utf8
        )
        try "# Skill".write(
            to: skillDir.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )

        let result = scanner.scanSkills(projectPath: tmpRoot.path)
        #expect(result.isEmpty)

        cleanup()
    }

    @Test
    func scanSkipsMetadataMissingRequiredFields() throws {
        let skillDir = tmpRoot.appendingPathComponent(".agent/skills/no-title")
        try FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)

        let json = """
        {
            "name": "no-title",
            "description": "Missing title"
        }
        """
        try json.write(
            to: skillDir.appendingPathComponent("metadata.json"),
            atomically: true,
            encoding: .utf8
        )
        try "# Skill".write(
            to: skillDir.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )

        let result = scanner.scanSkills(projectPath: tmpRoot.path)
        #expect(result.isEmpty)

        cleanup()
    }

    @Test
    func scanSkipsPlainFilesInSkillsDirectory() throws {
        try createSkill(name: "valid-skill")

        let skillsDir = tmpRoot.appendingPathComponent(".agent/skills")
        try "just a file".write(
            to: skillsDir.appendingPathComponent("README.md"),
            atomically: true,
            encoding: .utf8
        )

        let result = scanner.scanSkills(projectPath: tmpRoot.path)

        #expect(result.count == 1)
        #expect(result.first?.name == "valid-skill")

        cleanup()
    }

    @Test
    func scanSkipsHiddenDirectories() throws {
        try createSkill(name: "visible-skill")

        let hiddenDir = tmpRoot.appendingPathComponent(".agent/skills/.hidden-skill")
        try FileManager.default.createDirectory(at: hiddenDir, withIntermediateDirectories: true)
        let metadata: [String: Any] = [
            "name": "hidden-skill",
            "title": "Hidden",
            "description": "Should be skipped"
        ]
        let data = try JSONSerialization.data(withJSONObject: metadata)
        try data.write(to: hiddenDir.appendingPathComponent("metadata.json"))
        try "# Hidden".write(
            to: hiddenDir.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )

        let result = scanner.scanSkills(projectPath: tmpRoot.path)

        #expect(result.count == 1)
        #expect(result.first?.name == "visible-skill")

        cleanup()
    }

    // MARK: - Validation

    @Test
    func scanSkipsSkillWithBlankName() throws {
        let skillDir = tmpRoot.appendingPathComponent(".agent/skills/blank-name")
        try FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)

        let json = """
        {
            "name": "   ",
            "title": "Valid Title",
            "description": "Name is whitespace"
        }
        """
        try json.write(
            to: skillDir.appendingPathComponent("metadata.json"),
            atomically: true,
            encoding: .utf8
        )
        try "# Skill".write(
            to: skillDir.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )

        let result = scanner.scanSkills(projectPath: tmpRoot.path)
        #expect(result.isEmpty)

        cleanup()
    }

    @Test
    func scanSkipsSkillWithBlankTitle() throws {
        let skillDir = tmpRoot.appendingPathComponent(".agent/skills/blank-title")
        try FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)

        let json = """
        {
            "name": "valid-name",
            "title": "",
            "description": "Title is empty"
        }
        """
        try json.write(
            to: skillDir.appendingPathComponent("metadata.json"),
            atomically: true,
            encoding: .utf8
        )
        try "# Skill".write(
            to: skillDir.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )

        let result = scanner.scanSkills(projectPath: tmpRoot.path)
        #expect(result.isEmpty)

        cleanup()
    }

    @Test
    func scanSkipsOversizedMetadataFile() throws {
        let skillDir = tmpRoot.appendingPathComponent(".agent/skills/oversized")
        try FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)

        // Create a scanner with a very small size limit (10 bytes)
        let strictScanner = SkillScanner(maxMetadataSize: 10)

        let json = """
        {
            "name": "oversized",
            "title": "Big Skill",
            "description": "Should be skipped due to size"
        }
        """
        try json.write(
            to: skillDir.appendingPathComponent("metadata.json"),
            atomically: true,
            encoding: .utf8
        )
        try "# Skill".write(
            to: skillDir.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )

        let result = strictScanner.scanSkills(projectPath: tmpRoot.path)
        #expect(result.isEmpty)

        cleanup()
    }

    @Test
    func scanRespectsMaxSkillCount() throws {
        let limitedScanner = SkillScanner(maxSkillCount: 2)

        try createSkill(name: "a", title: "A", description: "First")
        try createSkill(name: "b", title: "B", description: "Second")
        try createSkill(name: "c", title: "C", description: "Third")

        let result = limitedScanner.scanSkills(projectPath: tmpRoot.path)
        #expect(result.count == 2)

        cleanup()
    }

    // MARK: - Edge Cases

    @Test
    func scanHandlesSkillWithEmptyTriggers() throws {
        try createSkill(name: "no-triggers", triggers: [])

        let result = scanner.scanSkills(projectPath: tmpRoot.path)
        let skill = try #require(result.first)

        #expect(skill.triggers.isEmpty)

        cleanup()
    }

    @Test
    func scanHandlesSkillWithSpecialCharactersInName() throws {
        try createSkill(name: "my-cool_skill.v2", title: "Special Name")

        let result = scanner.scanSkills(projectPath: tmpRoot.path)
        let skill = try #require(result.first)

        #expect(skill.name == "my-cool_skill.v2")
        #expect(skill.title == "Special Name")

        cleanup()
    }
}
