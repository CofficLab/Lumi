import SwiftUI
import LumiUI

public struct RegistryCard: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public let type: RegistryType
    @ObservedObject var viewModel: RegistryManagerViewModel

    private var currentUrl: String {
        viewModel.registries[type] ?? "Checking..."
    }

    private var isLoading: Bool {
        viewModel.isLoading[type] ?? false
    }

    public var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: type.icon)
                        .font(.appTitle)
                        .foregroundStyle(theme.textPrimary)
                        .frame(width: 32, height: 32)
                        .background(theme.appAccentSoftFill)
                        .clipShape(Circle())

                    Text(type.name)
                        .font(.appBodyEmphasized)
                        .foregroundColor(theme.textPrimary)

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
                        .foregroundColor(theme.textSecondary)
                        .help(LumiPluginLocalization.string("Refresh", bundle: .module))
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: LumiPluginLocalization.string("Current Registry", bundle: .module))
                        .font(.appCaption)
                        .foregroundStyle(theme.textSecondary)

                    Text(currentUrl)
                        .font(.appMonoCaption)
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .appSurface(style: .listRow, cornerRadius: 6, borderColor: theme.appSubtleBorder.opacity(0.7))
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
                        Text(verbatim: LumiPluginLocalization.string("Switch Source", bundle: .module))
                    }
                    .frame(maxWidth: .infinity)
                }
                .menuStyle(.borderedButton)
            }
            .padding()
        }
    }
}
