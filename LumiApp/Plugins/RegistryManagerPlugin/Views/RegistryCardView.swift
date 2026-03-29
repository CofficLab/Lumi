import SwiftUI
import MagicKit

struct RegistryCard: View {
    let type: RegistryType
    @ObservedObject var viewModel: RegistryManagerViewModel

    private var currentUrl: String {
        viewModel.registries[type] ?? "Checking..."
    }

    private var isLoading: Bool {
        viewModel.isLoading[type] ?? false
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: type.icon)
                        .font(.title2)
                        .foregroundStyle(.primary)
                        .frame(width: 32, height: 32)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Circle())

                    Text(type.name)
                        .font(AppUI.Typography.bodyEmphasized)

                    Spacer()

                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button {
                            Task { await viewModel.refresh(type) }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Refresh")
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Current Registry")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(currentUrl)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                        )
                        .help(currentUrl)
                        .onTapGesture {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(currentUrl, forType: .string)
                            viewModel.showToast(message: "Copied to clipboard")
                        }
                }

                Menu {
                    ForEach(viewModel.presets[type] ?? []) { source in
                        Button {
                            Task {
                                await viewModel.setRegistry(type, source: source)
                            }
                        } label: {
                            HStack {
                                Text(source.name)
                                if currentUrl.trimmingCharacters(in: .whitespacesAndNewlines) == source.url.trimmingCharacters(in: .whitespacesAndNewlines) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Switch Source")
                    }
                    .frame(maxWidth: .infinity)
                }
                .menuStyle(.borderedButton)
            }
            .padding()
        }
    }
}

