import SwiftUI
import LumiUI

struct HostsManagerView: View {
    @StateObject private var viewModel = HostsManagerViewModel()
    @State private var showAddSheet = false
    @State private var showImportExport = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                // Group Filter
                Picker("Group", selection: $viewModel.selectedGroup) {
                    Text(String(localized: "All", table: "HostsManager")).tag(String?.none)
                    ForEach(viewModel.groups, id: \.self) { group in
                        Text(group).tag(String?.some(group))
                    }
                }
                .frame(width: 150)
                
                Spacer()
                
                // Search
                GlassTextField(
                    title: "搜索",
                    text: $viewModel.searchText,
                    placeholder: "Search Host"
                )
                .frame(width: 200)
                
                // Actions
                GlassButton(title: "Add", style: .primary) {
                    showAddSheet = true
                }
                .frame(width: 100)
                
                Menu {
                    Button(String(localized: "Refresh", table: "HostsManager")) {
                        Task { await viewModel.loadHosts() }
                    }
                    GlassDivider()
                    Button(String(localized: "Export Backup...", table: "HostsManager")) {
                        exportHosts()
                    }
                    Button(String(localized: "Import Backup...", table: "HostsManager")) {
                        importHosts()
                    }
                } label: {
                    GlassRow {
                        Label("More", systemImage: "ellipsis.circle")
                            .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                    }
                    .frame(width: 110)
                }
            }
            .padding()
            .background(Material.regularMaterial)
            
            GlassDivider()
            
            // List
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage {
                ContentUnavailableView {
                    Label("An error occurred", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    GlassButton(title: "Retry", style: .secondary) {
                        Task { await viewModel.loadHosts() }
                    }
                }
            } else {
                List {
                    ForEach(viewModel.filteredEntries) { entry in
                        HostRowView(entry: entry, viewModel: viewModel)
                    }
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            HostAddView(viewModel: viewModel, isPresented: $showAddSheet)
        }
        .task {
            await viewModel.loadHosts()
        }
    }
    
    func exportHosts() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.data]
        panel.nameFieldStringValue = "hosts_backup_\(Date().timeIntervalSince1970)"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try HostsFileService.shared.backupHosts(to: url)
                } catch {
                    // Handle error (show alert)
                    if HostsManagerPlugin.verbose {
                                            HostsManagerPlugin.logger.error("Export failed: \(error)")
                    }
                }
            }
        }
    }
    
    func importHosts() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.data, .text]
        panel.allowsMultipleSelection = false
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task {
                    do {
                        try await HostsFileService.shared.importHosts(from: url)
                        await viewModel.loadHosts()
                    } catch {
                        // Handle error
                        if HostsManagerPlugin.verbose {
                                                    HostsManagerPlugin.logger.error("Import failed: \(error)")
                        }
                    }
                }
            }
        }
    }
}

struct HostRowView: View {
    let entry: HostEntry
    @ObservedObject var viewModel: HostsManagerViewModel
    
    var body: some View {
        HStack {
            switch entry.type {
            case .groupHeader(let name):
                Text(name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    .padding(.top, 8)
            case .comment(let text):
                Text(text)
                    .font(.monospaced(.caption)())
                    .foregroundColor(Color(hex: "98989E"))
            case .entry(let ip, let domains, let isEnabled, let comment):
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { _ in viewModel.toggleEntry(entry) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                
                VStack(alignment: .leading) {
                    HStack {
                        Text(domains.joined(separator: ", "))
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(isEnabled ? Color.adaptive(light: "1C1C1E", dark: "FFFFFF") : Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                        
                        if let comment = comment {
                            Text("# \(comment)")
                                .foregroundColor(Color(hex: "98989E"))
                        }
                    }
                    Text(ip)
                        .font(.monospaced(.caption)())
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                }
                
                Spacer()
                
                Button(role: .destructive, action: {
                    viewModel.deleteEntry(entry)
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(Color(hex: "FF453A").opacity(0.6))
                }
                .buttonStyle(.plain)
            case .empty:
                EmptyView()
            }
        }
        .padding(.vertical, 4)
    }
}

struct HostAddView: View {
    @ObservedObject var viewModel: HostsManagerViewModel
    @Binding var isPresented: Bool
    
    @State private var ip = "127.0.0.1"
    @State private var domain = ""
    @State private var comment = ""
    @State private var group = ""
    @State private var showIPError = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text(String(localized: "Add Host Entry", table: "HostsManager"))
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
            
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    GlassTextField(title: "IP Address", text: $ip, placeholder: "127.0.0.1")
                    if showIPError {
                        Text("Invalid IP address format")
                            .foregroundColor(Color(hex: "FF453A"))
                            .font(.system(size: 12, weight: .regular))
                    }

                    GlassTextField(title: "Domain", text: $domain, placeholder: "dev.example.com")
                    GlassTextField(title: "Comment", text: $comment, placeholder: "Optional")
                    GlassTextField(title: "Group", text: $group, placeholder: "Optional")
                }
            }
            
            HStack {
                GlassButton(title: "Cancel", style: .ghost) {
                    isPresented = false
                }
                
                GlassButton(title: "Save", style: .primary) {
                    if viewModel.isValidIP(ip) && !domain.isEmpty {
                        viewModel.addEntry(ip: ip, domain: domain, comment: comment.isEmpty ? nil : comment, group: group.isEmpty ? nil : group)
                        isPresented = false
                    } else {
                        showIPError = !viewModel.isValidIP(ip)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(domain.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 350)
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
