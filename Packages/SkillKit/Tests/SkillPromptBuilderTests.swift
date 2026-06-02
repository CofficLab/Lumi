import Foundation
import Testing
@testable import SkillKit

// MARK: - SkillPromptBuilder Tests

struct SkillPromptBuilderTests {

    // MARK: - Empty Input

    @Test
    func buildPromptWithEmptyListStillContainsHeader() {
        let prompt = SkillPromptBuilder.buildPrompt(skills: [])

        #expect(prompt.contains("## Available Skills"))
        #expect(prompt.contains("| Skill | Description |"))
        #expect(prompt.contains("|-------|-------------|"))
    }

    // MARK: - Single Skill

    @Test
    func buildPromptIncludesSingleSkill() {
        let skills = [
            SkillMetadata(name: "swiftui", title: "SwiftUI", description: "SwiftUI best practices")
        ]
        let prompt = SkillPromptBuilder.buildPrompt(skills: skills)

        #expect(prompt.contains("| `swiftui` | SwiftUI best practices |"))
    }

    // MARK: - Multiple Skills

    @Test
    func buildPromptIncludesAllSkillsInTable() {
        let skills = [
            SkillMetadata(name: "alpha", title: "Alpha", description: "First skill"),
            SkillMetadata(name: "beta", title: "Beta", description: "Second skill"),
            SkillMetadata(name: "gamma", title: "Gamma", description: "Third skill")
        ]
        let prompt = SkillPromptBuilder.buildPrompt(skills: skills)

        #expect(prompt.contains("| `alpha` | First skill |"))
        #expect(prompt.contains("| `beta` | Second skill |"))
        #expect(prompt.contains("| `gamma` | Third skill |"))
    }

    // MARK: - Activation Instruction

    @Test
    func buildPromptIncludesActivationInstruction() {
        let skills = [
            SkillMetadata(name: "test", title: "Test", description: "Desc")
        ]
        let prompt = SkillPromptBuilder.buildPrompt(skills: skills)

        #expect(prompt.contains("[Skill: <skill-name>]"))
        #expect(prompt.contains("start your response"))
    }

    // MARK: - Pipe Escaping

    @Test
    func buildPromptEscapesPipesInDescription() {
        let skills = [
            SkillMetadata(
                name: "table-skill",
                title: "Table Skill",
                description: "Column A | Column B | Column C"
            )
        ]
        let prompt = SkillPromptBuilder.buildPrompt(skills: skills)

        #expect(prompt.contains("Column A \\| Column B \\| Column C"))
        #expect(prompt.contains("| `table-skill` | Column A \\| Column B \\| Column C |"))
    }

    // MARK: - Whitespace Trimming

    @Test
    func buildPromptTrimsDescriptionWhitespace() {
        let skills = [
            SkillMetadata(
                name: "ws-skill",
                title: "WS",
                description: "  description with spaces  "
            )
        ]
        let prompt = SkillPromptBuilder.buildPrompt(skills: skills)

        #expect(prompt.contains("description with spaces"))
        #expect(!prompt.contains("|   description"))
    }

    // MARK: - Newline in Description

    @Test
    func buildPromptReplacesNewlinesInDescription() {
        let skills = [
            SkillMetadata(
                name: "nl",
                title: "NL",
                description: "Line one\nLine two\nLine three"
            )
        ]
        let prompt = SkillPromptBuilder.buildPrompt(skills: skills)

        // Newlines should be replaced with spaces to avoid breaking the table
        #expect(!prompt.contains("Line one\nLine two"))
        #expect(prompt.contains("Line one Line two Line three"))
    }

    // MARK: - Backtick Escaping in Name

    @Test
    func buildPromptEscapesBackticksInName() {
        let skills = [
            SkillMetadata(name: "skill`with`backticks", title: "BT", description: "Has backticks")
        ]
        let prompt = SkillPromptBuilder.buildPrompt(skills: skills)

        #expect(prompt.contains("skill\\`with\\`backticks"))
    }

