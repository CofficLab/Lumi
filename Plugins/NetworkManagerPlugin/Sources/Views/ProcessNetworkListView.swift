import LumiUI
import SwiftUI
import LumiKernel

public struct ProcessNetworkListView: View {
    @ObservedObject var viewModel: NetworkManagerViewModel

    public var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text(LumiPluginLocalization.string("Process Monitor", bundle: .module))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                Spacer()

                Toggle("Active Only", isOn: $viewModel.onlyActiveProcesses)
                    .toggleStyle(.switch)
                    .controlSize(.small)

                GlassTextField(
                    title: "搜索",
                    text: $viewModel.processSearchText,
                    placeholder: "Search..."
                )
                .frame(width: 160)
            }
            .padding(10)
            .background(Material.regularMaterial)

            // Table Header
            GeometryReader { geometry in
                let horizontalPadding: CGFloat = 8
                let scrollBarWidth: CGFloat = 16
                // Calculate available width: Total - Left/Right Padding - Scrollbar
                let availableWidth = max(0, geometry.size.width - (horizontalPadding * 2) - scrollBarWidth)
                
                HStack(spacing: 0) {
                    Text(LumiPluginLocalization.string("App", bundle: .module))
                        .frame(width: availableWidth * 0.50, alignment: .leading)

                    Spacer()

                    Text(LumiPluginLocalization.string("Down", bundle: .module))
                        .frame(width: availableWidth * 0.2, alignment: .trailing)

                    Text(LumiPluginLocalization.string("Up", bundle: .module))
                        .frame(width: availableWidth * 0.2, alignment: .trailing)
                }
                .font(.caption)
                .foregroundColor(Color(hex: "98989E"))
                .padding(.horizontal, horizontalPadding)
                .padding(.trailing, scrollBarWidth) // Extra padding to align with list (avoid scrollbar)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08))
            }
            .frame(height: 28)

            GlassDivider()

            // List
            if viewModel.filteredProcesses.isEmpty {
                VStack {
                    Spacer()
                    Text(LumiPluginLocalization.string("No active processes", bundle: .module))
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    Spacer()
                }
                .frame(maxHeight: .infinity)
            } else {
                GeometryReader { geometry in
                    List {
                        ForEach(viewModel.filteredProcesses) { process in
                            ProcessRow(process: process, containerWidth: geometry.size.width)
                                .listRowInsets(EdgeInsets()) // Remove default system insets
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                viewModel.showProcessMonitor = true
            }
        }
        .onDisappear {
            DispatchQueue.main.async {
                viewModel.showProcessMonitor = false
            }
        }
        .infiniteWidth()
    }
}



// MARK: - Preview

#Preview("Network Status Bar Popup") {
    NetworkMenuBarPopupView()
        .frame(width: 300)
        .frame(height: 400)
}
