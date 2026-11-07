import Foundation
import SwiftUI

/// Toast模型
struct ToastModel: Identifiable, Equatable {
    public let id = UUID()
    let type: MagicToastType
    let title: String
    let subtitle: String?
    let displayMode: DisplayMode
    let duration: TimeInterval
    let autoDismiss: Bool
    let tapToDismiss: Bool
    let showProgress: Bool
    let onTap: (() -> Void)?
    let onDismiss: (() -> Void)?

    init(
        type: MagicToastType,
        title: String,
        subtitle: String? = nil,
        displayMode: DisplayMode = .overlay,
        duration: TimeInterval = 3.0,
        autoDismiss: Bool = true,
        tapToDismiss: Bool = true,
        showProgress: Bool = false,
        onTap: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.displayMode = displayMode
        self.duration = duration
        self.autoDismiss = autoDismiss
        self.tapToDismiss = tapToDismiss
        self.showProgress = showProgress
        self.onTap = onTap
        self.onDismiss = onDismiss
    }

    public static func == (lhs: ToastModel, rhs: ToastModel) -> Bool {
        lhs.id == rhs.id
    }
}

/// Toast类型定义
enum MagicToastType {
    case info
    case success
    case warning
    case error
    case errorDetail(error: Error, title: String)
    case loading
    case custom(systemImage: String, color: Color)

    var systemImage: String {
        switch self {
        case .info:
            return "info.circle"
        case .success:
            return "checkmark.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.circle"
        case .errorDetail:
            return "exclamationmark.triangle.fill"
        case .loading:
            return "arrow.clockwise"
        case let .custom(systemImage, _):
            return systemImage
        }
    }

    var color: Color {
        switch self {
        case .info:
            return .blue
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        case .errorDetail:
            return .red
        case .loading:
            return .gray
        case let .custom(_, color):
            return color
        }
    }
}

/// Toast显示模式
enum DisplayMode {
    case overlay // 覆盖层显示在屏幕中央
    case banner // 横幅从顶部滑下
    case bottom // 从底部弹出
    case corner // 在角落显示
}

#if DEBUG
    #Preview {
        MagicRootView {
            MagicToastExampleView()
        }
        .frame(width: 400, height: 600)
    }
#endif