    @Test
    func buildPromptEscapesBackslashInName() {
        let skills = [
            SkillMetadata(name: "skill\\backslash", title: "BS", description: "Has backslash")
        ]
        let prompt = SkillPromptBuilder.buildPrompt(skills: skills)

        #expect(prompt.contains("skill\\\\backslash"))
    }

    // MARK: - Special Characters

    @Test
    func buildPromptHandlesUnicodeInDescription() {
        let skills = [
            SkillMetadata(name: "cn", title: "Chinese", description: "中文描述 🎉")
        ]
        let prompt = SkillPromptBuilder.buildPrompt(skills: skills)

        #expect(prompt.contains("中文描述 🎉"))
    }

    @Test
    func buildPromptHandlesMarkdownInDescription() {
        let skills = [
            SkillMetadata(
                name: "md-skill",
                title: "MD",
                description: "Contains **bold** and _italic_ and `code`"
            )
        ]
        let prompt = SkillPromptBuilder.buildPrompt(skills: skills)

        #expect(prompt.contains("**bold**"))
        #expect(prompt.contains("_italic_"))
        #expect(prompt.contains("`code`"))
    }

    // MARK: - Structure Validation

    @Test
    func buildPromptFormatIsConsistent() {
        let skills = [
            SkillMetadata(name: "a", title: "A", description: "Skill A"),
            SkillMetadata(name: "b", title: "B", description: "Skill B")
        ]
        let prompt = SkillPromptBuilder.buildPrompt(skills: skills)
        let lines = prompt.components(separatedBy: "\n")

        #expect(lines[0] == "## Available Skills")
        #expect(lines.contains("| Skill | Description |"))
        #expect(lines.contains("|-------|-------------|"))

        let nonEmptyLines = lines.filter { !$0.isEmpty }
        #expect(nonEmptyLines.last?.contains("[Skill: <skill-name>]") == true)
    }

    // MARK: - Truncation

    @Test
    func buildPromptTruncatesWhenExceedsMaxSkills() {
        var skills: [SkillMetadata] = []
        for i in 0..<15 {
            skills.append(SkillMetadata(name: "skill-\(i)", title: "Skill \(i)", description: "Description \(i)"))
        }

        let prompt = SkillPromptBuilder.buildPrompt(skills: skills, maxSkills: 5)

        // Should contain first 5
        for i in 0..<5 {
            #expect(prompt.contains("`skill-\(i)`"))
        }
        // Should NOT contain the rest
        for i in 5..<15 {
            #expect(!prompt.contains("`skill-\(i)`"))
        }

        // Should contain truncation notice
        #expect(prompt.contains("Showing 5 of 15 skills"))
    }

    @Test
    func buildPromptNoTruncationNoticeWhenWithinLimit() {
        let skills = (0..<5).map { SkillMetadata(name: "skill-\($0)", title: "S\($0)", description: "D\($0)") }

        let prompt = SkillPromptBuilder.buildPrompt(skills: skills, maxSkills: 10)

        #expect(!prompt.contains("Showing"))
    }

    // MARK: - Large Skill Set

    @Test
    func buildPromptHandlesManySkills() {
        var skills: [SkillMetadata] = []
        for i in 0..<50 {
            skills.append(SkillMetadata(name: "skill-\(i)", title: "Skill \(i)", description: "Description \(i)"))
        }

        let prompt = SkillPromptBuilder.buildPrompt(skills: skills)

        for i in 0..<SkillPromptBuilder.defaultMaxSkills {
            #expect(prompt.contains("`skill-\(i)`"))
        }

        #expect(prompt.contains("## Available Skills"))
        #expect(prompt.contains("[Skill: <skill-name>]"))
    }

    // MARK: - DefaultMaxSkills Value

    @Test
    func defaultMaxSkillsIsTen() {
        #expect(SkillPromptBuilder.defaultMaxSkills == 10)
    }
}
