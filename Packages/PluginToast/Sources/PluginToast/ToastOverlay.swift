import ProviderToast
import SwiftUI

// MARK: - Toast Overlay

/// 挂在主窗口根部的 Toast 渲染覆盖层。
///
/// 订阅共享的 `ToastCenter`（即 `ToastProviding` 实现），在窗口顶部
/// 渲染当前 toast。Toast 本身不参与交互（`allowsHitTesting(false)`），
/// 不遮挡下方内容。
public struct ToastOverlay<Content: View>: View {
    private let content: Content
    @ObservedObject private var center: ToastCenter

    public init(content: Content, center: ToastCenter) {
        self.content = content
        self.center = center
    }

    public var body: some View {
        content
            .overlay(alignment: .top) {
                Group {
                    if let toast = center.currentToast {
                        ToastView(toast: toast)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(.spring(duration: 0.3), value: center.currentToast)
                .allowsHitTesting(false)
            }
    }
}

// MARK: - Toast View

/// 单条 Toast 的视觉样式：图标 + 标题 + 可选副标题，顶部浮动卡片。
struct ToastView: View {
    private let toast: LumiToast

    init(toast: LumiToast) {
        self.toast = toast
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.style.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(toast.style.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                if let detail = toast.detail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(maxWidth: 380)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

// MARK: - LumiToastStyle Extensions

extension LumiToastStyle {
    /// 对应的 SF Symbol 图标名。
    var systemImage: String {
        switch self {
        case .info: "info.circle"
        case .success: "checkmark.circle"
        case .warning: "exclamationmark.triangle"
        case .error: "xmark.octagon"
        }
    }

    /// 对应的强调色。
    var tint: Color {
        switch self {
        case .info: Color.accentColor
        case .success: .green
        case .warning: .orange
        case .error: .red
        }
    }
}
