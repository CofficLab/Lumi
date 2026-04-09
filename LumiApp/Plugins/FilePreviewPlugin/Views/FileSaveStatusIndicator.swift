import SwiftUI
import MagicKit

/// 文件保存状态指示器视图
struct FileSaveStatusIndicator: View {
    /// 当前保存状态
    let state: FileSaveState
    
    /// 是否显示完整消息（默认只显示图标）
    var showFullMessage: Bool = false
    
    var body: some View {
        HStack(spacing: 4) {
            // 状态图标
            Image(systemName: state.icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(state.color)
                .symbolEffect(.pulse, options: .repeating.speed(0.5), isActive: state == .saving)
            
            // 状态消息（可选）
            if showFullMessage {
                Text(state.message)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(state.color)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, showFullMessage ? 8 : 4)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(state.color.opacity(0.1))
        )
        .opacity(state == .idle ? 0 : 1)
        .animation(.easeInOut(duration: 0.2), value: state)
    }
}

#Preview("各种状态") {
    VStack(spacing: 12) {
        FileSaveStatusIndicator(state: .idle, showFullMessage: true)
        FileSaveStatusIndicator(state: .pending, showFullMessage: true)
        FileSaveStatusIndicator(state: .saving, showFullMessage: true)
        FileSaveStatusIndicator(state: .saved, showFullMessage: true)
        FileSaveStatusIndicator(state: .error("权限不足"), showFullMessage: true)
        
        Divider()
        
        HStack(spacing: 8) {
            FileSaveStatusIndicator(state: .idle)
            FileSaveStatusIndicator(state: .pending)
            FileSaveStatusIndicator(state: .saving)
            FileSaveStatusIndicator(state: .saved)
            FileSaveStatusIndicator(state: .error("错误"))
        }
    }
    .padding()
    .frame(width: 300)
}