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
                Spacer()
                Button(action: {
                    isSettingsPresented = true
                }) {
                    Image(systemName: "gearshape")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Settings")
                .popover(isPresented: $isSettingsPresented, arrowEdge: .bottom) {
                    DevAssistantSettingsView()
                        .frame(width: 300, height: 200)
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay(Divider(), alignment: .bottom)
            
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
                .onChange(of: viewModel.messages) { _ in
                    if let lastId = viewModel.messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Input Area
            VStack(spacing: 0) {
                Divider()
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
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                        .focused($isInputFocused)
                        .onSubmit {
                            // TextEditor doesn't support onSubmit naturally like TextField
                        }
                    
                    Button(action: {
                        viewModel.sendMessage()
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.currentInput.isEmpty || viewModel.isProcessing)
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor))
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
                    .foregroundColor(.purple)
                    .frame(width: 24, height: 24)
                    .background(Color.purple.opacity(0.1))
                    .clipShape(Circle())
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                if message.role == .assistant {
                    Text("Dev Assistant")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
            }
        }
    }
    
    var bubbleColor: Color {
        if message.isError {
            return Color.red.opacity(0.1)
        }
        switch message.role {
        case .user: return Color.blue.opacity(0.1)
        case .assistant: return Color(nsColor: .controlBackgroundColor)
        default: return Color.gray.opacity(0.1)
        }
    }
    
    var textColor: Color {
        if message.isError {
            return .red
        }
        return .primary
    }
}
