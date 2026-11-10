import SwiftUI

/// 内容区统一的加载状态：进度图标下方显示当前正在进行的操作。
public struct ContentLoadingIndicator: View {
    private let message: String
    private let controlSize: ControlSize

    public init(_ message: String, controlSize: ControlSize = .regular) {
        self.message = message
        self.controlSize = controlSize
    }

    public var body: some View {
        VStack(spacing: 6) {
            ProgressView()
                .controlSize(controlSize)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }
}
