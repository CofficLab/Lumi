import SwiftUI
import AppKit

struct TextActionsSettingsView: View {
    @StateObject private var manager = TextSelectionManager.shared
    @AppStorage("TextActionsEnabled") private var isEnabled = false
    
    var body: some View {
        Form {
            Section("General Settings") {
                Toggle("Enable Text Selection Menu", isOn: $isEnabled)
                    .onChange(of: isEnabled) { newValue in
                        if newValue {
                            manager.startMonitoring()
                            // Ensure window controller is initialized
                            _ = TextActionMenuController.shared
                        } else {
                            manager.stopMonitoring()
                        }
                    }
                
                if !manager.isPermissionGranted {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text("Accessibility permission is required to detect text selection")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Open System Settings") {
                            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            
            Section("Supported Actions") {
                ForEach(TextActionType.allCases) { action in
                    HStack {
                        Image(systemName: action.icon)
                        Text(action.title)
                        Spacer()
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding()
        .onAppear {
            manager.checkPermission()
            if isEnabled {
                manager.startMonitoring()
                _ = TextActionMenuController.shared
            }
        }
    }
}
