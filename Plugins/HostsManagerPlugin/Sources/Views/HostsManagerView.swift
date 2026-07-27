import SwiftUI
import SuperLogKit
import LumiUI
import LumiKernel

public struct HostsManagerView: View, SuperLog {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @StateObject private var viewModel = HostsManagerViewModel()
    @State private var showAddSheet = false
    @State private var showImportExport = false

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Group", selection: $viewModel.selectedGroup) {
                    Text(LumiPluginLocalization.string("All", bundle: .module)).tag(String?.none)
                    ForEach(viewModel.groups, id: \.self) { group in
                        Text(group).tag(String?.some(group))
                    }
                }
                .frame(width: 150)

                Spacer()

                AppSearchBar(
                    text: $viewModel.searchText,
                    placeholder: LocalizedStringKey(LumiPluginLocalization.string("Search Host", bundle: .module))
                )
                .frame(width: 220)

                AppButton(
                    LumiPluginLocalization.string("Add", bundle: .module),
                    systemImage: "plus",
                    style: .primary,
                    size: .small
                ) {
                    showAddSheet = true
                }

                Menu {
                    Button(LumiPluginLocalization.string("Refresh", bundle: .module)) {
                        Task { await viewModel.loadHosts() }
                    }
                    Divider()
                    Button(LumiPluginLocalization.string("Export Backup...", bundle: .module)) {
                        exportHosts()
                    }
                    Button(LumiPluginLocalization.string("Import Backup...", bundle: .module)) {
                        importHosts()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "ellipsis.circle")
                        Text(LumiPluginLocalization.string("More", bundle: .module))
                    }
                    .font(.appCaptionEmphasized)
                    .foregroundColor(theme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity)
                    .appSurface(style: .listRow, cornerRadius: 8)
                    .frame(width: 110)
                }
            }
            .padding()
            .background(Material.regularMaterial)

            settingsDivider

            if viewModel.isLoading {
                AppLoadingOverlay(
                    message: LocalizedStringKey(LumiPluginLocalization.string("Loading Hosts", bundle: .module)),
                    size: .medium
                )
            } else if let error = viewModel.errorMessage {
                VStack {
                    AppErrorBanner(
                        message: LocalizedStringKey(error),
                        retryTitle: LocalizedStringKey(LumiPluginLocalization.string("Retry", bundle: .module))
                    ) {
                        Task { await viewModel.loadHosts() }
                    }
                    .frame(maxWidth: 420)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private var settingsDivider: some View {
        Rectangle()
            .fill(theme.appDivider)
            .frame(height: 1)
    }

    public func exportHosts() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.data]
        panel.nameFieldStringValue = "hosts_backup_\(Date().timeIntervalSince1970)"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try HostsFileService.shared.backupHosts(to: url)
                    viewModel.errorMessage = nil
                } catch {
                    if HostsManagerPlugin.verbose {
                        HostsManagerPlugin.logger.error("\(Self.t)Export failed: \(error)")
                    }
                    viewModel.errorMessage = String(
                        format: LumiPluginLocalization.string("Export failed: %@", bundle: .module),
                        error.localizedDescription
                    )
                }
            }
        }
    }

    public func importHosts() {
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
                        if HostsManagerPlugin.verbose {
                            HostsManagerPlugin.logger.error("\(Self.t)Import failed: \(error)")
                        }
                        await MainActor.run {
                            viewModel.errorMessage = String(
                                format: LumiPluginLocalization.string("Import failed: %@", bundle: .module),
                                error.localizedDescription
                            )
                        }
                    }
                }
            }
        }
    }
}

public struct HostRowView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public let entry: HostEntry
    @ObservedObject var viewModel: HostsManagerViewModel

    public var body: some View {
        switch entry.type {
        case .groupHeader(let name):
            AppListRow {
                Text(name)
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textSecondary)
            }
        case .comment(let text):
            AppListRow {
                Text(text)
                    .font(.monospaced(.caption)())
                    .foregroundColor(theme.textTertiary)
            }
        case .entry(let ip, let domains, let isEnabled, let comment):
            AppCard(
                style: .subtle,
                cornerRadius: 8,
                padding: EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12),
                showShadow: false
            ) {
                HStack {
                    entryToggle(isEnabled: isEnabled)

                    entryText(ip: ip, domains: domains, isEnabled: isEnabled, comment: comment)

                    Spacer()

                    AppIconButton(systemImage: "trash", tint: theme.error.opacity(0.7)) {
                        viewModel.deleteEntry(entry)
                    }
                }
            }
        case .empty:
            EmptyView()
        }
    }

    private func entryToggle(isEnabled: Bool) -> some View {
        Toggle("", isOn: Binding(
            get: { isEnabled },
            set: { _ in viewModel.toggleEntry(entry) }
        ))
        .toggleStyle(.switch)
        .controlSize(.small)
    }

    private func entryText(ip: String, domains: [String], isEnabled: Bool, comment: String?) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(domains.joined(separator: ", "))
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(
                        isEnabled
                        ? theme.textPrimary
                        : theme.textSecondary
                    )

                if let comment = comment {
                    Text("# \(comment)")
                        .foregroundColor(theme.textTertiary)
                }
            }
            Text(ip)
                .font(.monospaced(.caption)())
                .foregroundColor(theme.textSecondary)
        }
    }
}

public struct HostAddView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @ObservedObject var viewModel: HostsManagerViewModel
    @Binding var isPresented: Bool

    @State private var ip = "127.0.0.1"
    @State private var domain = ""
    @State private var comment = ""
    @State private var group = ""
    @State private var showIPError = false
    @State private var showDomainError = false

    public var body: some View {
        VStack(spacing: 20) {
            Text(LumiPluginLocalization.string("Add Host Entry", bundle: .module))
                .font(.appTitle)
                .foregroundColor(theme.textPrimary)

            AppCard {
                VStack(alignment: .leading, spacing: 8) {
                    GlassTextField(title: "IP Address", text: $ip, placeholder: "127.0.0.1")
                    if showIPError {
                        AppErrorBanner(message: LocalizedStringKey(LumiPluginLocalization.string("Invalid IP address format", bundle: .module)))
                    }

                    GlassTextField(title: "Domain", text: $domain, placeholder: "dev.example.com")
                    if showDomainError {
                        AppErrorBanner(message: LocalizedStringKey(LumiPluginLocalization.string("Invalid domain format", bundle: .module)))
                    }
                    GlassTextField(title: "Comment", text: $comment, placeholder: "Optional")
                    GlassTextField(title: "Group", text: $group, placeholder: "Optional")
                }
            }

            HStack {
                AppButton(LumiPluginLocalization.string("Cancel", bundle: .module), style: .ghost) {
                    isPresented = false
                }

                AppButton(LumiPluginLocalization.string("Save", bundle: .module), style: .primary) {
                    let trimmedIP = ip.trimmingCharacters(in: .whitespacesAndNewlines)
                    let hasDomain = !domain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    let hasValidDomains = viewModel.isValidDomainList(domain)
                    if viewModel.isValidIP(trimmedIP) && hasDomain && hasValidDomains {
                        viewModel.addEntry(ip: ip, domain: domain, comment: comment.isEmpty ? nil : comment, group: group.isEmpty ? nil : group)
                        isPresented = false
                    } else {
                        showIPError = !viewModel.isValidIP(trimmedIP)
                        showDomainError = hasDomain && !hasValidDomains
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(domain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
