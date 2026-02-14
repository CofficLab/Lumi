
import SwiftUI

struct MCPSettingsView: View {
    @StateObject private var mcpService = MCPService.shared
    @State private var selectedTab: Int = 0
    
    // Installation State
    @State private var selectedMarketplaceItem: MCPMarketplaceItem?
    @State private var envVarInputs: [String: String] = [:]
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Installed", tableName: "DevAssistant").tag(0)
                Text("Marketplace", tableName: "DevAssistant").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            
            if selectedTab == 0 {
                InstalledServersView()
            } else {
                MarketplaceView(selectedItem: $selectedMarketplaceItem)
            }
        }
        .frame(width: 500, height: 400)
        .sheet(item: $selectedMarketplaceItem) { item in
            InstallSheet(item: item, envVarInputs: $envVarInputs, onInstall: {
                install(item: item)
                selectedMarketplaceItem = nil
                selectedTab = 0 // Switch to installed tab
            })
        }
    }
    
    func install(item: MCPMarketplaceItem) {
        // Construct args and env
        let config = MCPServerConfig(
            name: item.name,
            command: item.command,
            args: item.args,
            env: envVarInputs,
            homepage: item.documentationURL
        )
        mcpService.addConfig(config)
    }
}

struct InstalledServersView: View {
    @ObservedObject var mcpService = MCPService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if mcpService.configs.isEmpty {
                emptyStateView
            } else {
                serverListView
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No MCP servers configured", tableName: "DevAssistant")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Go to Marketplace to install servers", tableName: "DevAssistant")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var serverListView: some View {
        List {
            ForEach(Array(mcpService.configs.enumerated()), id: \.element.name) { index, config in
                ServerRow(config: config, mcpService: mcpService)
            }
        }
        .listStyle(.plain)
    }
    
