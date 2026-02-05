import Foundation
import Combine
import SwiftUI

@MainActor
class DevAssistantViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var currentInput: String = ""
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    
    // Config
    @AppStorage("DevAssistant_SelectedProvider") var selectedProvider: LLMProvider = .anthropic
    
    // Anthropic
    @AppStorage("DevAssistant_ApiKey_Anthropic") var apiKeyAnthropic: String = ""
    @AppStorage("DevAssistant_Model_Anthropic") var modelAnthropic: String = "claude-3-5-sonnet-20240620"
    
    // OpenAI
    @AppStorage("DevAssistant_ApiKey_OpenAI") var apiKeyOpenAI: String = ""
    @AppStorage("DevAssistant_Model_OpenAI") var modelOpenAI: String = "gpt-4o"
    @AppStorage("DevAssistant_BaseURL_OpenAI") var baseURLOpenAI: String = "https://api.openai.com/v1/chat/completions"
    
    // DeepSeek
    @AppStorage("DevAssistant_ApiKey_DeepSeek") var apiKeyDeepSeek: String = ""
    @AppStorage("DevAssistant_Model_DeepSeek") var modelDeepSeek: String = "deepseek-chat"
    @AppStorage("DevAssistant_BaseURL_DeepSeek") var baseURLDeepSeek: String = "https://api.deepseek.com/chat/completions"
    
    private let llmService = LLMService.shared
    private let shellService = ShellService.shared
    
    // System Prompt
    private let systemPrompt = """
    You are Claude Code, an expert software engineer and agentic coding tool.
    You can help the user with coding tasks, file exploration, and command execution.
    
    When you need to execute a terminal command, wrap it in <execute> tags.
    Example: <execute>ls -la</execute>
    
    When you need to read a file, use <read>path/to/file</read> (not implemented yet, treat as command cat).
    
    Be concise and helpful. Use markdown for code blocks.
    The user is on macOS.
    """
    
    init() {
        // Initialize with system prompt
        messages.append(ChatMessage(role: .system, content: systemPrompt))
        // Welcome message
        messages.append(ChatMessage(role: .assistant, content: "Hello! I am your Dev Assistant. How can I help you today?"))
    }
    
    func sendMessage() {
        guard !currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMsg = ChatMessage(role: .user, content: currentInput)
        messages.append(userMsg)
        currentInput = ""
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                let config = getCurrentConfig()
                
                // 1. Get LLM Response
                let responseText = try await llmService.sendMessage(messages: messages, config: config)
                
                // 2. Parse and display assistant message
                let assistantMsg = ChatMessage(role: .assistant, content: responseText)
                messages.append(assistantMsg)
                
                // 3. Check for commands
                await processCommands(in: responseText)
                
            } catch {
                errorMessage = error.localizedDescription
                messages.append(ChatMessage(role: .assistant, content: "Error: \(error.localizedDescription)", isError: true))
            }
            isProcessing = false
        }
    }
    
    private func processCommands(in text: String) async {
        // Regex to find <execute>...</execute>
        let pattern = "<execute>(.*?)</execute>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return }
        
        let nsString = text as NSString
        let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        
        for result in results {
            if let range = Range(result.range(at: 1), in: text) {
                let command = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Auto-execute for now (or ask user?)
                // For MVP, we'll append a message saying "Executing..." and then the result
                
                messages.append(ChatMessage(role: .assistant, content: "Executing: `\(command)`..."))
                
                do {
                    let output = try await shellService.execute(command)
                    messages.append(ChatMessage(role: .user, content: "Command Output:\n```\n\(output)\n```"))
                    
                    // Recursively send the output back to LLM? 
                    // For now, let's stop here to avoid infinite loops, or user can prompt "continue"
                    // Ideally, we should feed this back to LLM automatically.
                    
                    // Let's trigger one more turn automatically to let AI analyze the output
                    // But prevent deep recursion
                    if messages.filter({ $0.role == .user && $0.content.starts(with: "Command Output:") }).count < 5 {
                         await continueConversationWithOutput()
                    }
                    
                } catch {
                    messages.append(ChatMessage(role: .assistant, content: "Execution Failed: \(error.localizedDescription)", isError: true))
                }
            }
        }
    }
    
    private func continueConversationWithOutput() async {
        do {
             let config = getCurrentConfig()
             let responseText = try await llmService.sendMessage(messages: messages, config: config)
             let assistantMsg = ChatMessage(role: .assistant, content: responseText)
             messages.append(assistantMsg)
             await processCommands(in: responseText)
        } catch {
            // Ignore errors in auto-continuation
        }
    }
    
    func clearHistory() {
        messages = [ChatMessage(role: .system, content: systemPrompt)]
    }
    
    private func getCurrentConfig() -> LLMConfig {
        switch selectedProvider {
        case .anthropic:
            return LLMConfig(apiKey: apiKeyAnthropic, model: modelAnthropic, provider: .anthropic)
        case .openai:
            return LLMConfig(apiKey: apiKeyOpenAI, model: modelOpenAI, provider: .openai, baseURL: baseURLOpenAI)
        case .deepseek:
            return LLMConfig(apiKey: apiKeyDeepSeek, model: modelDeepSeek, provider: .deepseek, baseURL: baseURLDeepSeek)
        }
    }
    
    // Helpers for View Binding
    var currentModel: String {
        get {
            switch selectedProvider {
            case .anthropic: return modelAnthropic
            case .openai: return modelOpenAI
            case .deepseek: return modelDeepSeek
            }
        }
        set {
            switch selectedProvider {
            case .anthropic: modelAnthropic = newValue
            case .openai: modelOpenAI = newValue
            case .deepseek: modelDeepSeek = newValue
            }
        }
    }
}
