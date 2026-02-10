import SwiftUI

struct ProcessNetworkListView: View {
    @ObservedObject var viewModel: NetworkManagerViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Process Monitor")
                    .font(.headline)

                Spacer()

                Toggle("Active Only", isOn: $viewModel.onlyActiveProcesses)
                    .toggleStyle(.switch)
                    .controlSize(.small)

                TextField("Search...", text: $viewModel.processSearchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))

            // Table Header
            GeometryReader { geometry in
                let horizontalPadding: CGFloat = 8
                let scrollBarWidth: CGFloat = 16
                // Calculate available width: Total - Left/Right Padding - Scrollbar
                let availableWidth = max(0, geometry.size.width - (horizontalPadding * 2) - scrollBarWidth)
                
                HStack(spacing: 0) {
                    Text("App")
                        .frame(width: availableWidth * 0.50, alignment: .leading)

                    Spacer()

                    Text("Down")
                        .frame(width: availableWidth * 0.2, alignment: .trailing)

                    Text("Up")
                        .frame(width: availableWidth * 0.2, alignment: .trailing)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, horizontalPadding)
                .padding(.trailing, scrollBarWidth) // Extra padding to align with list (avoid scrollbar)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            }
            .frame(height: 28)

            Divider()

            // List
            if viewModel.filteredProcesses.isEmpty {
                VStack {
                    Spacer()
                    Text("No active processes")
                        .foregroundColor(.secondary)
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
