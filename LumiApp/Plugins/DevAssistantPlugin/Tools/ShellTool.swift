import Foundation

struct ShellTool: AgentTool {
    let name = "run_command"
    let description = "Execute a shell command in the terminal. Use this to run build commands, git commands, or other system tools."
    
    var inputSchema: [String: Any] {
        return [
            "type": "object",
            "properties": [
                "command": [
                    "type": "string",
                    "description": "The command string to execute (e.g., 'git status')"
                ]
            ],
            "required": ["command"]
        ]
    }
    
    // We inject the existing ShellService to reuse its logic
    private let shellService: ShellService
    
    init(shellService: ShellService) {
        self.shellService = shellService
    }
    
    func execute(arguments: [String: Any]) async throws -> String {
        guard let command = arguments["command"] as? String else {
            throw NSError(domain: "ShellTool", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing 'command' argument"])
        }
        
        // Future: Add permission check here
        
        do {
            let output = try await shellService.execute(command)
            return output
        } catch {
            return "Error executing command: \(error.localizedDescription)"
        }
    }
}
