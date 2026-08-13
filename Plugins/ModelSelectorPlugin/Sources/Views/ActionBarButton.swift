import KernelLumi
import LumiUI
import SwiftUI

/// Action Bar 上的模型选择按钮
struct ActionBarButton: View {
    @LumiTheme private var theme
    let kernel: KernelLumi

    @State private var isPopoverPresented = false
    @State private var selectedProviderID: String?
    @State private var selectedModel: String?

    /// 从 kernel 获取服务
    private var llmProvider: (any LLMProviderManaging)? {
        kernel.resolveService((any LLMProviderManaging).self)
    }

    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.appCallout)
                Text(buttonLabel)
                    .font(.appCaptionEmphasized)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: isPopoverPresented ? "chevron.up" : "chevron.down")
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textTertiary)
            }
            .foregroundColor(theme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                    .fill(theme.appStatusMutedFill)
            )
            .contentShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .top) {
            PopoverContent(
                kernel: kernel,
                isPresented: $isPopoverPresented
            )
        }
        .accessibilityLabel("Select Model")
        .onLumiSelectedRemoteProviderIDDidChange {
            updateSelection()
        }
        .onLumiSelectedLocalProviderIDDidChange {
            updateSelection()
        }
        .onLumiSelectedModelsDidChange {
            updateSelection()
        }
        .onAppear {
            updateSelection()
        }
    }

    private func updateSelection() {
        selectedProviderID = llmProvider?.selectedProviderID
        selectedModel = llmProvider?.selectedModel
    }

    private var buttonLabel: String {
        guard let llmProvider else { return "Select Provider" }
        guard let providerID = selectedProviderID,
              let provider = llmProvider.allLLMProviders().first(where: { type(of: $0).info.id == providerID })
        else {
            return "Select Provider"
        }
        let info = type(of: provider).info
        if let model = selectedModel {
            let displayModel = info.modelInfo(for: model)?.displayName ?? model
            return "\(info.displayName) · \(displayModel)"
        }
        return info.displayName
    }
}
