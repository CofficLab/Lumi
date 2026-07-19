import SwiftUI

/// 设置窗口（简化版）
public struct WindowSettings: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            Text("设置")
                .font(.title2)
                .fontWeight(.semibold)

            Text("设置界面需要更多服务支持")
                .foregroundColor(.secondary)

            Spacer()
        }
        .frame(width: 500, height: 400)
        .padding()
    }
}