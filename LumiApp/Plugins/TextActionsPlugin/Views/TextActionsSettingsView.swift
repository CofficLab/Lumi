import SwiftUI
import AppKit

struct TextActionsSettingsView: View {
    @StateObject private var manager = TextSelectionManager.shared
    @AppStorage("TextActionsEnabled") private var isEnabled = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Preview Section
            TextActionPreviewView(isEnabled: isEnabled)
            
            Divider()
            
            // Settings Form
            Form {
                Section("General Settings") {
                    Toggle("Enable Text Selection Menu", isOn: $isEnabled)
                        .onChange(of: isEnabled) { _, newValue in
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
                                .frame(width: 20)
                            Text(action.title)
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .padding()
        }
        .onAppear {
            manager.checkPermission()
            if isEnabled {
                manager.startMonitoring()
                _ = TextActionMenuController.shared
            }
        }
    }
}

struct TextActionPreviewView: View {
    let isEnabled: Bool
    
    var body: some View {
        ZStack {
            Color(nsColor: .controlBackgroundColor)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Preview")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                ZStack {
                    // Document background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .textBackgroundColor))
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        .frame(width: 220, height: 160)
                    
                    // Mock content
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 180, height: 8)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 160, height: 8)
                        
                        HStack(spacing: 0) {
                            Text("Select ")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            
                            Text("this text")
                                .font(.system(size: 12))
                                .padding(.horizontal, 2)
                                .background(isEnabled ? Color.accentColor.opacity(0.3) : Color.clear)
                                .foregroundStyle(isEnabled ? Color.accentColor : .secondary)
                                .overlay(
                                    GeometryReader { geo in
                                        if isEnabled {
                                            MockActionMenu()
                                                .offset(x: -20, y: -60)
                                        }
                                    }
                                )
                            
                            Text(" to see.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 140, height: 8)
                    }
                }
            }
            .padding()
        }
        .frame(width: 260)
    }
}

struct MockActionMenu: View {
    var body: some View {
        HStack(spacing: 8) {
            ForEach(TextActionType.allCases) { action in
                VStack(spacing: 4) {
                    Image(systemName: action.icon)
                        .font(.system(size: 14))
                    Text(action.title)
                        .font(.caption2)
                }
                .frame(width: 44, height: 44)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
            }
        }
        .padding(6)
        .background(.regularMaterial)
        .cornerRadius(10)
        .shadow(radius: 4)
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
