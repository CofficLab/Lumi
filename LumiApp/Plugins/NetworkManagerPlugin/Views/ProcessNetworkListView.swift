import SwiftUI

struct ProcessNetworkListView: View {
    @ObservedObject var viewModel: NetworkManagerViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text(String(localized: "Process Monitor"))
                    .font(.headline)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

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
            .background(DesignTokens.Material.glass)

            // Table Header
            GeometryReader { geometry in
                let horizontalPadding: CGFloat = 8
                let scrollBarWidth: CGFloat = 16
                // Calculate available width: Total - Left/Right Padding - Scrollbar
                let availableWidth = max(0, geometry.size.width - (horizontalPadding * 2) - scrollBarWidth)
                
                HStack(spacing: 0) {
                    Text(String(localized: "App"))
                        .frame(width: availableWidth * 0.50, alignment: .leading)

                    Spacer()

                    Text(String(localized: "Down"))
                        .frame(width: availableWidth * 0.2, alignment: .trailing)

                    Text(String(localized: "Up"))
                        .frame(width: availableWidth * 0.2, alignment: .trailing)
                }
                .font(.caption)
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                .padding(.horizontal, horizontalPadding)
                .padding(.trailing, scrollBarWidth) // Extra padding to align with list (avoid scrollbar)
                .padding(.vertical, 6)
                .background(DesignTokens.Material.glass.opacity(0.5))
            }
            .frame(height: 28)

            GlassDivider()

            // List
            if viewModel.filteredProcesses.isEmpty {
                VStack {
                    Spacer()
                    Text(String(localized: "No active processes"))
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
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
    NetworkStatusBarPopupView()
        .frame(width: 300)
        .frame(height: 400)
}
