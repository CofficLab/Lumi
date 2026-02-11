import SwiftUI

struct InputSettingsView: View {
    @StateObject private var viewModel = InputSettingsViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Toggle("Enable Auto Input Source Switching", isOn: Binding(
                get: { viewModel.isEnabled },
                set: { _ in viewModel.toggleEnabled() }
            ))
            .toggleStyle(.switch)
            
            Divider()
            
            HStack {
                Text("Add New Rule")
                    .font(.headline)
                Spacer()
            }
            
            HStack {
                Picker("Application", selection: $viewModel.selectedApp) {
                    Text("Select Application").tag(nil as NSRunningApplication?)
                    ForEach(viewModel.runningApps, id: \.bundleIdentifier) { app in
                        Text(app.localizedName ?? "Unknown").tag(app as NSRunningApplication?)
                    }
                }
                .frame(width: 200)
                
                Picker("Input Source", selection: $viewModel.selectedSourceID) {
                    Text("Select Input Source").tag("")
                    ForEach(viewModel.availableSources) { source in
                        Text(source.name).tag(source.id)
                    }
                }
                .frame(width: 200)
                
                Button(action: viewModel.addRule) {
                    Image(systemName: "plus")
                }
                .disabled(viewModel.selectedApp == nil || viewModel.selectedSourceID.isEmpty)
            }
            
            Divider()
            
            List {
                ForEach(viewModel.rules) { rule in
                    HStack {
                        Text(rule.appName)
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)
                        Spacer()
                        if let source = viewModel.availableSources.first(where: { $0.id == rule.inputSourceID }) {
                            Text(source.name)
                                .foregroundColor(.secondary)
                        } else {
                            Text(rule.inputSourceID)
                                .foregroundColor(.red)
                        }
                    }
                }
                .onDelete(perform: viewModel.removeRule)
            }
        }
        .padding()
        .onAppear {
            viewModel.refreshRunningApps()
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .withDebugBar()
}
