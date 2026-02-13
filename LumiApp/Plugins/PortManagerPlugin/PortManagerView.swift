import SwiftUI

struct PortManagerView: View {
    @State private var ports: [PortInfo] = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false

    var filteredPorts: [PortInfo] {
        if searchText.isEmpty {
            return ports
        } else {
            return ports.filter {
                $0.port.contains(searchText) ||
                    $0.command.localizedCaseInsensitiveContains(searchText) ||
                    $0.pid.contains(searchText)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar / Header
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                GlassTextField(
                    title: LocalizedStringKey(String(localized: "Search port, PID, or process name", table: "PortManager")),
                    text: $searchText
                )

                Spacer()

                GlassButton(title: LocalizedStringKey(String(localized: "Refresh", table: "PortManager")), style: .secondary) {
                    Task { await refresh() }
                }
                .disabled(isLoading)
            }
            .padding()
            .background(DesignTokens.Material.glass)

            GlassDivider()

            // Content
            if isLoading && ports.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if ports.isEmpty {
                if #available(macOS 14.0, *) {
                    ContentUnavailableView(
                        LocalizedStringKey(String(localized: "No Listening Ports")),
                        systemImage: "network.slash",
                        description: Text("No listening ports found.")
                    )
                } else {
                    VStack {
                        Image(systemName: "network.slash")
                            .font(.largeTitle)
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        Text("No Listening Ports")
                            .font(.headline)
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                List {
                    ForEach(filteredPorts) { port in
                        PortRowView(port: port) {
                            Task {
                                await killProcess(port)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .task {
            await refresh()
        }
        .alert(Text("Error"), isPresented: $showError, actions: {
            Button(role: .cancel) {
            } label: {
                Text("OK")
            }
        }, message: {
            Text(errorMessage ?? String(localized: "Unknown error"))
        })
    }

    func refresh() async {
        isLoading = true
        ports = await PortScanner.shared.scanPorts()
        isLoading = false
    }

    func killProcess(_ port: PortInfo) async {
        do {
            try await PortScanner.shared.killProcess(pid: port.pid)
            // Refresh after killing
            try? await Task.sleep(nanoseconds: 500000000) // Wait 0.5s
            await refresh()
        } catch {
            errorMessage = String(localized: "Failed to kill process: \(error.localizedDescription)")
            showError = true
        }
    }
}

struct PortRowView: View {
    let port: PortInfo
    let onKill: () -> Void
    @State private var showConfirm = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(port.port)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(DesignTokens.Color.semantic.info)
                        .frame(minWidth: 50, alignment: .leading)

                    Text(port.command)
                        .font(.headline)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                    Spacer()
                }

                HStack {
                    Image(systemName: "network")
                        .font(.caption)
                    Text(port.address)
                        .font(.caption)
                        .monospaced()

                    Text("•")
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                    Text("PID: \(port.pid)")
                        .font(.caption)
                        .monospacedDigit()
                        .padding(.horizontal, 4)
                        .background(DesignTokens.Color.semantic.textTertiary.opacity(0.2))
                        .cornerRadius(4)

                    Text("•")
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                    Text(port.user)
                        .font(.caption)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }

            Spacer()

            Button(role: .destructive, action: {
                showConfirm = true
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(DesignTokens.Color.semantic.error.opacity(0.8))
                    .font(.title2)
            }
            .buttonStyle(.borderless)
            .help(Text("Kill Process"))
            .confirmationDialog(
                Text("Are you sure you want to kill process \(port.command) (PID: \(port.pid))?"),
                isPresented: $showConfirm
            ) {
                Button(role: .destructive) {
                    onKill()
                } label: {
                    Text("Kill Process")
                }
                Button(role: .cancel) {
                } label: {
                    Text("Cancel")
                }
            } message: {
                Text("This action will force terminate the process, which may lead to data loss.")
            }
        }
        .padding(.vertical, 8)
        .navigationTitle(PortManagerPlugin.displayName)
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .withNavigation(PortManagerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