    struct ServerRow: View {
        let config: MCPServerConfig
        @ObservedObject var mcpService: MCPService
        @State private var isExpanded: Bool = false
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Expand/Collapse Button
                    Button(action: {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(config.name)
                            .fontWeight(.medium)
                        if !isExpanded {
                            Text(config.command + " " + config.args.joined(separator: " "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    
                    Spacer()
                    
                    // Status
                    if mcpService.connectedClients[config.name] != nil {
                        MCPStatusBadge(isConnected: true)
                    } else {
                        VStack(alignment: .trailing) {
                            MCPStatusBadge(isConnected: false)
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
                
                if isExpanded {
                    VStack(alignment: .leading, spacing: 12) {
                        Divider()
                        
                        // Command Info
                        VStack(alignment: .leading, spacing: 4) {
                            if let homepage = config.homepage, let url = URL(string: homepage) {
                                Link(destination: url) {
                                    HStack(spacing: 4) {
                                        Text("HOMEPAGE", tableName: "DevAssistant")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                        Image(systemName: "arrow.up.right.square")
                                            .font(.system(size: 10))
                                    }
                                    .foregroundColor(.accentColor)
                                }
                                .padding(.bottom, 4)
                            }
                            
                            Text("COMMAND", tableName: "DevAssistant")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                            
                            HStack(alignment: .top, spacing: 4) {
                                Text(config.command)
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(4)
                                    .background(Color.black.opacity(0.05))
                                    .cornerRadius(4)
                                
                                ForEach(config.args, id: \.self) { arg in
                                    Text(arg)
                                        .font(.system(.caption, design: .monospaced))
                                        .padding(4)
                                        .background(Color.black.opacity(0.05))
                                        .cornerRadius(4)
                                }
                            }
                        }
                        
                        // Env Vars
                        if !config.env.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ENVIRONMENT VARIABLES", tableName: "DevAssistant")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                
                                ForEach(Array(config.env.keys.sorted()), id: \.self) { key in
                                    HStack {
                                        Text(key)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundColor(.primary)
                                        Text("=")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("******") // Hide value for security
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        
                        // Tools (if connected)
                        if mcpService.connectedClients[config.name] != nil {
                             // We might need to expose tools per client in MCPService to show them here.
                             // For now, we can just show a placeholder or count if available.
                             // Since we don't store tools per client easily accessible here without refactor, 
                             // we'll skip the detailed tool list for now or add it later.
                             Text("Tools available when connected.", tableName: "DevAssistant")
                                 .font(.caption)
                                 .foregroundColor(.secondary)
                        }
                    }
                    .padding(.leading, 24)
                    .padding(.bottom, 8)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct MarketplaceView: View {
    let items = MCPMarketplace.shared.items
    @ObservedObject var mcpService = MCPService.shared
    @State private var selectedItem: MCPMarketplaceItem?
    
    // Find parent to present sheet
    // SwiftUI View hierarchy trickery might be needed or use binding from parent
    // For simplicity, we will use a binding passed down or PreferenceKey, 
    // but here we can just use the parent's state via @State in parent passed down?
    // Let's rely on finding the parent MCPSettingsView via environment object if we made it one, 
    // but since we are in same file, let's just make it simple.
    // Actually, we need to bubble up the selection.
    
    // Since we can't easily bubble up without bindings, let's restructure slightly.
    // We will assume this view is used inside MCPSettingsView which manages the sheet.
    
    var body: some View {
        // We need access to the parent's state to trigger sheet. 
        // A cleaner way is to use a Binding.
        EmptyView()
    }
}

// Re-implementing correctly
extension MCPSettingsView {
    struct MarketplaceView: View {
        let items = MCPMarketplace.shared.items
        @Binding var selectedItem: MCPMarketplaceItem?
        @ObservedObject var mcpService = MCPService.shared
        
        var body: some View {
            List(items) { item in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: item.iconName)
                        .font(.system(size: 24))
                        .foregroundColor(.accentColor)
                        .frame(width: 40, height: 40)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.name)
                                .fontWeight(.medium)
                            
                            if mcpService.configs.contains(where: { $0.name == item.name }) {
                                Text("Installed", tableName: "DevAssistant")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.1))
                                    .foregroundColor(.green)
                                    .cornerRadius(4)
                            }
                        }
                        
                        Text(LocalizedStringKey(item.description), tableName: "DevAssistant")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    if let documentationURL = item.documentationURL, let url = URL(string: documentationURL) {
                        Link(destination: url) {
                            Image(systemName: "globe")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .frame(width: 24, height: 24)
                                .background(Color.black.opacity(0.05))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 8)
                        .help(Text("Visit Homepage", tableName: "DevAssistant"))
                    }
                    
                    Button(action: {
                        selectedItem = item
                    }) {
                        Text(LocalizedStringKey(mcpService.configs.contains(where: { $0.name == item.name }) ? "Reinstall" : "Install"), tableName: "DevAssistant")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundColor(.accentColor)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 8)
            }
            .listStyle(.plain)
        }
    }
    
    struct InstallSheet: View {
        let item: MCPMarketplaceItem
        @Binding var envVarInputs: [String: String]
        var onInstall: () -> Void
        @Environment(\.dismiss) var dismiss
        @State private var visibleKeys: Set<String> = []
        
        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Image(systemName: item.iconName)
                        .font(.title2)
                    Text("Install \(item.name)" as LocalizedStringKey, tableName: "DevAssistant")
                        .font(.headline)
                }
                
                Text(LocalizedStringKey(item.description), tableName: "DevAssistant")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Divider()
                
                if !item.requiredEnvVars.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Configuration Required", tableName: "DevAssistant")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ForEach(item.requiredEnvVars, id: \.self) { (envKey: String) in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(envKey)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    if visibleKeys.contains(envKey) {
                                        TextField("", text: Binding(
                                            get: { envVarInputs[envKey] ?? "" },
                                            set: { envVarInputs[envKey] = $0 }
                                        ), prompt: Text("Enter value", tableName: "DevAssistant"))
                                        .textFieldStyle(.roundedBorder)
                                    } else {
                                        SecureField("", text: Binding(
                                            get: { envVarInputs[envKey] ?? "" },
                                            set: { envVarInputs[envKey] = $0 }
                                        ), prompt: Text("Enter value", tableName: "DevAssistant"))
                                        .textFieldStyle(.roundedBorder)
                                    }
                                    
                                    Button(action: {
                                        if visibleKeys.contains(envKey) {
                                            visibleKeys.remove(envKey)
                                        } else {
                                            visibleKeys.insert(envKey)
                                        }
                                    }) {
                                        Image(systemName: visibleKeys.contains(envKey) ? "eye.slash" : "eye")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                } else {
                    Text("No configuration required.", tableName: "DevAssistant")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Cancel", tableName: "DevAssistant")
                    }
                    .keyboardShortcut(.cancelAction)
                    
                    Spacer()
                    
                    Button(action: {
                        onInstall()
                        dismiss()
                    }) {
                        Text("Install Server", tableName: "DevAssistant")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!item.requiredEnvVars.allSatisfy { 
                        let value = envVarInputs[$0] ?? ""
                        return !value.isEmpty
                    })
                }
            }
            .padding(24)
            .frame(width: 400, height: item.requiredEnvVars.isEmpty ? 200 : 400)
            .onAppear {
                envVarInputs = [:]
            }
        }
    }
}

struct MCPStatusBadge: View {
    let isConnected: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(isConnected ? "Connected" : "Disconnected", tableName: "DevAssistant")
                .font(.caption)
                .foregroundColor(isConnected ? .green : .red)
        }
    }
}
