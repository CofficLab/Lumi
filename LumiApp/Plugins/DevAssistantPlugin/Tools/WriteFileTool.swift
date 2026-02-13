import Foundation

struct WriteFileTool: AgentTool {
    let name = "write_file"
    let description = "Create a new file or overwrite an existing file with the given content."
    
    var inputSchema: [String: Any] {
        return [
            "type": "object",
            "properties": [
                "path": [
                    "type": "string",
                    "description": "The absolute path to the file to write"
                ],
                "content": [
                    "type": "string",
                    "description": "The full content to write to the file"
                ]
            ],
            "required": ["path", "content"]
        ]
    }
    
    func execute(arguments: [String: Any]) async throws -> String {
        guard let path = arguments["path"] as? String,
              let content = arguments["content"] as? String else {
            throw NSError(domain: "WriteFileTool", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing 'path' or 'content' argument"])
        }
        
        let fileURL = URL(fileURLWithPath: path)
        let directoryURL = fileURL.deletingLastPathComponent()
        
        // Ensure directory exists
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: directoryURL.path) {
            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            } catch {
                return "Error creating directory: \(error.localizedDescription)"
            }
        }
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return "Successfully wrote to \(path)"
        } catch {
            return "Error writing file: \(error.localizedDescription)"
        }
    }
}
