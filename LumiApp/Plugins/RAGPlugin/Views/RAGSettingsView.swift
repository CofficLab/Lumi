import MagicKit
import SwiftUI

/// RAG 插件设置视图
///
/// 提供 RAG 功能的配置界面
@MainActor
struct RAGSettingsView: View {
    
    let plugin: RAGPlugin
    @State private var isEnabled = true
    
    var body: some View {
        Form {
            Section(
                header: Text(String(localized: "Retrieval-Augmented Generation Description", table: "RAG")),
                footer: Text(String(localized: "When enabled, AI can answer questions based on project code", table: "RAG"))
            ) {
                Toggle(
                    String(localized: "Enable RAG", table: "RAG"),
                    isOn: $isEnabled
                )
                .onChange(of: isEnabled) { _, newValue in
                    Task {
                        if newValue {
                            await plugin.enable()
                        } else {
                            await plugin.disable()
                        }
                    }
                }
            }
            
            Section(
                header: Text(String(localized: "System Information", table: "RAG"))
            ) {
                LabeledContent(String(localized: "Status", table: "RAG")) {
                    Text(String(localized: "Ready", table: "RAG"))
                        .foregroundStyle(.green)
                }
                LabeledContent(String(localized: "Vector Model", table: "RAG")) {
                    Text("all-MiniLM-L6-v2 (模拟)")
                }
                LabeledContent(String(localized: "Vector Database", table: "RAG")) {
                    Text("LanceDB (模拟)")
                }
            }
            
            Section(
                header: Text(String(localized: "About RAG", table: "RAG"))
            ) {
                Text(
                    String(
                        localized: "RAG (Retrieval-Augmented Generation) is a technology that enables AI to access project code.\n\nWorkflow:\n1. Index project files\n2. Search for relevant code when user asks questions\n3. AI answers based on the found code\n\nThis allows AI to accurately answer questions about your project.",
                        table: "RAG"
                    )
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - 预览

#Preview("设置") {
    RAGSettingsView(plugin: RAGPlugin.shared)
        .inRootView()
}
