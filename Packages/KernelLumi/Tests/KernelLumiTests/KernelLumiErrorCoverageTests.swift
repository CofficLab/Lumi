import Foundation
import Testing
@testable import KernelLumi

/// KernelLumi 覆盖率补充：错误描述与编辑器 V2 契约错误/命令模型的纯逻辑分支。
@Suite("KernelLumi Error Coverage")
struct KernelLumiErrorCoverageTests {

    // MARK: - KernelLumiError

    @Test("KernelLumiError 各 case 的错误描述")
    func kernelLumiErrorDescriptions() {
        #expect(
            KernelLumiError.pluginAlreadyRegistered(id: "p").errorDescription
                == "Plugin 'p' is already registered"
        )
        #expect(
            KernelLumiError.pluginNotFound(id: "q").errorDescription
                == "Plugin 'q' not found"
        )
        #expect(
            KernelLumiError.serviceAlreadyRegistered(type: Int.self).errorDescription
                == "Service 'Swift.Int' is already registered"
        )
        #expect(
            KernelLumiError.missingRequiredServices(["a", "b"]).errorDescription
                == "Missing required services: a, b"
        )
        #expect(
            KernelLumiError.serviceNotAvailable(service: "Chat").errorDescription
                == "Chat service is not available"
        )
        #expect(KernelLumiError.noActiveConversation.errorDescription != nil)
        #expect(KernelLumiError.llmProviderUnavailable.errorDescription != nil)
        #expect(KernelLumiError.invalidProviderOrModel.errorDescription != nil)
        #expect(
            KernelLumiError.llmProviderRegistrationFailed(providerType: "openai", reason: "bad key").errorDescription
                == "Failed to register LLM provider 'openai': bad key"
        )
        #expect(
            KernelLumiError.networkRequestFailed(url: "https://x", reason: "offline").errorDescription
                == "Network request to 'https://x' failed: offline"
        )
        #expect(
            KernelLumiError.networkInvalidResponse(url: "https://x").errorDescription
                == "Invalid response from 'https://x'"
        )
        #expect(
            KernelLumiError.networkTimeout(url: "https://x", timeout: 3.25).errorDescription
                == "Request to 'https://x' timed out after 3.2s"
        )
        #expect(
            KernelLumiError.networkHTTPError(url: "https://x", statusCode: 500).errorDescription
                == "HTTP error 500 for 'https://x'"
        )
    }

    // MARK: - AgentTurnManagingError / HTTPNetworkError / LegacyDataError

    @Test("AgentTurnManagingError 各 case 有描述")
    func agentTurnErrorDescriptions() {
        let all: [AgentTurnManagingError] = [
            .createNotSupported, .invalidCreationRequest, .resumeNotSupported,
            .invalidResumeRequest, .turnFailed,
        ]
        #expect(all.allSatisfy { $0.errorDescription?.isEmpty == false })
    }

    @Test("HTTPNetworkError 带状态码与不带状态码的描述")
    func httpNetworkErrorDescriptions() {
        let url = URL(string: "https://example.com")!
        #expect(
            HTTPNetworkError(url: url, statusCode: 502).errorDescription
                == "HTTP error 502 for 'https://example.com'"
        )
        #expect(
            HTTPNetworkError(url: url, underlyingDescription: "lost").errorDescription
                == "Network request to 'https://example.com' failed: lost"
        )
        #expect(
            HTTPNetworkError(url: url).errorDescription
                == "Network request to 'https://example.com' failed: unknown error"
        )
    }

    @Test("LegacyDataError 各 case 有描述")
    func legacyDataErrorDescriptions() {
        struct Dummy: Error, LocalizedError { var errorDescription: String? { "dummy" } }
        #expect(LegacyDataError.legacyDataNotFound.errorDescription != nil)
        #expect(LegacyDataError.snapshotCopyFailed(underlying: Dummy()).errorDescription?.contains("dummy") == true)
        #expect(LegacyDataError.openFailed(underlying: Dummy()).errorDescription?.contains("dummy") == true)
        #expect(
            LegacyDataError.fetchFailed(entity: "Message", underlying: Dummy()).errorDescription
                == "Failed to fetch legacy 'Message': dummy"
        )
    }

    // MARK: - LumiLLMProviderSupportError

    @Test("LumiLLMProviderSupportError 的重试策略与描述")
    func llmProviderSupportError() {
        #expect(LumiLLMProviderSupportError.emptyConversation.llmErrorDisposition == .nonRetryable)
        #expect(LumiLLMProviderSupportError.invalidBaseURL("://").llmErrorDisposition == .nonRetryable)
        #expect(LumiLLMProviderSupportError.missingAPIKey("openai").llmErrorDisposition == .nonRetryable)
        #expect(
            LumiLLMProviderSupportError.apiKeyAccessFailed(provider: "openai", details: "denied").llmErrorDisposition
                == .retryable(delay: 2.0)
        )
        #expect(LumiLLMProviderSupportError.allEndpointsFailed.llmErrorDisposition == .retryable(delay: 2.0))
        #expect(LumiLLMProviderSupportError.streamingFailed("eof").llmErrorDisposition == .retryable(delay: 2.0))
        #expect(LumiLLMProviderSupportError.emptyResponse.llmErrorDisposition == .retryable(delay: 2.0))

        #expect(LumiLLMProviderSupportError.emptyConversation.errorDescription == "Conversation is empty")
        #expect(LumiLLMProviderSupportError.invalidBaseURL("bad").errorDescription == "Invalid base URL: bad")
        #expect(LumiLLMProviderSupportError.missingAPIKey("p").errorDescription == "Missing API key for: p")
        #expect(
            LumiLLMProviderSupportError.apiKeyAccessFailed(provider: "p", details: "d").errorDescription
                == "p API Key could not be read from macOS Keychain. d"
        )
        #expect(LumiLLMProviderSupportError.allEndpointsFailed.errorDescription == "All endpoints failed")
        #expect(LumiLLMProviderSupportError.streamingFailed("x").errorDescription == "Streaming failed: x")
        #expect(LumiLLMProviderSupportError.emptyResponse.errorDescription == "Empty response from provider")
    }

    // MARK: - LumiPluginContributionFailureAggregate / LumiToolRegistrationError

    @Test("插件贡献失败聚合错误的描述")
    func contributionFailureAggregate() {
        #expect(LumiPluginContributionFailureAggregate([]).errorDescription == "Plugin contribution failures")

        let aggregate = LumiPluginContributionFailureAggregate([
            LumiPluginContributionFailure(
                pluginID: "p1", pluginDisplayName: "Plugin One",
                contribution: "agentTools", errorDescription: "boom"
            ),
            LumiPluginContributionFailure(
                pluginID: "p2", pluginDisplayName: "Plugin Two",
                contribution: "commands", errorDescription: "bang"
            ),
        ])
        let text = aggregate.errorDescription ?? ""
        #expect(text.contains("- Plugin One [agentTools]: boom"))
        #expect(text.contains("- Plugin Two [commands]: bang"))
    }

    @Test("工具重名错误的描述与原因")
    func toolRegistrationError() {
        let error = LumiToolRegistrationError.duplicateNames([
            LumiToolDuplicateEntry(name: "read_file", owners: ["a", "b"]),
        ])
        #expect(error.errorDescription?.contains("read_file") == true)
        #expect(error.errorDescription?.contains("a, b") == true)
        #expect(error.failureReason != nil)
    }

    // MARK: - EditorContractError

    @Test("EditorContractError 瞬时判定")
    func editorContractErrorTransience() {
        #expect(EditorContractError.requestCancelled.isTransient)
        #expect(EditorContractError.requestTimedOut.isTransient)
        #expect(!EditorContractError.workspaceNotTrusted.isTransient)
        #expect(!EditorContractError.providerFailed(providerID: "p", reason: "r").isTransient)
    }

    @Test("EditorContractError 用户描述覆盖所有 case")
    func editorContractErrorUserDescriptions() {
        #expect(EditorContractError.capabilityUnavailable(feature: "rename").userDescription == "Capability unavailable: rename")
        #expect(EditorContractError.workspaceNotTrusted.userDescription == "This workspace is not trusted")
        #expect(EditorContractError.permissionDenied("fs").userDescription == "Permission denied: fs")
        #expect(EditorContractError.documentNotFound(EditorDocumentID(rawValue: UUID())).userDescription == "Document not found")
        #expect(EditorContractError.revisionMismatch(documentID: EditorDocumentID(rawValue: UUID()), expected: 1, actual: 2).userDescription == "The document changed while editing")
        #expect(EditorContractError.readOnlyDocument(EditorDocumentID(rawValue: UUID())).userDescription == "The document is read-only")
        #expect(EditorContractError.providerFailed(providerID: "p", reason: "r").userDescription == "The provider failed to complete the request")
        #expect(EditorContractError.requestCancelled.userDescription == "The request was cancelled")
        #expect(EditorContractError.requestTimedOut.userDescription == "The request timed out")
        #expect(EditorContractError.invalidWorkspaceEdit(reason: "overlap").userDescription == "The edit could not be applied")
        #expect(EditorContractError.externalFileConflict(EditorDocumentID(rawValue: UUID())).userDescription == "The file changed on disk")
        #expect(EditorContractError.largeFileRestriction(feature: "Folding").userDescription == "Folding is disabled for large files")
        #expect(EditorContractError.closeRequiresConfirmation(EditorSessionID(rawValue: UUID())).userDescription == "The tab has unsaved changes")
    }

    // MARK: - EditorCommandModels

    @Test("EditorKeybinding 展示标签")
    func keybindingDisplayLabel() {
        #expect(EditorKeybinding("⌘S").displayLabel == "⌘S")
        #expect(EditorKeybinding(chords: ["⌃⇧P", "⌘P"]).displayLabel == "⌃⇧P ⌘P")
    }

    @Test("EditorCommandContext 默认值")
    func commandContextDefaults() {
        let context = EditorCommandContext(document: nil)
        #expect(context.document == nil)
        #expect(!context.largeFileMode)
        #expect(context.workspaceTrusted)
    }

    @Test("EditorCommandPresentation 默认启用且无快捷键标签")
    func commandPresentationDefaults() {
        let presentation = EditorCommandPresentation(
            id: EditorCommandID(rawValue: "save"), title: "Save"
        )
        #expect(presentation.category.isEmpty)
        #expect(presentation.isEnabled)
        #expect(presentation.keybindingLabel == nil)
    }
}
