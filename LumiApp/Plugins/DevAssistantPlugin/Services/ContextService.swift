import Foundation
import Combine

actor ContextService {
    static let shared = ContextService()
    
    private(set) var projectRoot: URL?
    private(set) var openFiles: [URL] = []
    
    // Limits
    private let maxContextTokens = 100_000 // Approximate
    
    func setProjectRoot(_ url: URL) {
        self.projectRoot = url
    }
    
    func getContextPrompt() -> String {
        var prompt = "## Current Context\n"
        
        if let root = projectRoot {
            prompt += "- Project Root: \(root.path)\n"
        } else {
            prompt += "- Project Root: Not set (using current working directory)\n"
        }
        
        // Add Date
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        prompt += "- Date: \(dateFormatter.string(from: Date()))\n"
        
        // Add System Info
        prompt += "- OS: macOS \(ProcessInfo.processInfo.operatingSystemVersionString)\n"
        
        return prompt
    }
    
    // Future: Add file caching, git status, etc.
}
