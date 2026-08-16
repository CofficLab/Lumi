import Foundation
import ProviderMessage
import ProviderLLM

@MainActor
public final class DefaultAgentLoopProviding: AgentLoopProviding {
    private let messages: any MessageManaging
    private var responder: AgentLoopResponder?
    private var llmProvider: (any LLMProviding)?
    private var states: [UUID: AgentLoopState] = [:]
    private var tasks: [UUID: Task<AgentLoopOutcome, Never>] = [:]

    @Published public private(set) var revision: Int = 0

    public init(messages: any MessageManaging, llmProvider: (any LLMProviding)? = nil) {
        self.messages = messages
        self.llmProvider = llmProvider
    }

    public func setResponder(_ responder: AgentLoopResponder?) {
        self.responder = responder
    }

    public func setLLMProvider(_ provider: (any LLMProviding)?) {
        llmProvider = provider
    }

    public func state(for conversationID: UUID) -> AgentLoopState {
        states[conversationID] ?? .idle
    }

    public func cancelTurn(in conversationID: UUID) {
        tasks[conversationID]?.cancel()
        tasks[conversationID] = nil
        states[conversationID] = .cancelled
        revision += 1
    }

    public func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome {
        guard state(for: conversationID) != .running else { return .failed("turn already running") }
        guard responder != nil || llmProvider != nil else {
            states[conversationID] = .failed
            revision += 1
            return .failed("agent responder is not configured")
        }

        states[conversationID] = .running
        revision += 1
        let request = AgentLoopRequest(
            conversationID: conversationID,
            messages: messages.messages(for: conversationID)
        )

        let task: Task<AgentLoopOutcome, Never> = Task { @MainActor [weak self] in
            guard let self else { return AgentLoopOutcome.cancelled }
            do {
                let content: String
                if let responder {
                    content = try await responder(request)
                } else if let llmProvider {
                    let response = try await llmProvider.complete(
                        LLMRequest(conversationID: request.conversationID, messages: request.messages)
                    )
                    content = response.content
                } else {
                    throw LLMProviderError.notConfigured
                }
                try Task.checkCancellation()
                let assistant = Message(
                    conversationID: conversationID,
                    role: .assistant,
                    content: content
                )
                messages.insertMessage(assistant, to: conversationID)
                states[conversationID] = .completed
                revision += 1
                return .completed
            } catch is CancellationError {
                states[conversationID] = .cancelled
                revision += 1
                return .cancelled
            } catch {
                states[conversationID] = .failed
                revision += 1
                return .failed(String(describing: error))
            }
        }
        tasks[conversationID] = task
        let outcome = await task.value
        tasks[conversationID] = nil
        return outcome
    }
}
