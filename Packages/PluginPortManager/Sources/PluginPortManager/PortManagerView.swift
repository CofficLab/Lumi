import LumiUI
import SwiftUI

public struct PortManagerView: View {
    @StateObject private var viewModel = PortManagerViewModel()
    @State private var searchText = ""

    public var filteredPorts: [PortInfo] {
        if searchText.isEmpty {
            return viewModel.ports
        } else {
            return viewModel.ports.filter {
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
                    placeholder: LocalizedStringKey(pluginLocalization.string("Search port, PID, or process name"))
                )

                Spacer()

                AppButton(
                    LocalizedStringKey(pluginLocalization.string("Refresh")),
                    systemImage: "arrow.clockwise",
                    style: .secondary,
                    size: .small
                ) {
                    Task { await viewModel.refresh() }
                }
                .disabled(viewModel.isLoading)
            }
            .padding()
            .background(Material.regularMaterial)

            GlassDivider()

            if viewModel.isLoading && viewModel.ports.isEmpty {
                AppLoadingOverlay(
                    message: LocalizedStringKey(pluginLocalization.string("Loading Ports")),
                    size: .medium
                )
            } else if viewModel.ports.isEmpty {
                AppEmptyState(
                    icon: "network.slash",
                    title: LocalizedStringKey(pluginLocalization.string("No Listening Ports")),
                    description: LocalizedStringKey(pluginLocalization.string("No listening ports found."))
                )
            } else {
                List {
                    ForEach(filteredPorts) { port in
                        PortRowView(port: port) {
                            Task {
                                await viewModel.killProcess(port)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .task {
            await viewModel.refresh()
        }
        .alert(Text(verbatim: pluginLocalization.string("Error")), isPresented: $viewModel.showError, actions: {
            Button(role: .cancel) {
            } label: {
                Text(pluginLocalization.string("OK"))
            }
        }, message: {
            Text(viewModel.errorMessage ?? pluginLocalization.string("Unknown error"))
        })
        .frame(maxWidth: .infinity)
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

                        Text(verbatim: pluginLocalization.string("•"))
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

                        Text("PID: \(port.pid)")
                            .font(.caption)
                            .monospacedDigit()
                            .padding(.horizontal, 4)
                            .background(Color(hex: "98989E").opacity(0.2))
                            .cornerRadius(4)

                        Text(verbatim: pluginLocalization.string("•"))
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
                .help(pluginLocalization.string("Kill Process"))
            }
            .confirmationDialog(
                Text("Are you sure you want to kill process \(port.command) (PID: \(port.pid))?"),
                isPresented: $showConfirm
            ) {
                Button(role: .destructive) {
                    onKill()
                } label: {
                    Text(verbatim: pluginLocalization.string("Kill Process"))
                }
                Button(role: .cancel) {
                } label: {
                    Text(pluginLocalization.string("Cancel"))
                }
            } message: {
                Text(verbatim: pluginLocalization.string("This action will force terminate the process, which may lead to data loss."))
            }
        }
        .padding(.vertical, 4)
        .navigationTitle(pluginLocalization.string("Port Manager"))
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
