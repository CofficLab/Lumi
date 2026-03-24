import SwiftUI

// MARK: - GitOK Icon Extension

extension Image {
    /// GitOK 应用图标
    ///
    /// 使用 Git 风格的图标表示 GitOK 应用
    static var gitokApp: Image {
        Image(systemName: "point.topleft.down.curvedto.point.filled.bottomright.up")
            .symbolRenderingMode(.hierarchical)
    }
}

// MARK: - Preview

#Preview("GitOK Icon") {
    Image.gitokApp
        .resizable()
        .frame(width: 40, height: 40)
        .padding()
        .background(Color.white)
}