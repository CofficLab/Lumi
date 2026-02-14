
import SwiftUI

struct MCPSettingsView: View {
    @StateObject private var mcpService = MCPService.shared
    @State private var newApiKey: String = ""
    @State private var isAddingVision: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MCP Servers")
                .font(.headline)
            
            // Server List
            if mcpService.configs.isEmpty {
                Text("No MCP servers configured.")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                List {
                    ForEach(mcpService.configs) { config in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(config.name)
                                    .fontWeight(.medium)
                                Text(config.command + " " + config.args.joined(separator: " "))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            
                            Spacer()
                            
                            // Status
                            if mcpService.connectedClients[config.name] != nil {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                    Text("Connected")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            } else {
                                VStack(alignment: .trailing) {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 8, height: 8)
                                        Text("Disconnected")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                    
                                    if let error = mcpService.connectionErrors[config.name] {
                                        Text(error)
                                            .font(.caption2)
                                            .foregroundColor(.red)
                                            .multilineTextAlignment(.trailing)
                                            .frame(maxWidth: 200)
                                    }
                                }
                            }
                            
                            Button(action: {
                                mcpService.removeConfig(name: config.name)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 8)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
                .frame(height: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }
            
            Divider()
            
            // Add Vision MCP Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Add Vision MCP Server")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    SecureField("Zhipu API Key", text: $newApiKey)
                        .textFieldStyle(.roundedBorder)
                    
                    Button(action: {
                        guard !newApiKey.isEmpty else { return }
                        mcpService.installVisionMCP(apiKey: newApiKey)
                        newApiKey = ""
                    }) {
                        Text("Install")
                    }
                    .disabled(newApiKey.isEmpty)
                }
                
                Text("This will install @z_ai/mcp-server via npx.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 500)
    }
}
