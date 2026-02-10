import SwiftUI
import AppKit

struct TextActionsSettingsView: View {
    @StateObject private var manager = TextSelectionManager.shared
    @AppStorage("TextActionsEnabled") private var isEnabled = false
    
    var body: some View {
        Form {
            Section("通用设置") {
                Toggle("启用划词菜单", isOn: $isEnabled)
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
                        Text("需要辅助功能权限才能检测文本选择")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("打开系统设置") {
                            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            
            Section("支持的操作") {
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
