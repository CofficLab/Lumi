import SwiftUI
import MagicKit

struct RegistryManagerView: View {
    @StateObject private var viewModel = RegistryManagerViewModel()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Registry Manager")
                    .font(.largeTitle)
                    .bold()
                    .padding(.horizontal)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320))], spacing: 16) {
                    ForEach(RegistryType.allCases) { type in
                        RegistryCard(type: type, viewModel: viewModel)
                    }
                }
                .padding()
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.showToast {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(viewModel.toastMessage)
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(12)
                .shadow(radius: 5)
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring, value: viewModel.showToast)
    }
}

struct RegistryCard: View {
    let type: RegistryType
    @ObservedObject var viewModel: RegistryManagerViewModel
    
    var currentUrl: String {
        viewModel.registries[type] ?? "Checking..."
    }
    
    var isLoading: Bool {
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
                        .font(.headline)
                    
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
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Registry")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(currentUrl)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(4)
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
                                // Simple check if current URL matches preset URL
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
