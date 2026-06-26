import SwiftUI

/// 单色咖啡Logo视图
/// 用于 statusBar 场景
/// 菜单栏图标渲染为单色模板图（由系统统一着色），恒为单色、无激活态。
struct CofficMonochromeLogoView: View {
    let size: CGFloat
    
    var body: some View {
        let mainSize = size * 0.75
        
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.08)
                .fill(.black)
                .frame(width: mainSize * 0.7, height: mainSize * 0.6)
            
            RoundedRectangle(cornerRadius: size * 0.04)
                .fill(.black.opacity(0.8))
                .frame(width: mainSize * 0.75, height: mainSize * 0.12)
                .offset(y: -mainSize * 0.28)
            
            Circle()
                .stroke(.black, lineWidth: size * 0.04)
                .frame(width: mainSize * 0.25, height: mainSize * 0.25)
                .offset(x: mainSize * 0.38, y: -mainSize * 0.05)
        }
        .frame(width: size, height: size)
    }
}

#Preview("Monochrome Logo") {
    CofficMonochromeLogoView(size: 64)
}