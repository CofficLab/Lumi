import LumiUI
import LumiCoreKit
import SwiftUI

public struct ChatModeToolbarButton: View {
    @EnvironmentObject private var llmVM: AppLLMVM
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    @State private var isPopoverPresented = false

    public init() {}

    public var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: llmVM.chatMode.iconName)
                    .font(.system(size: 13))
                Text(llmVM.chatMode.levelCode)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(ChatMode.allCases) { mode in
                    Button {
                        llmVM.setChatMode(mode)
                        isPopoverPresented = false
                    } label: {
                        HStack {
                            Image(systemName: mode.iconName)
                            Text(mode.levelCode)
                            Text(mode.displayName)
                            Spacer()
                            if mode == llmVM.chatMode {
                                Image(systemName: "checkmark")
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .frame(width: 220)
        }
    }

    private var foregroundColor: Color {
        switch llmVM.chatMode {
        case .chat: return .orange
        case .build: return theme.textSecondary
        case .autonomous: return .red
        }
    }

    private var backgroundColor: Color {
        foregroundColor.opacity(0.12)
    }
}
