import Foundation
import Testing
@testable import AgentToolKit

// MARK: - ToolCall

struct ToolCallTests {
    @Test
    func initStoresAllFields() {
        let call = ToolCall(
            id: "call_1",
            name: "read_file",
            arguments: #"{"path":"README.md"}"#,
            authorizationState: .userApproved
        )

        #expect(call.id == "call_1")
        #expect(call.name == "read_file")
        #expect(call.arguments == #"{"path":"README.md"}"#)
        #expect(call.authorizationState == .userApproved)
    }

    @Test
    func initDefaultsAuthorizationStateToPending() {
        let call = ToolCall(id: "call_1", name: "read_file", arguments: "{}")
        #expect(call.authorizationState == .pendingAuthorization)
    }

    @Test
    func codableRoundTripPreservesExplicitAuthorizationState() throws {
        let original = ToolCall(
            id: "call_2",
            name: "write_file",
            arguments: #"{"path":"out.txt"}"#,
            authorizationState: .autoApproved
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ToolCall.self, from: data)

        #expect(decoded == original)
    }

    @Test
    func decodeDefaultsMissingAuthorizationStateToPending() throws {
        let json = """
        {
            "id": "call_3",
            "name": "list_dir",
            "arguments": "{}"
        }
        """
        let decoded = try JSONDecoder().decode(ToolCall.self, from: Data(json.utf8))
        #expect(decoded.authorizationState == .pendingAuthorization)
    }

    @Test
    func encodeOmitsPendingAuthorizationState() throws {
        let call = ToolCall(id: "call_4", name: "read_file", arguments: "{}")
        let data = try JSONEncoder().encode(call)
        let json = String(decoding: data, as: UTF8.self)

        #expect(!json.contains("authorizationState"))
    }

    @Test
    func encodeIncludesNonPendingAuthorizationState() throws {
        let call = ToolCall(
            id: "call_5",
            name: "shell",
            arguments: #"{"command":"ls"}"#,
            authorizationState: .userRejected
        )
        let data = try JSONEncoder().encode(call)
        let decoded = try JSONDecoder().decode(ToolCall.self, from: data)

        #expect(decoded.authorizationState == .userRejected)
    }

    @Test
    func equatableComparesAllFields() {
        let a = ToolCall(id: "1", name: "a", arguments: "{}", authorizationState: .noRisk)
        let b = ToolCall(id: "1", name: "a", arguments: "{}", authorizationState: .noRisk)
        let c = ToolCall(id: "1", name: "a", arguments: "{}", authorizationState: .userApproved)

        #expect(a == b)
        #expect(a != c)
    }
}

// MARK: - ToolCallAuthorizationState

struct ToolCallAuthorizationStateTests {
    @Test
    func displayNamesAreNonEmpty() {
        for state in ToolCallAuthorizationState.allCases {
            #expect(!state.displayName.isEmpty)
        }
    }

    @Test
    func onlyPendingNeedsAuthorizationPrompt() {
        #expect(ToolCallAuthorizationState.pendingAuthorization.needsAuthorizationPrompt)
        #expect(!ToolCallAuthorizationState.noRisk.needsAuthorizationPrompt)
        #expect(!ToolCallAuthorizationState.autoApproved.needsAuthorizationPrompt)
        #expect(!ToolCallAuthorizationState.userApproved.needsAuthorizationPrompt)
        #expect(!ToolCallAuthorizationState.userRejected.needsAuthorizationPrompt)
    }

    @Test
    func codableRoundTripPreservesAllCases() throws {
        for state in ToolCallAuthorizationState.allCases {
            let data = try JSONEncoder().encode(state)
            let decoded = try JSONDecoder().decode(ToolCallAuthorizationState.self, from: data)
            #expect(decoded == state)
        }
    }
}

// MARK: - CommandRiskLevel

struct CommandRiskLevelTests {
    @Test
    func onlyHighRequiresPermission() {
        #expect(!CommandRiskLevel.safe.requiresPermission)
        #expect(!CommandRiskLevel.low.requiresPermission)
        #expect(!CommandRiskLevel.medium.requiresPermission)
        #expect(CommandRiskLevel.high.requiresPermission)
    }

