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
                    .foregroundStyle(.secondary)
                TextField("Search port, PID, or process name", text: $searchText)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)

                Spacer()

                Button(action: {
                    Task { await refresh() }
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Content
            if isLoading && ports.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if ports.isEmpty {
                if #available(macOS 14.0, *) {
                    ContentUnavailableView("No Listening Ports", systemImage: "network.slash", description: Text("No listening ports found."))
                } else {
                    VStack {
                        Image(systemName: "network.slash")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No Listening Ports")
                            .font(.headline)
                            .foregroundStyle(.secondary)
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
        .alert("Error", isPresented: $showError, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(errorMessage ?? "Unknown error")
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
            errorMessage = "Failed to kill process: \(error.localizedDescription)"
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
                        .foregroundStyle(.blue)
                        .frame(minWidth: 50, alignment: .leading)

                    Text(port.command)
                        .font(.headline)

                    Spacer()
                }

                HStack {
                    Image(systemName: "network")
                        .font(.caption)
                    Text(port.address)
                        .font(.caption)
                        .monospaced()

                    Text("•")
                        .foregroundStyle(.secondary)

                    Text("PID: \(port.pid)")
                        .font(.caption)
                        .monospacedDigit()
                        .padding(.horizontal, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)

                    Text("•")
                        .foregroundStyle(.secondary)

                    Text(port.user)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive, action: {
                showConfirm = true
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red.opacity(0.8))
                    .font(.title2)
            }
            .buttonStyle(.borderless)
            .help("Kill Process")
            .confirmationDialog("Are you sure you want to kill process \(port.command) (PID: \(port.pid))?", isPresented: $showConfirm) {
                Button("Kill Process", role: .destructive) {
                    onKill()
                }
                Button("Cancel", role: .cancel) {}
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
