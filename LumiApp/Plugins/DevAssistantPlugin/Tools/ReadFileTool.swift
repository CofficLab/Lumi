import Foundation

struct ReadFileTool: AgentTool {
    let name = "read_file"
    let description = "Read the contents of a file at the given path. Use this to examine code or configuration files."
    
    var inputSchema: [String: Any] {
        return [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": "The absolute path to the file to read"
                ]
            ],
            "required": ["path"]
        ]
    }
    
    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let path = arguments["path"]?.value as? String else {
            throw NSError(domain: "ReadFileTool", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing 'path' argument"])
        }
        
        let fileURL = URL(fileURLWithPath: path)
        
        // Basic security check (sandbox might restrict this anyway)
        // For now, we rely on the user confirming the action if we add safety middleware later.
        // Reading is generally safe.
        
        do {
            let data = try Data(contentsOf: fileURL)
            guard let content = String(data: data, encoding: .utf8) else {
                return "Error: File content is not valid UTF-8 text."
            }
            
            // Limit output size to prevent context overflow (e.g., 50KB)
            if content.count > 50_000 {
                let prefix = content.prefix(50_000)
                return "\(prefix)\n... (File truncated due to size limit)"
            }
            
            return content
        } catch {
            return "Error reading file: \(error.localizedDescription)"
        }
    }
}
