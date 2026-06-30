import SwiftUI
import AppKit

/// 中键点击捕获视图
/// 用于捕获 macOS 上的鼠标中键点击事件（buttonNumber == 2）
struct MiddleClickCatcher: NSViewRepresentable {
    let action: () -> Void
    
    func makeNSView(context: Context) -> MiddleClickView {
        let view = MiddleClickView()
        view.action = action
        return view
    }
    
    func updateNSView(_ nsView: MiddleClickView, context: Context) {
        nsView.action = action
    }
}

/// 自定义 NSView，用于捕获中键点击事件
class MiddleClickView: NSView {
    var action: (() -> Void)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func otherMouseDown(with event: NSEvent) {
        // buttonNumber == 2 表示中键
        if event.buttonNumber == 2 {
            action?()
        } else {
            // 其他按钮传递给父视图处理
            super.otherMouseDown(with: event)
        }
    }
    
    // 确保视图可以接收鼠标事件
    override func hitTest(_ point: NSPoint) -> NSView? {
        // 始终接收事件，让 MiddleClickCatcher 覆盖的区域都能响应
        return self
    }
}

/// View 扩展，提供中键点击修饰器
extension View {
    /// 添加中键点击事件处理
    /// - Parameter action: 中键点击时执行的闭包
    /// - Returns: 添加了中键点击捕获的视图
    func onMiddleClick(perform action: @escaping () -> Void) -> some View {
        self.background(
            MiddleClickCatcher(action: action)
        )
    }
}
