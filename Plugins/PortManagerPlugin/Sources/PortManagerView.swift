import LumiUI
import SwiftUI

public struct PortManagerView: View {
    @State private var ports: [PortInfo] = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false

    public var filteredPorts: [PortInfo] {
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

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                AppSearchBar(
                    text: $searchText,
                    placeholder: LocalizedStringKey(LumiPluginLocalization.string("Search port, PID, or process name", bundle: .module))
                )

                Spacer()

                AppButton(
                    LocalizedStringKey(LumiPluginLocalization.string("Refresh", bundle: .module)),
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
                    message: LocalizedStringKey(LumiPluginLocalization.string("Loading Ports", bundle: .module)),
                    size: .medium
                )
            } else if ports.isEmpty {
                AppEmptyState(
                    icon: "network.slash",
                    title: LocalizedStringKey(LumiPluginLocalization.string("No Listening Ports", bundle: .module)),
                    description: LocalizedStringKey(LumiPluginLocalization.string("No listening ports found.", bundle: .module))
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
        .alert(Text(verbatim: LumiPluginLocalization.string("Error", bundle: .module)), isPresented: $showError, actions: {
            Button(role: .cancel) {
            } label: {
                Text(LumiPluginLocalization.string("OK", bundle: .module))
            }
        }, message: {
            Text(errorMessage ?? LumiPluginLocalization.string("Unknown error", bundle: .module))
        })
        .frame(maxWidth: .infinity)
    }

    public func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            ports = try await PortScanner.shared.scanPorts()
            showError = false
        } catch {
            ports = []
            errorMessage = String(
                format: LumiPluginLocalization.string("Failed to scan ports: %@", bundle: .module),
                error.localizedDescription
            )
            showError = true
        }
    }

    public func killProcess(_ port: PortInfo) async {
        do {
            try await PortScanner.shared.killProcess(pid: port.pid)
            // Refresh after killing
            try? await Task.sleep(nanoseconds: 500000000) // Wait 0.5s
            await refresh()
        } catch {
            errorMessage = LumiPluginLocalization.string("Failed to kill process: \(error.localizedDescription)", bundle: .module)
            showError = true
        }
    }
}

public struct PortRowView: View {
    public let port: PortInfo
    public let onKill: () -> Void
    @State private var showConfirm = false

    public var body: some View {
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

                        Text(verbatim: LumiPluginLocalization.string("•", bundle: .module))
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

                        Text("PID: \(port.pid)")
                            .font(.caption)
                            .monospacedDigit()
                            .padding(.horizontal, 4)
                            .background(Color(hex: "98989E").opacity(0.2))
                            .cornerRadius(4)

                        Text(verbatim: LumiPluginLocalization.string("•", bundle: .module))
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
                .help(LumiPluginLocalization.string("Kill Process", bundle: .module))
            }
            .confirmationDialog(
                Text("Are you sure you want to kill process \(port.command) (PID: \(port.pid))?"),
                isPresented: $showConfirm
            ) {
                Button(role: .destructive) {
                    onKill()
                } label: {
                    Text(verbatim: LumiPluginLocalization.string("Kill Process", bundle: .module))
                }
                Button(role: .cancel) {
                } label: {
                    Text(LumiPluginLocalization.string("Cancel", bundle: .module))
                }
            } message: {
                Text(verbatim: LumiPluginLocalization.string("This action will force terminate the process, which may lead to data loss.", bundle: .module))
            }
        }
        .padding(.vertical, 4)
        .navigationTitle("Port Manager")
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
