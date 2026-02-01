import SwiftUI

struct InputSettingsView: View {
    @StateObject private var viewModel = InputSettingsViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Toggle("启用输入法自动切换", isOn: Binding(
                get: { viewModel.isEnabled },
                set: { _ in viewModel.toggleEnabled() }
            ))
            .toggleStyle(.switch)
            
            Divider()
            
            HStack {
                Text("新增规则")
                    .font(.headline)
                Spacer()
            }
            
            HStack {
                Picker("应用", selection: $viewModel.selectedApp) {
                    Text("选择应用").tag(nil as NSRunningApplication?)
                    ForEach(viewModel.runningApps, id: \.bundleIdentifier) { app in
                        Text(app.localizedName ?? "Unknown").tag(app as NSRunningApplication?)
                    }
                }
                .frame(width: 200)
                
                Picker("输入法", selection: $viewModel.selectedSourceID) {
                    Text("选择输入法").tag("")
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
