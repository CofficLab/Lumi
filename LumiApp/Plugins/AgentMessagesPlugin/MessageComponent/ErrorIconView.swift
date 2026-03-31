import MagicKit
import SwiftUI

/// 错误图标组件
struct ErrorIconView: View {
    var size: CGFloat = 16
    var weight: Font.Weight = .medium

    var body: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: size, weight: weight))
            .foregroundColor(AppUI.Color.semantic.error)
    }
}

#Preview {
    HStack(spacing: 16) {
        ErrorIconView(size: 14)
        ErrorIconView(size: 16)
        ErrorIconView(size: 20)
    }
    .padding()
}
