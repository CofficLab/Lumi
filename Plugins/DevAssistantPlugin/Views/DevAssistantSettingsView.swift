import SwiftUI

struct DevAssistantSettingsView: View {
    @AppStorage("DevAssistant_ApiKey") var apiKey: String = ""
    @AppStorage("DevAssistant_Model") var model: String = "claude-3-5-sonnet-20240620"
    
    var body: some View {
        Form {
            Section("Anthropic API Configuration") {
                SecureField("API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Model Name", text: $model)
                    .textFieldStyle(.roundedBorder)
                
                Link("Get API Key", destination: URL(string: "https://console.anthropic.com/")!)
                    .font(.caption)
            }
            
            Section("About") {
                Text("Dev Assistant uses Anthropic's Claude API to help you with coding tasks.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}