    @Test
    func displayNamesAreNonEmpty() {
        for level in [CommandRiskLevel.safe, .low, .medium, .high] {
            #expect(!level.displayName.isEmpty)
        }
    }

    @Test
    func reasonIsNilOnlyForSafe() {
        #expect(CommandRiskLevel.safe.reason == nil)
        #expect(CommandRiskLevel.low.reason != nil)
        #expect(CommandRiskLevel.medium.reason != nil)
        #expect(CommandRiskLevel.high.reason != nil)
    }

    @Test
    func codableRoundTripPreservesRawValues() throws {
        for level in [CommandRiskLevel.safe, .low, .medium, .high] {
            let data = try JSONEncoder().encode(level)
            let decoded = try JSONDecoder().decode(CommandRiskLevel.self, from: data)
            #expect(decoded == level)
        }
    }
}

// MARK: - LanguagePreference

struct LanguagePreferenceTests {
    @Test
    func idMatchesRawValue() {
        #expect(LanguagePreference.chinese.id == "zh")
        #expect(LanguagePreference.english.id == "en")
    }

    @Test
    func systemPromptDescriptionMentionsLanguage() {
        #expect(LanguagePreference.chinese.systemPromptDescription.contains("中文"))
        #expect(LanguagePreference.english.systemPromptDescription.contains("English"))
    }

    @Test
    func codableRoundTripPreservesCases() throws {
        for language in LanguagePreference.allCases {
            let data = try JSONEncoder().encode(language)
            let decoded = try JSONDecoder().decode(LanguagePreference.self, from: data)
            #expect(decoded == language)
        }
    }
}

// MARK: - ToolArgument

struct ToolArgumentTests {
    @Test
    func storesArbitraryValue() {
        let stringArg = ToolArgument("hello")
        let intArg = ToolArgument(42)
        let boolArg = ToolArgument(true)

        #expect(stringArg.value as? String == "hello")
        #expect(intArg.value as? Int == 42)
        #expect(boolArg.value as? Bool == true)
    }
}

// MARK: - ImageAttachment

struct ImageAttachmentTests {
    @Test
    func initDefaultsIdWhenNotProvided() {
        let attachment = ImageAttachment(data: Data([0x01]), mimeType: "image/png")
        #expect(attachment.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
    }

    @Test
    func equalityIgnoresDataButComparesIdAndMimeType() {
        let id = UUID()
        let lhs = ImageAttachment(id: id, data: Data([0x01]), mimeType: "image/png")
        let rhs = ImageAttachment(id: id, data: Data([0x02, 0x03]), mimeType: "image/png")
        let other = ImageAttachment(id: id, data: Data([0x01]), mimeType: "image/jpeg")

        #expect(lhs == rhs)
        #expect(lhs != other)
    }

    @Test
    func codableRoundTripPreservesFields() throws {
        let id = UUID()
        let data = Data([0x89, 0x50, 0x4E, 0x47])
        let original = ImageAttachment(id: id, data: data, mimeType: "image/png")

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ImageAttachment.self, from: encoded)

        #expect(decoded.id == id)
        #expect(decoded.data == data)
        #expect(decoded.mimeType == "image/png")
    }
}

// MARK: - ToolCallResult

struct ToolCallResultTests {
    @Test
    func codableRoundTripPreservesFields() throws {
        let executedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let original = ToolCallResult(
            content: "file contents",
            images: [ImageAttachment(data: Data([0x01]), mimeType: "image/png")],
            isError: true,
            executedAt: executedAt
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ToolCallResult.self, from: data)

        #expect(decoded == original)
    }
}

extension ToolCallTests {
    @Test
    func codableRoundTripPreservesEmbeddedResult() throws {
        let result = ToolCallResult(content: "done")
        let original = ToolCall(
            id: "call_result",
            name: "read_file",
            arguments: "{}",
            authorizationState: .userApproved,
            result: result
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ToolCall.self, from: data)

        #expect(decoded == original)
        #expect(decoded.hasResult)
    }
}
