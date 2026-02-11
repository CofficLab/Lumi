import SwiftUI

struct DevAssistantView: View {
    @StateObject private var viewModel = DevAssistantViewModel()
    @FocusState private var isInputFocused: Bool
    @State private var isSettingsPresented = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Dev Assistant")
                    .font(.headline)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                Spacer()
                GlassButton(title: "Settings", style: .ghost) {
                    isSettingsPresented = true
                }
                .help("Settings")
                .popover(isPresented: $isSettingsPresented, arrowEdge: .bottom) {
                    DevAssistantSettingsView()
                        .frame(width: 300, height: 200)
                }
            }
            .padding(10)
            .background(DesignTokens.Material.glass)
            .overlay(GlassDivider(), alignment: .bottom)
            
            // Chat History
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages.filter { $0.role != .system }) { msg in
                            ChatBubble(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages) { _, _ in
                    if let lastId = viewModel.messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Input Area
            VStack(spacing: 0) {
                GlassDivider()
                HStack(alignment: .bottom) {
                    if viewModel.isProcessing {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.trailing, 4)
                    }
                    
                    TextEditor(text: $viewModel.currentInput)
                        .font(.body)
                        .frame(minHeight: 40, maxHeight: 120)
                        .fixedSize(horizontal: false, vertical: true)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(DesignTokens.Color.semantic.textTertiary.opacity(0.2), lineWidth: 1)
                        )
                        .focused($isInputFocused)
                        .onSubmit {
                            // TextEditor doesn't support onSubmit naturally like TextField
                        }
                    
                    // Provider Selector
                    VStack(spacing: 0) {
                        Menu {
                            Picker("Provider", selection: $viewModel.selectedProvider) {
                                ForEach(LLMProvider.allCases) { provider in
                                    Text(provider.rawValue).tag(provider)
                                }
                            }
                            GlassDivider()
                            // Quick model edit? Or just show current
                            Text("Model: \(viewModel.currentModel)")
                                .font(.caption)
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        } label: {
                            Image(systemName: "globe")
                                .font(.system(size: 20))
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        }
                        .menuStyle(.borderlessButton)
                        .frame(width: 30, height: 30)
                    }
                    .padding(.horizontal, 4)
                    
                    GlassButton(title: "Send", style: .primary) {
                        viewModel.sendMessage()
                    }
                    .disabled(viewModel.currentInput.isEmpty || viewModel.isProcessing)
                }
                .padding(12)
                .background(DesignTokens.Material.glass)
            }
        }
        .onAppear {
            isInputFocused = true
        }
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Avatar
            if message.role == .user {
                Spacer()
            } else {
                Image(systemName: "cpu")
                    .font(.system(size: 16))
                    .foregroundColor(DesignTokens.Color.semantic.primary)
                    .frame(width: 24, height: 24)
                    .background(DesignTokens.Color.semantic.primary.opacity(0.1))
                    .clipShape(Circle())
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                if message.role == .assistant {
                    Text("Dev Assistant")
                        .font(.caption)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }
                
                Text(message.content)
                    .font(.system(.body, design: .monospaced))
                    .padding(10)
                    .background(bubbleColor)
                    .foregroundColor(textColor)
                    .cornerRadius(12)
                    .textSelection(.enabled)
            }
            
            if message.role == .assistant {
                Spacer()
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 16))
                    .foregroundColor(DesignTokens.Color.semantic.info)
                    .frame(width: 24, height: 24)
                    .background(DesignTokens.Color.semantic.info.opacity(0.1))
                    .clipShape(Circle())
            }
        }
    }
    
    var bubbleColor: Color {
        if message.isError {
            return DesignTokens.Color.semantic.error.opacity(0.1)
        }
        switch message.role {
        case .user: return DesignTokens.Color.semantic.info.opacity(0.1)
        case .assistant: return DesignTokens.Color.semantic.textTertiary.opacity(0.12)
        default: return DesignTokens.Color.semantic.textTertiary.opacity(0.1)
        }
    }
    
    var textColor: Color {
        if message.isError {
            return DesignTokens.Color.semantic.error
        }
        return DesignTokens.Color.semantic.textPrimary
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
