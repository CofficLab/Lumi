import AppKit
import SwiftUI

/// 状态栏图标视图模型
class StatusBarIconViewModel: ObservableObject {
    @Published var isActive: Bool = false
    @Published var activeSources: Set<String> = []
}

/// 状态栏图标视图
struct StatusBarIconView: View {
    @ObservedObject var viewModel: StatusBarIconViewModel

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            ZStack {
                if viewModel.isActive {
                    LogoView(variant: .statusBar, design: .smartLight)
                    .background(.blue.opacity(0.7))
                    .roundedFull()
                    .frame(width: size - 2, height: size - 2)
                } else {
                    LogoView(variant: .statusBar, design: .smartLight)
                    .background(.blue.opacity(0.7))
                    .roundedFull()
                    .frame(width: size - 2, height: size - 2)
                }
            }
            .infinite()
        }
    }
}

/// 能够穿透点击事件的 NSHostingView
class InteractiveHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        // 返回 nil 让点击事件穿透到下层的 NSStatusBarButton
        return nil
    }
}

// MARK: - Preview

#Preview("StatusBarIconView") {
    StatusBarIconView(viewModel: .init())
}

