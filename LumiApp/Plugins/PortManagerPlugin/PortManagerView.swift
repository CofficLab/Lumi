import LumiUI
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
            HStack {
                AppSearchBar(
                    text: $searchText,
                    placeholder: LocalizedStringKey(String(localized: "Search port, PID, or process name", table: "PortManager"))
                )

                Spacer()

                AppButton(
                    LocalizedStringKey(String(localized: "Refresh", table: "PortManager")),
                    systemImage: "arrow.clockwise",
                    style: .secondary,
                    size: .small
                ) {
                    Task { await refresh() }
                }
                .disabled(isLoading)
            }
            .padding()
            .background(Material.regularMaterial)

            GlassDivider()

            if isLoading && ports.isEmpty {
                AppLoadingOverlay(
                    message: LocalizedStringKey(String(localized: "Loading Ports", table: "PortManager")),
                    size: .medium
                )
            } else if ports.isEmpty {
                AppEmptyState(
                    icon: "network.slash",
                    title: LocalizedStringKey(String(localized: "No Listening Ports", table: "PortManager")),
                    description: LocalizedStringKey(String(localized: "No listening ports found.", table: "PortManager"))
                )
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
                Text(String(localized: "OK", table: "PortManager"))
            }
        }, message: {
            Text(errorMessage ?? String(localized: "Unknown error"))
        })
        .frame(maxWidth: .infinity)
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
        AppCard(
            style: .subtle,
            cornerRadius: 8,
            padding: EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12),
            showShadow: false
        ) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(port.port)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(Color(hex: "0A84FF"))
                            .frame(minWidth: 50, alignment: .leading)

                        Text(port.command)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                        Spacer()
                    }

                    HStack {
                        Image(systemName: "network")
                            .font(.caption)
                        Text(port.address)
                            .font(.caption)
                            .monospaced()

                        Text("•")
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

                        Text("PID: \(port.pid)")
                            .font(.caption)
                            .monospacedDigit()
                            .padding(.horizontal, 4)
                            .background(Color(hex: "98989E").opacity(0.2))
                            .cornerRadius(4)

                        Text("•")
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

                        Text(port.user)
                            .font(.caption)
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    }
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                }

                Spacer()

                AppIconButton(systemImage: "xmark.circle.fill", tint: Color(hex: "FF453A").opacity(0.8), size: .regular) {
                    showConfirm = true
                }
                .help(String(localized: "Kill Process", table: "PortManager"))
            }
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
                    Text(String(localized: "Cancel", table: "PortManager"))
                }
            } message: {
                Text("This action will force terminate the process, which may lead to data loss.")
            }
        }
        .padding(.vertical, 4)
        .navigationTitle(PortManagerPlugin.displayName)
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
